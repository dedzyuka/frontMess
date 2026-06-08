import SwiftUI
import AVFoundation

extension Notification.Name {
    static let shouldStopAudioPlayback = Notification.Name("shouldStopAudioPlayback")
}

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying = false
    @Published var currentPlayerId: String? = nil  // attachmentId
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: Any?
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(stopCurrent), name: .shouldStopAudioPlayback, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopCurrent), name: .shouldStopVideoPlayback, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func play(attachmentId: String, url: URL, onProgress: @escaping (Double) -> Void, onFinish: @escaping () -> Void) {
        // Если это же аудио уже играет – останавливаем (сворачиваем)
        if currentPlayerId == attachmentId && player != nil {
            stopCurrent()
            onFinish()
            return
        }
        
        // Останавливаем текущее воспроизведение
        stopCurrent()
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        player = newPlayer
        currentPlayerId = attachmentId
        isPlaying = true
        
        // Прогресс
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            let duration = playerItem.asset.duration.seconds
            if duration > 0 {
                let progress = time.seconds / duration
                onProgress(progress)
            }
        }
        
        // Окончание
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.stopCurrent()
            onFinish()
        }
        
        newPlayer.play()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    @objc func stopCurrent() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.pause()
        player = nil
        currentPlayerId = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
