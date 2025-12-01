// ./FrontDip/MessengerApp/Models/Chat/Chat.swift
import Foundation

struct Chat: Identifiable, Codable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let createdAt: Date
    let memberCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "chat_id"
        case name
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case memberCount = "member_count"
    }
}
