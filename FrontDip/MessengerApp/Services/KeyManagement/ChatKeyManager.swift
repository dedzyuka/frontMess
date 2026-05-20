
import Foundation

class ChatKeyManager {
    static let shared = ChatKeyManager()
    
    private var chatKeys: [UUID: Data] = [:]
    
    private init() {}
    
    func saveChatKey(_ key: Data, for chatId: UUID) {
        chatKeys[chatId] = key
    }
    
    func getChatKey(for chatId: UUID) -> Data? {
        return chatKeys[chatId]
    }
    
    func removeChatKey(for chatId: UUID) {
        chatKeys.removeValue(forKey: chatId)
    }
    
    func clearAllKeys() {
        chatKeys.removeAll()
    }
}
