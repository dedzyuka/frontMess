import Foundation

struct Contact: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let nickname: String
    let publicKey: String
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case nickname
        case publicKey = "public_key"
        case addedAt = "added_at"
    }
}
