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
