//
//  VoiceRecorderView.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation

struct VoiceRecorderView: UIViewControllerRepresentable {
    let onRecordingFinished: (URL, TimeInterval, String?) -> Void
    
    func makeUIViewController(context: Context) -> VoiceRecorderViewController {
        let controller = VoiceRecorderViewController()
        controller.onRecordingFinished = onRecordingFinished
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VoiceRecorderViewController, context: Context) {}
}

class VoiceRecorderViewController: UIViewController, AVAudioRecorderDelegate {
    
    var onRecordingFinished: ((URL, TimeInterval, String?) -> Void)?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }
    
    private func setupUI() {
        let button = UIButton(type: .system)
        button.setTitle("🎙 Записать", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.layer.cornerRadius = 30
        button.frame = CGRect(x: 0, y: 0, width: 160, height: 60)
        button.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - 100)
        button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        view.addSubview(button)
        
        // Кнопка отмены
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Отмена", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.frame = CGRect(x: 20, y: 40, width: 80, height: 40)
        view.addSubview(cancelButton)
    }
    
    @objc private func recordButtonTapped() {
        if audioRecorder?.isRecording == true {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            recordingStartTime = Date()
            
            if let button = view.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.title(for: .normal) == "🎙 Записать" }) as? UIButton {
                button.setTitle("⏹ Остановить", for: .normal)
                button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
            }
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        
        if let button = view.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.title(for: .normal) == "⏹ Остановить" }) as? UIButton {
            button.setTitle("🎙 Записать", for: .normal)
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag, let url = recordingURL, let startTime = recordingStartTime else {
            dismiss(animated: true)
            return
        }
        let duration = Date().timeIntervalSince(startTime)
        
        // Генерация упрощённого waveform (массив амплитуд)
        var waveform: String? = nil
        if let audioFile = try? AVAudioFile(forReading: url) {
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try? audioFile.read(into: buffer)
            if let channelData = buffer.floatChannelData {
                let channelDataPointer = channelData.pointee
                let frameLength = Int(buffer.frameLength)
                let step = max(1, frameLength / 100) // 100 точек
                var amplitudes: [Float] = []
                for i in stride(from: 0, to: frameLength, by: step) {
                    let amplitude = abs(channelDataPointer[i])
                    amplitudes.append(amplitude)
                }
                // Нормализуем и кодируем в base64
                let maxAmp = amplitudes.max() ?? 1.0
                let normalized = amplitudes.map { Int(($0 / maxAmp) * 100) }
                if let jsonData = try? JSONSerialization.data(withJSONObject: normalized) {
                    waveform = jsonData.base64EncodedString()
                }
            }
        }
        
        onRecordingFinished?(url, duration, waveform)
        dismiss(animated: true)
    }
}
