//
//  VideoCircleManager.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation

class VideoCircleManager: ObservableObject {
    static let shared = VideoCircleManager()
    
    @Published var expandedVideoId: String? = nil
    
    // Для бесшумного циклического воспроизведения (свёрнутое состояние)
    private var loopPlayers: [String: AVQueuePlayer] = [:]
    private var loopers: [String: AVPlayerLooper] = [:]
    
    // Для проигрывания одного раза (развёрнутое состояние)
    private var singlePlayPlayers: [String: AVPlayer] = [:]
    
    private init() {}
    
    // Регистрируем видео для бесшумного цикла
    func registerLooper(id: String, url: URL) -> AVQueuePlayer? {
        unregisterLooper(id: id)
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        guard let looper = try? AVPlayerLooper(player: player, templateItem: playerItem) else {
            return nil
        }
        loopPlayers[id] = player
        loopers[id] = looper
        player.play()
        return player
    }
    
    func unregisterLooper(id: String) {
        loopPlayers[id]?.pause()
        loopPlayers.removeValue(forKey: id)
        loopers.removeValue(forKey: id)
    }
    
    // Запуск однократного воспроизведения со звуком при разворачивании
    func playSingleWithSound(id: String, url: URL, onFinish: @escaping () -> Void) {
        // Останавливаем цикл, если он был
        if let loopPlayer = loopPlayers[id] {
            loopPlayer.pause()
        }
        // Создаём новый плеер для одного раза
        let player = AVPlayer(url: url)
        player.isMuted = false
        singlePlayPlayers[id] = player
        
        // Подписываемся на окончание
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            onFinish()
            self.cleanupSinglePlay(id: id)
        }
        
        player.play()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func cleanupSinglePlay(id: String) {
        singlePlayPlayers[id]?.pause()
        singlePlayPlayers.removeValue(forKey: id)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Возвращаем цикл, если он был
        if let loopPlayer = loopPlayers[id] {
            loopPlayer.play()
        }
    }
    
    func setExpanded(_ id: String?, url: URL?, onFinish: @escaping () -> Void) {
        // Если уже развёрнут этот же – ничего не делаем
        if expandedVideoId == id { return }
        
        // Сворачиваем предыдущий развёрнутый
        if let prevId = expandedVideoId {
            // Останавливаем однократное воспроизведение
            cleanupSinglePlay(id: prevId)
        }
        
        expandedVideoId = id
        
        if let id = id, let url = url {
            // Запускаем однократное воспроизведение
            playSingleWithSound(id: id, url: url, onFinish: {
                // Автоматически сворачиваем
                DispatchQueue.main.async {
                    if self.expandedVideoId == id {
                        self.setExpanded(nil, url: nil, onFinish: {})
                    }
                    onFinish()
                }
            })
        } else {
            // Если свернули – просто обновляем состояние
        }
        objectWillChange.send()
    }
}
