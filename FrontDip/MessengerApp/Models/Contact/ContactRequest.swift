import Foundation

struct ContactRequest: Identifiable, Codable {
    let id: UUID
    let fromUserId: UUID
    let fromNickname: String
    let fromPublicKey: String
    let status: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case fromNickname = "from_nickname"
        case fromPublicKey = "from_public_key"
        case status
        case createdAt = "created_at"
    }
}
