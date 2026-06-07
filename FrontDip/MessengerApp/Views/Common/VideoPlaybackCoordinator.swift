//
//  VideoPlaybackCoordinator.swift
//  MessengerApp
//

import Foundation
import AVFoundation

class VideoPlaybackCoordinator: ObservableObject {
    static let shared = VideoPlaybackCoordinator()

    private(set) var activePlayerId: String?
    private var activePlayer: AVPlayer?

    private init() {}

    func setActivePlayer(id: String, player: AVPlayer) {
        if activePlayerId == id { return }
        // Деактивируем старый
        if let oldPlayer = activePlayer {
            oldPlayer.isMuted = true
        }
        activePlayerId = id
        activePlayer = player
        player.isMuted = false
    }

    func deactivateCurrent() {
        if let player = activePlayer {
            player.isMuted = true
        }
        activePlayerId = nil
        activePlayer = nil
    }

    func isActive(id: String) -> Bool {
        return activePlayerId == id
    }
}
