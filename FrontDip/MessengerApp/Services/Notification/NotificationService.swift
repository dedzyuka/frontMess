// ./FrontDip/MessengerApp/Services/NotificationService.swift
import Foundation
import SwiftUI

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func showSuccess(_ message: String) {
        DispatchQueue.main.async {
            // Используем NotificationCenter для отправки уведомления
            NotificationCenter.default.post(
                name: .showNotification,  // Используем уже объявленное в ContactService.swift
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
    }
    
    let type: NotificationType
    let message: String
}

