//
//  VoiceMessageBubble.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation

struct VoiceMessageBubble: View {
    let attachment: Attachment
    let isCurrentUser: Bool

    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var amplitudes: [Int] = []

    private let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.75 // 75% экрана
    private let maxWaveformColumns = 20 // уменьшил до 20 для компактности

    private var audioURL: URL? {
        let base = AppConfig.baseURL
        let path = attachment.storagePath.hasPrefix("/") ? attachment.storagePath : "/media/" + attachment.storagePath
        return URL(string: base + path)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCurrentUser ? .white : .blue)
            }

            waveformView
                .frame(height: 30)

            Text(formatDuration(attachment.duration ?? 0))
                .font(.caption)
                .foregroundColor(isCurrentUser ? .white : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
        .cornerRadius(20)
        .frame(maxWidth: maxBubbleWidth, alignment: isCurrentUser ? .trailing : .leading)
        .onAppear {
            loadWaveform()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    @ViewBuilder
    private var waveformView: some View {
        let columns = amplitudes.isEmpty ? maxWaveformColumns : min(amplitudes.count, maxWaveformColumns)
        let activeCount = Int(Double(columns) * progress)

        HStack(spacing: 2) {
            ForEach(0..<columns, id: \.self) { index in
                let height = amplitudes.isEmpty ? CGFloat.random(in: 8...20) : CGFloat(amplitudes[index]) / 100 * 30
                let isActive = index < activeCount
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(isActive: isActive))
                    .frame(width: 3, height: height)
                    .animation(.linear(duration: 0.05), value: isActive)
            }
        }
        .frame(height: 30)
    }

    private func barColor(isActive: Bool) -> Color {
        if isCurrentUser {
            return isActive ? .white : .white.opacity(0.4)
        } else {
            return isActive ? .blue : .blue.opacity(0.4)
        }
    }

    private func loadWaveform() {
        if let waveformData = attachment.waveform,
           let decoded = decodeWaveform(waveformData) {
            amplitudes = decoded
        } else {
            amplitudes = []
        }
    }

    private func decodeWaveform(_ base64: String) -> [Int]? {
        guard let data = Data(base64Encoded: base64),
              let array = try? JSONDecoder().decode([Int].self, from: data) else { return nil }
        return array
    }

    // MARK: - Playback Control
    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = audioURL else { return }
        stopPlayback()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        Task {
            if let duration = try? await playerItem.asset.load(.duration) {
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite {
                    await MainActor.run {
                        self.duration = seconds
                    }
                }
            }
        }

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { time in
            let current = CMTimeGetSeconds(time)
            if self.duration > 0 {
                self.progress = min(1.0, max(0, current / self.duration))
            }
            if !current.isFinite || current >= self.duration - 0.05 {
                self.finishPlayback()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            self.finishPlayback()
        }

        player?.play()
        isPlaying = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
    }

    private func stopPlayback() {
        pausePlayback()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
        progress = 0
        duration = 0
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func finishPlayback() {
        stopPlayback()
        isPlaying = false
        progress = 0
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
