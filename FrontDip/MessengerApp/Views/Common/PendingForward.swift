//
//  PendingForward.swift
//  MessengerApp
//

import Foundation

class PendingForward {
    static let shared = PendingForward()
    
    var message: Message?
    var targetChatId: UUID?
    
    private init() {}
    
    func clear() {
        message = nil
        targetChatId = nil
    }
}
