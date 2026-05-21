import Foundation

// MARK: - User
struct User: Identifiable, Codable {
    let user_id: UUID
    let nick_name: String
    let first_name: String?
    let last_name: String?
    let middle_name: String?
    let email: String?
    let phone: String?
    let avatar_url: String?
    let bio: String?
    let last_seen: Date?
    let is_online: Bool
    let status: String
    let email_verified: Bool
    let phone_verified: Bool
    let is_admin: Bool
    let created_at: Date
    let updated_at: Date
    
    var id: UUID { user_id }
}

// MARK: - Chat
struct Chat: Identifiable, Codable {
    let chat_id: UUID
    let chat_type: String
    let name: String?
    let description: String?
    let avatar_url: String?
    let creator_id: UUID?
    let is_public: Bool
    let max_members: Int
    let created_at: Date
    let updated_at: Date
    let last_activity_at: Date?
    let visibility: String
    let join_policy: String
    let members_count: Int
    let last_message_preview: MessagePreview?
    
    var id: UUID { chat_id }
}

// MARK: - MessagePreview
struct MessagePreview: Codable {
    let message_id: Int64
    let sender_id: UUID
    let type: String
    let text_preview: String?
    let created_at: Date
    let is_deleted: Bool
}

// MARK: - Message
struct Message: Identifiable, Codable {
    let message_id: Int64
    let chat_id: UUID
    let sender_id: UUID
    let reply_to_id: Int64?
    let content: String?
    let type: String
    let created_at: Date
    let updated_at: Date
    let deleted_at: Date?
    let is_edited: Bool
    
    var id: Int64 { message_id }
}

// MARK: - ChatMember
struct ChatMemberItem: Codable {
    let user_id: UUID
    let nickname: String
    let joined_at: Date
}

// MARK: - Contact
struct Contact: Identifiable, Codable {
    let id: UUID  // локальный ID
    let user_id: UUID
    let contact_user_id: UUID
    let status: String
    let created_at: Date
    let updated_at: Date
    let contact_user: User?
    
    var contact_id: UUID { id }
}

// MARK: - ContactRequest (входящие заявки)
struct ContactRequest: Identifiable, Codable {
    let id: UUID
    let from_user_id: UUID
    let from_nickname: String
    let from_avatar_url: String?
    let status: String
    let created_at: Date
    
    var contact_request_id: UUID { id }
}

// MARK: - Search result
struct UserPublicResponse: Identifiable, Codable {
    let user_id: UUID
    let nick_name: String
    let avatar_url: String?
    let is_online: Bool
    
    var id: UUID { user_id }
}
