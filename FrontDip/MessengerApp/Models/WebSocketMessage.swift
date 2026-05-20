import Foundation

struct WebSocketMessage: Codable {
    let type: String
    var chatId: UUID?
    var content: String?
    var messageId: UUID?
    var timestamp: Date?
    var senderId: UUID?
    var recipientId: UUID?
    var originalSenderId: UUID?
    var requestId: UUID?
    var ackSenderId: UUID?
    var senderNickname: String?
    var senderPublicKey: String?
    var recipientNickname: String?
    var acceptedUserId: UUID?
    var acceptedNickname: String?
    var acceptedPublicKey: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case chatId = "chat_id"
        case content
        case messageId = "message_id"
        case timestamp
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case originalSenderId = "original_sender_id"
        case requestId = "request_id"
        case ackSenderId = "ack_sender_id"
        case senderNickname = "sender_nickname"
        case senderPublicKey = "sender_public_key"
        case recipientNickname = "recipient_nickname"
        case acceptedUserId = "accepted_user_id"
        case acceptedNickname = "accepted_nickname"
        case acceptedPublicKey = "accepted_public_key"
    }
    
    init(type: String,
         chatId: UUID? = nil,
         content: String? = nil,
         messageId: UUID? = nil,
         timestamp: Date? = nil,
         senderId: UUID? = nil,
         recipientId: UUID? = nil,
         originalSenderId: UUID? = nil,
         requestId: UUID? = nil,
         ackSenderId: UUID? = nil,
         senderNickname: String? = nil,
         senderPublicKey: String? = nil,
         recipientNickname: String? = nil,
         acceptedUserId: UUID? = nil,
         acceptedNickname: String? = nil,
         acceptedPublicKey: String? = nil) {
        self.type = type
        self.chatId = chatId
        self.content = content
        self.messageId = messageId
        self.timestamp = timestamp
        self.senderId = senderId
        self.recipientId = recipientId
        self.originalSenderId = originalSenderId
        self.requestId = requestId
        self.ackSenderId = ackSenderId
        self.senderNickname = senderNickname
        self.senderPublicKey = senderPublicKey
        self.recipientNickname = recipientNickname
        self.acceptedUserId = acceptedUserId
        self.acceptedNickname = acceptedNickname
        self.acceptedPublicKey = acceptedPublicKey
    }
}
