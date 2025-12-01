// ./FrontDip/MessengerApp/Services/KeyManagement/ChatKeyManager.swift
import Foundation

class ChatKeyManager {
    static let shared = ChatKeyManager()
    
    private var chatKeys: [UUID: Data] = [:]
    
    private init() {}
    
    func saveChatKey(_ key: Data, for chatId: UUID) {
        chatKeys[chatId] = key
        print("🔐 Ключ чата сохранен в памяти для \(chatId)")
    }
    
    func getChatKey(for chatId: UUID) -> Data? {
        return chatKeys[chatId]
    }
    
    func removeChatKey(for chatId: UUID) {
        chatKeys.removeValue(forKey: chatId)
    }
    
    func hasKey(for chatId: UUID) -> Bool {
        return chatKeys[chatId] != nil
    }
    
    func clearAllKeys() {
        chatKeys.removeAll()
        print("🧹 Все ключи чатов очищены из памяти")
    }
}
