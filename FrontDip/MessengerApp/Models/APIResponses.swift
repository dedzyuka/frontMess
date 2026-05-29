import Foundation

// MARK: - Login Response
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
    let updatedAt: Date
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
