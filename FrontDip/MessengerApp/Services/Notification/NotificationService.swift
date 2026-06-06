// ./FrontDip/MessengerApp/Services/Notification/NotificationService.swift
import Foundation
import SwiftUI

// Все Notification.Name в одном месте
extension Notification.Name {
    static let showNotification = Notification.Name("showNotification")
    static let newContactRequest = Notification.Name("newContactRequest")
    static let contactRequestAccepted = Notification.Name("contactRequestAccepted")
    static let userLoggedIn = Notification.Name("userLoggedIn")
    static let newMessageReceived = Notification.Name("newMessageReceived")
    static let websocketConnected = Notification.Name("websocketConnected")
    static let websocketDisconnected = Notification.Name("websocketDisconnected")
    static let websocketError = Notification.Name("websocketError")
    static let typingStarted = Notification.Name("typingStarted")
    static let typingStopped = Notification.Name("typingStopped")
    static let messageAcknowledged = Notification.Name("messageAcknowledged")
    static let chatCreated = Notification.Name("chatCreated")
    static let openChat = Notification.Name("openChat")
    static let openProfile = Notification.Name("openProfile")
    static let reactionAdded = Notification.Name("reactionAdded")
    static let reactionRemoved = Notification.Name("reactionRemoved")
    static let statusUpdated = Notification.Name("statusUpdated")

    static let messageUpdated = Notification.Name("messageUpdated")
    static let messageDeleted = Notification.Name("messageDeleted")
    static let chatOpened = Notification.Name("chatOpened")
    static let scrollToMessage = Notification.Name("scrollToMessage")
    
}

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func showSuccess(_ message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationData(type: .success, message: message)
            )
        }
    }
    
    func showError(_ message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationData(type: .error, message: message)
            )
        }
    }
    
    func showInfo(_ message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showNotification,
                object: NotificationData(type: .info, message: message)
            )
        }
    }
}

struct NotificationData {
    enum NotificationType {
        case success
        case error
        case info
        
        var title: String {
            switch self {
            case .success: return "Успех"
            case .error: return "Ошибка"
            case .info: return "Информация"
            }
        }
    }
    
    let type: NotificationType
    let message: String
}
