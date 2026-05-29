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
    
    var isOnline: Bool?
    let status: String?          // опционально
    let emailVerified: Bool?
    let phoneVerified: Bool?
    let isAdmin: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    
    var id: UUID { userId }
}
struct Reaction: Identifiable, Codable {
    let id = UUID()
    let messageId: Int64
    let userId: UUID
    let emoji: String
    let createdAt: Date
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
    let createdAt: Date
    let membersCount: Int
    var lastMessage: String?   // ← строковое поле

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
    var content: String?           // теперь var
    let type: String
    let createdAt: Date
    var updatedAt: Date            // теперь var
    let deletedAt: Date?
    var isEdited: Bool             // теперь var
    var deliveredAt: Date?         // теперь var
    var readAt: Date?              // теперь var
    var reactions: [Reaction]? = nil
    var attachments: [Attachment]? = nil
    
    var id: Int64 { messageId }
}

struct Attachment: Codable {
    let attachmentId: UUID
    let fileName: String
    let fileSize: Int?
    let mimeType: String?
    let storagePath: String
}

// MARK: - ChatMember
struct ChatMemberItem: Decodable {
    let userId: UUID
    let nickName: String
    let avatarUrl: String?
    let isOnline: Bool
}

// MARK: - Contact
// MARK: - Contact
struct Contact: Identifiable, Codable {
    let userId: UUID
    let contactUserId: UUID
    let status: String
    let createdAt: Date
    let updatedAt: Date?
    let contactUser: User?
    
    // Вычисляемое свойство для Identifiable (не участвует в декодировании)
    var id: String {
        "\(userId.uuidString)-\(contactUserId.uuidString)"
    }
    
    enum CodingKeys: String, CodingKey {
        case userId
        case contactUserId
        case status
        case createdAt
        case updatedAt
        case contactUser
    }
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

