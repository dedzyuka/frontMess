import SwiftUI
import AVFoundation

struct VoiceMessageView: View {
    let attachment: Attachment
    @State private var isPlaying = false
    @State private var progress: Float = 0
    @State private var player: AVAudioPlayer?
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            // Waveform placeholder
            HStack(spacing: 2) {
                if let waveformData = attachment.waveform, let amplitudes = decodeWaveform(waveformData) {
                    ForEach(0..<min(amplitudes.count, 30), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: 3, height: CGFloat(amplitudes[i]) / 100 * 30)
                    }
                } else {
                    Text("🎙️")
                        .font(.title3)
                }
            }
            .frame(height: 30)
            
            Text(formatDuration(attachment.duration ?? 0))
                .font(.caption)
                .monospacedDigit()
            
            if isPlaying {
                ProgressView(value: progress, total: 1.0)
                    .frame(width: 50)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(20)
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        guard let url = attachment.storagePath.getMediaURL() else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
            progress = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard let player = player, player.duration > 0 else { return }
                progress = Float(player.currentTime / player.duration)
                if !player.isPlaying {
                    stopPlayback()
                }
            }
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    private func stopPlayback() {
        player?.stop()
        player = nil
        timer?.invalidate()
        isPlaying = false
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false)
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

extension String {
    func getMediaURL() -> URL? {
        if self.hasPrefix("http") {
            return URL(string: self)
        }
        let base = AppConfig.baseURL
        let path = self.hasPrefix("/") ? String(self.dropFirst()) : self
        return URL(string: base + "/media/" + path)
    }
}
