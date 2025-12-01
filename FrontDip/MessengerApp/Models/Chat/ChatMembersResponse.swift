import Foundation

struct ChatMembersResponse: Codable {
    let chat_id: UUID
    let members: [ChatMemberDetailed]
    let total_members: Int
    
    enum CodingKeys: String, CodingKey {
        case chat_id
        case members
        case total_members
    }
}
