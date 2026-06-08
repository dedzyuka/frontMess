import SwiftUI
import AVFoundation

struct VoiceMessageBubble: View {
    let attachment: Attachment
    let isCurrentUser: Bool
    
    @ObservedObject private var audioManager = AudioPlayerManager.shared
    @ObservedObject private var videoManager = VideoCircleManager.shared
    
    @State private var progress: Double = 0
    @State private var amplitudes: [Int] = []
    
    private var isPlaying: Bool {
        audioManager.currentPlayerId == attachment.attachmentId.uuidString && audioManager.isPlaying
    }
    
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
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isCurrentUser ? .trailing : .leading)
        .onAppear {
            loadWaveform()
        }
        .onDisappear {
            if isPlaying {
                audioManager.stopCurrent()
            }
        }
    }
    
    @ViewBuilder
    private var waveformView: some View {
        let columns = amplitudes.isEmpty ? 20 : min(amplitudes.count, 20)
        let activeCount = Int(Double(columns) * progress)
        
        HStack(spacing: 2) {
            ForEach(0..<columns, id: \.self) { index in
                let height = amplitudes.isEmpty ? CGFloat.random(in: 8...20) : CGFloat(amplitudes[index]) / 100 * 30
                let isActive = isPlaying && index < activeCount
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
    
    private func togglePlayback() {
        if isPlaying {
            audioManager.stopCurrent()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        // Останавливаем видео, если играет
        NotificationCenter.default.post(name: .shouldStopVideoPlayback, object: nil)
        
        guard let url = audioURL else { return }
        audioManager.play(
            attachmentId: attachment.attachmentId.uuidString,
            url: url,
            onProgress: { newProgress in
                self.progress = newProgress
            },
            onFinish: {
                self.progress = 0
            }
        )
    }
    
    private func loadWaveform() {
        if let waveformData = attachment.waveform,
           let decoded = decodeWaveform(waveformData) {
            amplitudes = decoded
        }
    }
    
    private func decodeWaveform(_ base64: String) -> [Int]? {
        guard let data = Data(base64Encoded: base64),
              let array = try? JSONDecoder().decode([Int].self, from: data) else { return nil }
        return array
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
