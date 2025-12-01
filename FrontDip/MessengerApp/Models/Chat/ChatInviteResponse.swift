// ./FrontDip/MessengerApp/Models/Chat/ChatInviteResponse.swift
import Foundation

struct ChatInviteResponse: Codable {
    let chatId: UUID
    let inviteKey: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case inviteKey = "invite_key"
        case createdAt = "created_at"
    }
}
