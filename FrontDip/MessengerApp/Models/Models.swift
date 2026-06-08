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
    let chatType: String
    let name: String?
    let description: String?
    let avatarUrl: String?
    let creatorId: UUID?
    let isPublic: Bool
    let maxMembers: Int
    let createdAt: Date?          // ← изменили на опциональный
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
    var myRole: String?
    var joinPolicy: String?
    var visibility: String?
    
    var id: UUID { chatId }
    
    var isPrivate: Bool {
        return chatType == "1" || chatType.lowercased() == "private"
    }
    
    var isGroup: Bool {
        return chatType == "2" || chatType.lowercased() == "group"
    }
    
    var isChannel: Bool {
        return chatType == "3" || chatType.lowercased() == "channel"
    }
    
    var lastActivityDate: Date {
        return lastMessagePreview?.createdAt ?? (createdAt ?? Date.distantPast)
    }
    
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



struct Message: Identifiable, Codable {
    let messageId: Int64
    let chatId: UUID
    let senderId: UUID
    let replyToId: Int64?
    var content: String?
    let type: String
    let createdAt: Date
    var updatedAt: Date
    let deletedAt: Date?
    var isEdited: Bool
    var deliveredAt: Date?
    var readAt: Date?
    var reactions: [Reaction]?
    var attachments: [Attachment]?
    
    // НОВЫЕ ПОЛЯ ДЛЯ ПЕРЕСЫЛКИ
    var forwardedFromUserId: UUID?
    var forwardedFromNickname: String?
    var senderNickname: String?   // для отображения в пересылке
    
    // UI-поля для отображения ответа
    var replyToSenderName: String?
    var replyToContent: String?
    
    var id: Int64 { messageId }
    
    enum CodingKeys: String, CodingKey {
        case messageId, chatId, senderId, replyToId, content, type, createdAt, updatedAt, deletedAt, isEdited, deliveredAt, readAt, reactions, attachments
        case forwardedFromUserId, forwardedFromNickname, senderNickname
    }
    
    init(messageId: Int64, chatId: UUID, senderId: UUID, replyToId: Int64? = nil,
         content: String? = nil, type: String = "text", createdAt: Date, updatedAt: Date,
         deletedAt: Date? = nil, isEdited: Bool = false, deliveredAt: Date? = nil,
         readAt: Date? = nil, reactions: [Reaction]? = nil, attachments: [Attachment]? = nil,
         forwardedFromUserId: UUID? = nil, forwardedFromNickname: String? = nil,
         senderNickname: String? = nil,
         replyToSenderName: String? = nil, replyToContent: String? = nil) {
        self.messageId = messageId
        self.chatId = chatId
        self.senderId = senderId
        self.replyToId = replyToId
        self.content = content
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.isEdited = isEdited
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.reactions = reactions
        self.attachments = attachments
        self.forwardedFromUserId = forwardedFromUserId
        self.forwardedFromNickname = forwardedFromNickname
        self.senderNickname = senderNickname
        self.replyToSenderName = replyToSenderName
        self.replyToContent = replyToContent
    }
}


struct ChatMemberItem: Decodable, Identifiable {
    let user: User
    let role: String?
    let status: String?
    let joinedAt: Date
    let leftAt: Date?
    let bannedUntil: Date?
    
    var id: UUID { user.userId }
    var userId: UUID { user.userId }
    var nickName: String { user.nickName }
    var avatarUrl: String? { user.avatarUrl }
    var isOnline: Bool { user.isOnline ?? false }
}

// MARK: - Contact
// MARK: - Contact
struct Contact: Identifiable, Codable {
    let userId: UUID
    let contactUserId: UUID
    let status: String
    let createdAt: Date?
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

struct UpdateChatMemberResponse: Decodable {
    let chat: UpdateChatMemberWrapper
}
struct UpdateChatMemberWrapper: Decodable {
    let updateChatMember: Bool
}
struct ChatMemberResult: Decodable {
    let userId: UUID
    let role: String
    let status: String
}

// MARK: - Kick/Ban/Unban Response
struct KickMemberResponse: Decodable {
    let chat: KickMemberWrapper
}
struct KickMemberWrapper: Decodable {
    let kickMember: Bool
}

struct UnbanMemberResponse: Decodable {
    let chat: UnbanMemberWrapper
}
struct UnbanMemberWrapper: Decodable {
    let unbanMember: Bool
}

// MARK: - Leave Chat Response
struct LeaveChatResponse: Decodable {
    let chat: LeaveChatWrapper
}
struct LeaveChatWrapper: Decodable {
    let leaveChat: Bool
}

// MARK: - Join Chat Response
struct JoinChatResponse: Decodable {
    let chat: JoinChatWrapper
}
struct JoinChatWrapper: Decodable {
    let joinChat: Bool
}
struct ChatMemberJoined: Decodable {
    let userId: UUID
    let role: String
    let joinedAt: Date
}

// MARK: - Invite Link Response
struct InviteLinkResponse: Decodable {
    let chat: InviteLinkWrapper
}
struct InviteLinkWrapper: Decodable {
    let generateInviteLink: String   // теперь просто строка
}
struct InviteLink: Decodable {
    let inviteKey: String
    let expireAt: Date?
}

// MARK: - Update Chat Response
struct UpdateChatResponse: Decodable {
    let chat: UpdateChatWrapper
}
struct UpdateChatWrapper: Decodable {
    let update: Chat
}

// MARK: - Delete Chat Response
struct DeleteChatResponse: Decodable {
    let chat: DeleteChatWrapper
}
struct DeleteChatWrapper: Decodable {
    let delete: Bool
}
import Foundation

struct Call: Identifiable, Codable {
    let callId: UUID
    let chatId: UUID
    let initiatorId: UUID
    var status: String
    let type: String
    let startedAt: Date
    let endedAt: Date?
    
    var id: UUID { callId }
    
    var isIncoming: Bool {
        initiatorId != AppState.shared.currentUser?.userId
    }
    
    var isActive: Bool { status == "active" }
    var isPending: Bool { status == "pending" }
    
    init(callId: UUID, chatId: UUID, initiatorId: UUID, status: String, type: String, startedAt: Date, endedAt: Date? = nil) {
        self.callId = callId
        self.chatId = chatId
        self.initiatorId = initiatorId
        self.status = status
        self.type = type
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case callId, chatId, initiatorId, status, type, startedAt, endedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        callId = try container.decode(UUID.self, forKey: .callId)
        chatId = try container.decode(UUID.self, forKey: .chatId)
        initiatorId = try container.decode(UUID.self, forKey: .initiatorId)
        status = try container.decode(String.self, forKey: .status)
        type = try container.decode(String.self, forKey: .type)
        
        let startedAtRaw = try container.decode(String.self, forKey: .startedAt)
        startedAt = Self.parseProtobufTimestamp(startedAtRaw)
        
        if let endedAtRaw = try? container.decode(String.self, forKey: .endedAt), !endedAtRaw.isEmpty {
            endedAt = Self.parseProtobufTimestamp(endedAtRaw)
        } else {
            endedAt = nil
        }
    }
    
    private static func parseProtobufTimestamp(_ string: String) -> Date {
        let pattern = #"seconds:\s*(\d+)\s*\n\s*nanos:\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
           let secondsRange = Range(match.range(at: 1), in: string),
           let nanosRange = Range(match.range(at: 2), in: string),
           let seconds = Int64(string[secondsRange]),
           let nanos = Int32(string[nanosRange]) {
            let interval = TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000
            return Date(timeIntervalSince1970: interval)
        }
        // fallback: ISO8601
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(callId, forKey: .callId)
        try container.encode(chatId, forKey: .chatId)
        try container.encode(initiatorId, forKey: .initiatorId)
        try container.encode(status, forKey: .status)
        try container.encode(type, forKey: .type)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(isoFormatter.string(from: startedAt), forKey: .startedAt)
        if let endedAt = endedAt {
            try container.encode(isoFormatter.string(from: endedAt), forKey: .endedAt)
        } else {
            try container.encodeNil(forKey: .endedAt)
        }
    }
}
