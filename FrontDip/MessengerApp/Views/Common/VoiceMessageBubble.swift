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
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?

    private var audioURL: URL? {
        let base = AppConfig.baseURL
        let path = attachment.storagePath.hasPrefix("/") ? attachment.storagePath : "/media/" + attachment.storagePath
        return URL(string: base + path)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCurrentUser ? .white : .blue)
            }

            // Упрощённый waveform (динамические полоски)
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isCurrentUser ? Color.white.opacity(0.7) : Color.blue.opacity(0.7))
                        .frame(width: 3, height: CGFloat.random(in: 8...20))
                }
            }
            .frame(height: 30)

            Text(formatDuration(attachment.duration ?? 0))
                .font(.caption)
                .foregroundColor(isCurrentUser ? .white : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
        .cornerRadius(20)
        .onDisappear {
            audioPlayer?.stop()
            timer?.invalidate()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            timer?.invalidate()
            isPlaying = false
        } else {
            guard let url = audioURL else { return }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                isPlaying = true
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    if let player = audioPlayer, !player.isPlaying {
                        isPlaying = false
                        timer?.invalidate()
                    }
                }
            } catch {
                print("Audio playback error: \(error)")
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
