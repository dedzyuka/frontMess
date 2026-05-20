import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case file
}

struct Message: Identifiable, Codable {
    let id: UUID?
    let chatId: UUID
    let senderId: UUID
    let content: String
    let type: MessageType
    let timestamp: Date
    let isEncrypted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case chatId = "chat_id"
        case senderId = "sender_id"
        case content
        case type = "message_type"
        case timestamp
        case isEncrypted = "encrypted"
    }
    
    init(id: UUID? = nil, chatId: UUID, senderId: UUID, content: String,
         type: MessageType = .text, timestamp: Date = Date(), isEncrypted: Bool = true) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.isEncrypted = isEncrypted
    }
}
