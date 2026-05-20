import Foundation

// MARK: - Chat Responses
struct ChatsResponse: Decodable {
    struct ChatData: Decodable {
        let list: [Chat]
    }
    let chat: ChatData
}






struct APIUser: Decodable {
    let user_id: String
    let nick_name: String
    let avatar_url: String?
    let is_online: Bool
}

// MARK: - Contact Responses
struct AddMemberResponse: Decodable {
    struct ChatData: Decodable {
        let add_member: Bool
    }
    let chat: ChatData
}

struct MembersResponse: Decodable {
    struct ChatData: Decodable {
        struct Member: Decodable {
            let user_id: String
            let nick_name: String
            let joined_at: Date
        }
        let members: [Member]
    }
    let chat: ChatData
}
