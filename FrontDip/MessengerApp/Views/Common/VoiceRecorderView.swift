import SwiftUI
import AVFoundation

struct VoiceRecorderView: View {
    let onComplete: (URL, TimeInterval, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = VoiceRecorderViewModel()

    @State private var buttonFrame: CGRect = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var isPressingToRecord = false
    @State private var isLocked = false
    @State private var didCancelByGesture = false

    private let cancelThreshold: CGFloat = 100
    private let lockThreshold: CGFloat = 90

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerContent
                Spacer()
                bottomPanel
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .task {
            await recorder.requestPermissionsIfNeeded()
        }
        .onDisappear {
            recorder.cleanup()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if recorder.isRecording {
                    recorder.cancelRecording()
                }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            Text(titleText)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private var centerContent: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(mainCircleColor.opacity(0.18))
                    .frame(width: 220, height: 220)

                Circle()
                    .fill(mainCircleColor.opacity(0.28))
                    .frame(width: 170, height: 170)
                    .scaleEffect(recorder.isRecording ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.isRecording)

                Circle()
                    .fill(mainCircleColor)
                    .frame(width: 120, height: 120)
                    .shadow(color: mainCircleColor.opacity(0.35), radius: 18, y: 10)

                Image(systemName: recorderIcon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text(recorder.formattedDuration)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            }

            waveformView
        }
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(recorder.meterLevels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 4, height: max(8, CGFloat(level) * 56))
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 18) {
            if recorder.isRecording && !isLocked {
                gestureHints
            }

            if isLocked && recorder.isRecording {
                lockedControls
            } else {
                recordButton
            }

            if let errorText = recorder.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.red.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var gestureHints: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text("Свайп вверх — зафиксировать")
            }
            .font(.footnote)
            .foregroundColor(readyToLock ? .yellow : .white.opacity(0.7))

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                Text("Свайп влево — отмена")
            }
            .font(.footnote)
            .foregroundColor(readyToCancel ? .red : .white.opacity(0.7))
        }
        .padding(.horizontal, 6)
    }

    private var lockedControls: some View {
        HStack(spacing: 14) {
            Button {
                didCancelByGesture = true
                isLocked = false
                recorder.cancelRecording()
                dismiss()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red)
                    .clipShape(Circle())
            }

            Button {
                finishLockedRecording()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                    Text("Отправить")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .clipShape(Capsule())
            }

            Button {
                recorder.stopRecording(shouldSave: false)
                isLocked = false
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
        }
    }

    private var recordButton: some View {
        ZStack {
            Circle()
                .fill(readyToCancel ? Color.red : mainCircleColor)
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: recorder.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                )
                .scaleEffect(isPressingToRecord ? 1.08 : 1.0)
                .offset(x: dragOffset.width, y: dragOffset.height)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: dragOffset)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                buttonFrame = proxy.frame(in: .global)
                            }
                            .onChange(of: proxy.frame(in: .global)) { newValue in
                                buttonFrame = newValue
                            }
                    }
                )
                .gesture(recordGesture)

            if recorder.isRecording && !isLocked {
                lockIndicator
                    .offset(y: -116)
            }
        }
        .frame(height: 120)
    }

    private var lockIndicator: some View {
        VStack(spacing: 6) {
            Image(systemName: readyToLock ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(readyToLock ? .yellow : .white.opacity(0.85))

            Text(readyToLock ? "Отпусти для lock" : "Потяни вверх")
                .font(.caption2)
                .foregroundColor(readyToLock ? .yellow : .white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10))
        .clipShape(Capsule())
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !isPressingToRecord {
                    beginPressRecording()
                }

                dragOffset = CGSize(
                    width: min(0, value.translation.width),
                    height: min(0, value.translation.height)
                )
            }
            .onEnded { value in
                let translation = value.translation

                if readyToCancelWith(translation) {
                    didCancelByGesture = true
                    recorder.cancelRecording()
                    resetGestureState()
                    dismiss()
                    return
                }

                if readyToLockWith(translation) {
                    isLocked = true
                    isPressingToRecord = false
                    dragOffset = .zero
                    return
                }

                if recorder.isRecording {
                    completePressRecording()
                } else {
                    resetGestureState()
                }
            }
    }

    private var readyToCancel: Bool {
        readyToCancelWith(dragOffset)
    }

    private var readyToLock: Bool {
        readyToLockWith(dragOffset)
    }

    private func readyToCancelWith(_ translation: CGSize) -> Bool {
        translation.width < -cancelThreshold
    }

    private func readyToLockWith(_ translation: CGSize) -> Bool {
        translation.height < -lockThreshold
    }

    private func beginPressRecording() {
        didCancelByGesture = false
        isPressingToRecord = true

        if !recorder.isRecording {
            recorder.startRecording()
        }
    }

    private func completePressRecording() {
        recorder.stopRecording(shouldSave: true) { url, duration, waveform in
            resetGestureState()
            onComplete(url, duration, waveform)
            dismiss()
        }
    }

    private func finishLockedRecording() {
        recorder.stopRecording(shouldSave: true) { url, duration, waveform in
            isLocked = false
            resetGestureState()
            onComplete(url, duration, waveform)
            dismiss()
        }
    }

    private func resetGestureState() {
        isPressingToRecord = false
        dragOffset = .zero
    }

    private var mainCircleColor: Color {
        if readyToCancel { return .red }
        if recorder.isRecording { return .blue }
        return .blue
    }

    private var recorderIcon: String {
        if isLocked && recorder.isRecording {
            return "lock.fill"
        }
        return recorder.isRecording ? "waveform" : "mic.fill"
    }

    private var titleText: String {
        if isLocked && recorder.isRecording {
            return "Запись зафиксирована"
        }
        return recorder.isRecording ? "Запись голосового" : "Голосовое сообщение"
    }

    private var statusText: String {
        if recorder.isRecording && isLocked {
            return "Нажми отправить, когда закончишь"
        }
        if recorder.isRecording {
            return "Удерживай, влево — отмена, вверх — lock"
        }
        return "Зажми кнопку для записи"
    }
}

final class VoiceRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var errorText: String?
    @Published var meterLevels: [Float] = Array(repeating: 0.12, count: 24)

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var outputURL: URL?

    private(set) var waveformSamples: [Float] = []

    var formattedDuration: String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func requestPermissionsIfNeeded() async {
        await MainActor.run {
            errorText = nil
        }

        let session = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { continuation in
            session.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }

        if !granted {
            await MainActor.run {
                self.errorText = "Нет доступа к микрофону. Разреши доступ в Settings."
            }
        }
    }

    func startRecording() {
        errorText = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let url = Self.makeOutputURL()
            outputURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()

            guard recorder.record() else {
                errorText = "Не удалось начать запись."
                return
            }

            audioRecorder = recorder
            startedAt = Date()
            duration = 0
            waveformSamples = []
            meterLevels = Array(repeating: 0.12, count: 24)
            isRecording = true

            startTimers()
        } catch {
            errorText = error.localizedDescription
            cleanupSession()
        }
    }

    func stopRecording(
        shouldSave: Bool,
        completion: ((URL, TimeInterval, String?) -> Void)? = nil
    ) {
        guard let recorder = audioRecorder else {
            isRecording = false
            return
        }

        stopTimers()
        recorder.stop()

        let finalDuration = duration
        let finalURL = recorder.url
        let waveform = encodeWaveform()

        audioRecorder = nil
        isRecording = false
        cleanupSession()

        if shouldSave, finalDuration >= 0.35 {
            completion?(finalURL, finalDuration, waveform)
        } else {
            try? FileManager.default.removeItem(at: finalURL)
        }
    }

    func cancelRecording() {
        stopRecording(shouldSave: false, completion: nil)
    }

    func cleanup() {
        if isRecording {
            cancelRecording()
        } else {
            stopTimers()
            cleanupSession()
        }
    }

    private func startTimers() {
        stopTimers()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            self.duration = Date().timeIntervalSince(startedAt)
        }

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder, recorder.isRecording else { return }

            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let normalized = self.normalizedPowerLevel(from: power)

            self.waveformSamples.append(normalized)
            if self.waveformSamples.count > 120 {
                self.waveformSamples.removeFirst(self.waveformSamples.count - 120)
            }

            var levels = self.meterLevels
            levels.append(max(0.08, normalized))
            if levels.count > 24 {
                levels.removeFirst(levels.count - 24)
            }
            self.meterLevels = levels
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func cleanupSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func normalizedPowerLevel(from decibels: Float) -> Float {
        if decibels < -50 { return 0.08 }
        if decibels >= 0 { return 1.0 }

        let minDb: Float = -50
        let level = (decibels - minDb) / abs(minDb)
        return max(0.08, min(1.0, level))
    }

    private func encodeWaveform() -> String? {
        guard !waveformSamples.isEmpty else { return nil }

        let targetCount = 48
        let chunkSize = max(1, waveformSamples.count / targetCount)

        let reduced: [Int] = stride(from: 0, to: waveformSamples.count, by: chunkSize).map { start in
            let end = min(start + chunkSize, waveformSamples.count)
            let chunk = waveformSamples[start..<end]
            let avg = chunk.reduce(0, +) / Float(chunk.count)
            return Int(max(1, min(100, avg * 100)))
        }

        return reduced.map(String.init).joined(separator: ",")
    }

    static private func makeOutputURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("voice-\(UUID().uuidString).m4a")
    }
}
