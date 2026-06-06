import Foundation

// MARK: - Login Response
struct SearchMessagesResponse: Decodable {
    let message: SearchMessagesWrapper
}
struct SearchMessagesWrapper: Decodable {
    let searchMessages: [Message]
}
struct LoginResponse: Decodable {
    let auth: AuthLogin
}
struct AuthLogin: Decodable {
    let login: LoginResult
}
struct LoginResult: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: UserData
}
struct UserData: Decodable {
    let userId: UUID
    let nickName: String
    let avatarUrl: String?
    let isOnline: Bool
    let email: String?
}

// MARK: - Refresh Response
struct RefreshResponse: Decodable {
    let auth: AuthRefresh
}
struct AuthRefresh: Decodable {
    let refreshToken: RefreshResult
}
struct RefreshResult: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: UserData
}

// MARK: - Create User Response
struct CreateUserResponse: Decodable {
    let user: CreateUserResult
}
struct CreateUserResult: Decodable {
    let create: CreatedUser
}
struct CreatedUser: Decodable {
    let userId: UUID
    let nickName: String
    let email: String
}

// MARK: - Chat List Response
struct ListChatsResponse: Decodable {
    let chat: ChatListWrapper
}
struct ChatListWrapper: Decodable {
    let list: [Chat]
}

// MARK: - Create Chat Response
struct CreateChatResponse: Decodable {
    let chat: CreateChatWrapper
}
struct CreateChatWrapper: Decodable {
    let create: CreatedChat
}
struct CreatedChat: Decodable {
    let chatId: UUID
    let chatType: String
    let name: String?
    let createdAt: Date
    let updatedAt: Date?
    let membersCount: Int
    
}

// MARK: - Chat Members Response
struct ChatMembersResponse: Decodable {
    let chat: ChatMembersWrapper
}
struct ChatMembersWrapper: Decodable {
    let members: [ChatMemberItem]
}

// MARK: - Add Chat Member Response
struct AddChatMemberResponse: Decodable {
    let chat: AddChatMemberWrapper
}
struct AddChatMemberWrapper: Decodable {
    let addMember: AddMemberResult
}
struct AddMemberResult: Decodable {
    let userId: UUID
}
struct AddReactionResponse: Decodable {
    let message: AddReactionWrapper
}
struct AddReactionWrapper: Decodable {
    let addReaction: Reaction
}

struct RemoveReactionResponse: Decodable {
    let message: RemoveReactionWrapper
}
struct RemoveReactionWrapper: Decodable {
    let removeReaction: Bool
}
// MARK: - Messages Response
struct ListMessagesResponse: Decodable {
    let message: MessageListWrapper
}
struct MessageListWrapper: Decodable {
    let listMessages: [Message]
}

// MARK: - Send Message Response
struct SendMessageResponse: Decodable {
    let message: SendMessageWrapper
}
struct SendMessageWrapper: Decodable {
    let sendMessage: Message
}

// MARK: - Contacts Response
struct ListContactsResponse: Decodable {
    let contact: ContactListWrapper
}
struct ContactListWrapper: Decodable {
    let list: [Contact]
}

struct AddContactResponse: Decodable {
    let contact: ContactAddWrapper
}
struct ContactAddWrapper: Decodable {
    let add: Contact
}

struct AcceptContactResponse: Decodable {
    let contact: ContactAcceptWrapper
}
struct ContactAcceptWrapper: Decodable {
    let accept: Contact
}

struct RemoveContactResponse: Decodable {
    let contact: ContactRemoveWrapper
}
struct ContactRemoveWrapper: Decodable {
    let remove: Bool
}

// MARK: - Search Response
struct SearchUsersResponse: Decodable {
    let user: SearchUsersWrapper
}
struct SearchUsersWrapper: Decodable {
    let search: [UserPublicResponse]
}

struct IncomingContactsResponse: Decodable {
    let contact: IncomingContactWrapper
}
struct IncomingContactWrapper: Decodable {
    let incoming: [Contact]
}

struct MyProfileResponse: Decodable {
    let user: MyProfileWrapper
}
struct MyProfileWrapper: Decodable {
    let myProfile: User
}

struct MyPrivacyResponse: Decodable {
    let user: PrivacyWrapper
}
struct PrivacyWrapper: Decodable {
    let myPrivacy: PrivacySettingsResponse
}
struct PrivacySettingsResponse: Decodable {
    let whoCanWriteMe: String
    let whoCanAddToGroups: String
    let whoCanSeePhone: String
    let whoCanSeeLastSeen: String
    let updatedAt: Date?
}

struct UpdatePrivacyResponse: Decodable {
    let user: UpdatePrivacyWrapper
}
struct UpdatePrivacyWrapper: Decodable {
    let updatePrivacy: PrivacySettingsResponse
}

struct ListSessionsResponse: Decodable {
    let auth: SessionsWrapper
}
struct SessionsWrapper: Decodable {
    let sessions: [SessionInfo]
}
struct SessionInfo: Decodable {
    let sessionId: String
    let deviceInfo: String?
    let userAgent: String?
    let ipAddress: String?
    let createdAt: Date?
    let lastSeenAt: Date?
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case sessionId
        case deviceInfo
        case userAgent
        case ipAddress
        case createdAt
        case lastSeenAt
        case isCurrent
    }

    // Внутренний enum для парсинга Protobuf Timestamp
    private enum TimestampKeys: String, CodingKey {
        case seconds
        case nanos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionId = try container.decode(String.self, forKey: .sessionId)
        deviceInfo = try? container.decodeIfPresent(String.self, forKey: .deviceInfo)
        userAgent = try? container.decodeIfPresent(String.self, forKey: .userAgent)
        ipAddress = try? container.decodeIfPresent(String.self, forKey: .ipAddress)
        isCurrent = try container.decode(Bool.self, forKey: .isCurrent)

        // Функция парсинга Protobuf Timestamp
        func parseProtobufTimestamp(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
            // Пробуем извлечь как вложенный контейнер с полями seconds/nanos
            guard let timestampContainer = try? container.nestedContainer(keyedBy: TimestampKeys.self, forKey: key) else {
                // Если не получилось, возможно это уже строка ISO8601 (запасной вариант)
                if let dateString = try? container.decode(String.self, forKey: key) {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter.date(from: dateString)
                }
                return nil
            }
            let seconds = try timestampContainer.decode(Int64.self, forKey: .seconds)
            let nanos = try timestampContainer.decode(Int32.self, forKey: .nanos)
            let interval = TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000
            return Date(timeIntervalSince1970: interval)
        }

        createdAt = try? parseProtobufTimestamp(container, forKey: .createdAt)
        lastSeenAt = try? parseProtobufTimestamp(container, forKey: .lastSeenAt)
    }
}

struct RevokeSessionResponse: Decodable {
    let auth: RevokeWrapper
}
struct RevokeWrapper: Decodable {
    let revokeSession: Bool
}

struct LogoutAllResponse: Decodable {
    let auth: LogoutAllWrapper
}
struct LogoutAllWrapper: Decodable {
    let logoutAllOtherSessions: Bool
}
struct UpdateUserResponse: Decodable {
    let user: UpdateUserWrapper
}
struct UpdateUserWrapper: Decodable {
    let update: User
}

// MARK: - Custom Decoder for Protobuf Timestamp in SessionInfo
private struct ProtobufTimestampCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
    
    static let seconds = ProtobufTimestampCodingKeys(stringValue: "seconds")
    static let nanos = ProtobufTimestampCodingKeys(stringValue: "nanos")
}

