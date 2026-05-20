import Foundation

struct Chat: Identifiable, Codable {
    let id: UUID
    let chatType: String
    let name: String?
    let description: String?
    let avatarUrl: String?
    let creatorId: UUID?
    let isPublic: Bool
    let membersCount: Int
    let createdAt: Date
    let updatedAt: Date
    let lastMessagePreview: MessagePreview?
    
    enum CodingKeys: String, CodingKey {
        case id = "chat_id"
        case chatType = "chat_type"
        case name
        case description
        case avatarUrl = "avatar_url"
        case creatorId = "creator_id"
        case isPublic = "is_public"
        case membersCount = "members_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessagePreview = "last_message_preview"
    }
}
