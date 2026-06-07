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

            // Упрощённый waveform
            if let waveformData = attachment.waveform, let amplitudes = decodeWaveform(waveformData) {
                HStack(spacing: 2) {
                    ForEach(0..<min(amplitudes.count, 30), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isCurrentUser ? Color.white.opacity(0.7) : Color.blue.opacity(0.7))
                            .frame(width: 3, height: CGFloat(amplitudes[i]) / 100 * 30)
                    }
                }
                .frame(height: 30)
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isCurrentUser ? Color.white.opacity(0.7) : Color.blue.opacity(0.7))
                            .frame(width: 3, height: CGFloat.random(in: 8...20))
                    }
                }
                .frame(height: 30)
            }

            if isPlaying, duration > 0 {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 50)
                    .tint(isCurrentUser ? .white : .blue)
            }

            Text(formatDuration(attachment.duration ?? 0))
                .font(.caption)
                .foregroundColor(isCurrentUser ? .white : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
        .cornerRadius(20)
        .onDisappear {
            stopPlayback()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = audioURL else { return }

        // Убедимся, что плеер создан заново
        stopPlayback()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Получаем длительность асинхронно
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

        // Наблюдатель за прогрессом
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            let current = CMTimeGetSeconds(time)
            if self.duration > 0 {
                self.progress = current / self.duration
            }
            if !current.isFinite || current >= self.duration - 0.05 {
                self.finishPlayback()
            }
        }

        // Наблюдатель за окончанием
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            self.finishPlayback()
        }

        player?.play()
        isPlaying = true

        // Активируем аудиосессию
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
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func decodeWaveform(_ base64: String) -> [Int]? {
        guard let data = Data(base64Encoded: base64),
              let array = try? JSONDecoder().decode([Int].self, from: data) else { return nil }
        return array
    }
}
