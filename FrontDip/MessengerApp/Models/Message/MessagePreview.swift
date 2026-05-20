import Foundation

struct MessagePreview: Codable {
    let messageId: Int
    let senderId: String
    let type: String
    let textPreview: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case senderId = "sender_id"
        case type
        case textPreview = "text_preview"
        case createdAt = "created_at"
    }
}
