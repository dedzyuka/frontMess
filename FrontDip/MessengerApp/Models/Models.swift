import Foundation

// MARK: - User
struct User: Identifiable, Codable {
    let userId: UUID
    let nickName: String
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let email: String?
    let phone: String?
    let avatarUrl: String?
    let bio: String?
    let lastSeen: Date?
    let isOnline: Bool
    let status: String?          // опционально
    let emailVerified: Bool?
    let phoneVerified: Bool?
    let isAdmin: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    
    var id: UUID { userId }
}

struct Chat: Identifiable, Codable {
    let chatId: UUID
    let chatType: String
    let name: String?
    let description: String?
    let avatarUrl: String?
    let creatorId: UUID?
    let isPublic: Bool
    let maxMembers: Int
    let createdAt: Date      // снова Date
    let membersCount: Int
    let lastMessage: String?
    
    var id: UUID { chatId } 
}

// MARK: - MessagePreview
struct MessagePreview: Codable {
    let messageId: Int64
    let senderId: UUID
    let type: String
    let textPreview: String?
    let createdAt: Date
    let isDeleted: Bool
}



// MARK: - Message
struct Message: Identifiable, Codable {
    let messageId: Int64
    let chatId: UUID
    let senderId: UUID
    let replyToId: Int64?
    let content: String?
    let type: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let isEdited: Bool
    
    var id: Int64 { messageId }
}

// MARK: - ChatMember
struct ChatMemberItem: Codable {
    let userId: UUID
    let nickname: String
    let joinedAt: Date
}

// MARK: - Contact
struct Contact: Identifiable, Codable {
    let id = UUID()
    let userId: UUID
    let contactUserId: UUID
    let status: String
    let createdAt: Date
    let updatedAt: Date?
    let contactUser: User?   // ← теперь UserPublic, а не User
}

// MARK: - ContactRequest (входящие)
struct ContactRequest: Identifiable, Codable {
    let id = UUID()
    let fromUserId: UUID
    let fromNickname: String
    let fromAvatarUrl: String?
    let status: String
    let createdAt: Date
}

// MARK: - Search result
struct UserPublicResponse: Identifiable, Codable {
    let userId: UUID
    let nickName: String
    let avatarUrl: String?
    let isOnline: Bool?
    
    var id: UUID { userId }
}

