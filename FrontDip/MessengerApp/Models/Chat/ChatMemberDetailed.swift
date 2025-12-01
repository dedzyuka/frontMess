import Foundation

struct ChatMemberDetailed: Identifiable, Codable {
    let user_id: UUID
    let nickname: String
    let public_key: String
    let joined_at: Date
    let device_id: String
    
    var id: UUID { user_id }
    
    enum CodingKeys: String, CodingKey {
        case user_id
        case nickname
        case public_key
        case joined_at
        case device_id
    }
}
