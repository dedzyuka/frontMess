import Foundation

// MARK: - User
class User: Identifiable, Codable {
    let userId: UUID
    var nickName: String
    var firstName: String?
    var lastName: String?
    var middleName: String?
    var email: String?
    var phone: String?
    var avatarUrl: String?
    var bio: String?
    var lastSeen: Date?
    var isOnline: Bool?
    var status: String?
    var emailVerified: Bool?
    var phoneVerified: Bool?
    var isAdmin: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    
    var id: UUID { userId }
    
    // Инициализатор с параметрами (можно оставить как есть, только свойства теперь var)
    init(userId: UUID, nickName: String, firstName: String?, lastName: String?, middleName: String?, email: String?, phone: String?, avatarUrl: String?, bio: String?, lastSeen: Date?, isOnline: Bool?, status: String?, emailVerified: Bool?, phoneVerified: Bool?, isAdmin: Bool?, createdAt: Date?, updatedAt: Date?) {
        self.userId = userId
        self.nickName = nickName
        self.firstName = firstName
        self.lastName = lastName
        self.middleName = middleName
        self.email = email
        self.phone = phone
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.lastSeen = lastSeen
        self.isOnline = isOnline
        self.status = status
        self.emailVerified = emailVerified
        self.phoneVerified = phoneVerified
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Codable – добавить required init и encode
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        nickName = try container.decode(String.self, forKey: .nickName)
        firstName = try? container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try? container.decodeIfPresent(String.self, forKey: .lastName)
        middleName = try? container.decodeIfPresent(String.self, forKey: .middleName)
        email = try? container.decodeIfPresent(String.self, forKey: .email)
        phone = try? container.decodeIfPresent(String.self, forKey: .phone)
        avatarUrl = try? container.decodeIfPresent(String.self, forKey: .avatarUrl)
        bio = try? container.decodeIfPresent(String.self, forKey: .bio)
        lastSeen = try? container.decodeIfPresent(Date.self, forKey: .lastSeen)
        isOnline = try? container.decodeIfPresent(Bool.self, forKey: .isOnline)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        emailVerified = try? container.decodeIfPresent(Bool.self, forKey: .emailVerified)
        phoneVerified = try? container.decodeIfPresent(Bool.self, forKey: .phoneVerified)
        isAdmin = try? container.decodeIfPresent(Bool.self, forKey: .isAdmin)
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(nickName, forKey: .nickName)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(middleName, forKey: .middleName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(lastSeen, forKey: .lastSeen)
        try container.encodeIfPresent(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(emailVerified, forKey: .emailVerified)
        try container.encodeIfPresent(phoneVerified, forKey: .phoneVerified)
        try container.encodeIfPresent(isAdmin, forKey: .isAdmin)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId, nickName, firstName, lastName, middleName, email, phone, avatarUrl, bio, lastSeen, isOnline, status, emailVerified, phoneVerified, isAdmin, createdAt, updatedAt
    }
}
struct Reaction: Identifiable, Codable {
    let id = UUID()
    let messageId: Int64
    let userId: UUID
    let emoji: String
    let createdAt: Date
}
// ./FrontDip/MessengerApp/Models/Models.swift (фрагмент)

struct Chat: Identifiable, Codable {
    let chatId: UUID
    let chatType: String   // "1" = private, "2" = group, "3" = channel
    let name: String?
    let description: String?
    let avatarUrl: String?
    let creatorId: UUID?
    let isPublic: Bool
    let maxMembers: Int
    let createdAt: Date
    let membersCount: Int
    var lastMessage: String?
    
    var lastMessagePreview: MessagePreview?
    var unreadCount: Int = 0
    var lastMessageStatus: MessageStatusType?
    var otherUserId: UUID?
    var otherUserNickname: String?
    var otherUserAvatarUrl: String?
    var otherUserIsOnline: Bool = false
    var isTyping: Bool = false
    
    var id: UUID { chatId }
    
    // ⭐️ Добавляем вычисляемое свойство
    var isPrivate: Bool {
        return chatType == "1" || chatType.lowercased() == "private"
    }
    
    var lastActivityDate: Date {
        return lastMessagePreview?.createdAt ?? createdAt
    }
    
    // Остальные CodingKeys и декодеры остаются без изменений
    enum CodingKeys: String, CodingKey {
        case chatId, chatType, name, description, avatarUrl, creatorId, isPublic, maxMembers, createdAt, membersCount, lastMessage, lastMessagePreview
    }
}

// MARK: - MessagePreview
struct MessagePreview: Codable {
    let messageId: Int64
    let senderId: UUID
    let senderNickname: String?
    let textPreview: String?
    let createdAt: Date
    let type: String
}
enum MessageStatusType {
    case sending
    case delivered
    case read
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
    var contactUser: User?   // теперь var
    
    var id: String { "\(userId.uuidString)-\(contactUserId.uuidString)" }
    
    enum CodingKeys: String, CodingKey {
        case userId, contactUserId, status, createdAt, updatedAt, contactUser
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

