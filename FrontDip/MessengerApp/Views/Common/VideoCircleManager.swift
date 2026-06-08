//
//  VideoCircleManager.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation


class VideoCircleManager: ObservableObject {
    static let shared = VideoCircleManager()
    
    @Published var expandedVideoId: String? = nil
    
    private var _currentPlayer: AVPlayer?
    private var currentPlayerId: String?
    private var endObserver: Any?
    
    // Публичный доступ к плееру (read-only)
    var activePlayer: AVPlayer? {
        return _currentPlayer
    }
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(stopCurrent), name: .shouldStopVideoPlayback, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func play(id: String, url: URL, onFinish: @escaping () -> Void) {
        NotificationCenter.default.post(name: .shouldStopAudioPlayback, object: nil)
        stopCurrent()
        
        let player = AVPlayer(url: url)
        _currentPlayer = player
        currentPlayerId = id
        expandedVideoId = id
        
        player.isMuted = false
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.stopCurrent()
            DispatchQueue.main.async {
                onFinish()
            }
        }
        
        player.play()
    }
    
    @objc func stopCurrent() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        _currentPlayer?.pause()
        _currentPlayer = nil
        currentPlayerId = nil
        expandedVideoId = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
