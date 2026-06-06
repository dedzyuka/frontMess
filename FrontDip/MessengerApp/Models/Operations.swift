import Foundation

import Foundation



struct GraphQLQueries {
    // MARK: - Auth
    static let login = """
    mutation Login($login: String!, $password: String!) {
        auth {
            login(login: $login, password: $password) {
                accessToken
                refreshToken
                expiresIn
                user {
                    userId
                    nickName
                    avatarUrl
                    isOnline
                }
            }
        }
    }
    """
    
    static let refreshToken = """
    mutation RefreshToken($refreshToken: String!) {
        auth {
            refreshToken(refreshToken: $refreshToken) {
                accessToken
                refreshToken
                expiresIn
                user {
                    userId
                    nickName
                    email
                    createdAt
                    updatedAt
                    avatarUrl
                    isOnline
                }
            }
        }
    }
    """
    
    static let createUser = """
    mutation CreateUser($nickName: String!, $email: String!, $password: String!, $phone: String!) {
        user {
            create(nickName: $nickName, email: $email, password: $password, phone: $phone) {
                userId
                nickName
                email
            }
        }
    }
    """
    
    // MARK: - Chats (исправленный listChats – без updatedAt)
    static let listChats = """
    query ListChats {
      chat {
        list {
          chatId
          chatType
          name
          description
          avatarUrl
          creatorId
          isPublic
          maxMembers
          membersCount
          createdAt
          lastMessage
          lastMessagePreview {
            messageId
            senderId
            senderNickname
            textPreview
            createdAt
            type
          }
        }
      }
    }
    """
    
    static let markAsRead = """
    mutation MarkAsRead($messageId: Int!, $chatId: String!) {
        message {
            markAsRead(messageId: $messageId, chatId: $chatId)
        }
    }
    """
    
    static let createChat = """
    mutation CreateChat($chatType: String!, $name: String, $memberIds: [String!]!, $isPublic: Boolean) {
        chat {
            create(chatType: $chatType, name: $name, memberIds: $memberIds, isPublic: $isPublic) {
                chatId
                chatType
                name
                createdAt
                membersCount
            }
        }
    }
    """
    
    static let addReaction = """
    mutation AddReaction($messageId: Int!, $chatId: String!, $emoji: String!) {
        message {
            addReaction(messageId: $messageId, chatId: $chatId, emoji: $emoji) {
                messageId
                userId
                emoji
                createdAt
            }
        }
    }
    """

    static let removeReaction = """
    mutation RemoveReaction($messageId: Int!, $chatId: String!, $emoji: String!) {
        message {
            removeReaction(messageId: $messageId, chatId: $chatId, emoji: $emoji)
        }
    }
    """
    
    static let addChatMember = """
    mutation AddChatMember($chatId: String!, $userId: String!) {
        chat {
            addMember(chatId: $chatId, userId: $userId) {
                userId
            }
        }
    }
    """
    
    // MARK: - Messages
    static let listMessages = """
    query ListMessages($chatId: String!, $page: Int, $pageSize: Int) {
        message {
            listMessages(chatId: $chatId, page: $page, pageSize: $pageSize) {
                messageId
                chatId
                senderId
                content
                type
                replyToId
                createdAt
                updatedAt
                isEdited
                attachments {
                    attachmentId
                    fileName
                    fileSize
                    mimeType
                    storagePath
                }
                reactions {
                    messageId
                    userId
                    emoji
                    createdAt
                }
            }
        }
    }
    """
    
    static let sendMessage = """
    mutation SendMessage($chatId: String!, $content: String!, $attachmentId: String) {
        message {
            sendMessage(chatId: $chatId, content: $content, attachmentId: $attachmentId) {
                messageId
                chatId
                senderId
                content
                type
                createdAt
                updatedAt
                isEdited
                attachments {
                    attachmentId
                    fileName
                    fileSize
                    mimeType
                    storagePath
                }
            }
        }
    }
    """
    
    // MARK: - Contacts
    static let listContacts = """
    query ListContacts($status: String) {
        contact {
            list(status: $status) {
                userId
                contactUserId
                status
                createdAt
                updatedAt
                contactUser {
                    userId
                    nickName
                    avatarUrl
                    isOnline
                }
            }
        }
    }
    """
    
    static let addContact = """
    mutation AddContact($contactUserId: String!) {
        contact {
            add(contactUserId: $contactUserId) {
                userId
                contactUserId
                status
                createdAt
            }
        }
    }
    """
    
    static let acceptContact = """
    mutation AcceptContact($contactUserId: String!) {
        contact {
            accept(contactUserId: $contactUserId) {
                userId
                contactUserId
                status
                updatedAt
            }
        }
    }
    """
    
    static let removeContact = """
    mutation RemoveContact($contactUserId: String!) {
        contact {
            remove(contactUserId: $contactUserId)
        }
    }
    """
    
    static let incomingRequests = """
    query IncomingRequests {
        contact {
            incoming {
                userId
                contactUserId
                status
                createdAt
                contactUser {
                    userId
                    nickName
                    avatarUrl
                }
            }
        }
    }
    """
    
    // MARK: - Search
    static let searchUsers = """
    query SearchUsers($query: String!) {
        user {
            search(query: $query, page: 1) {
                userId
                nickName
                avatarUrl
                isOnline
            }
        }
    }
    """
    
    static let updateMessage = """
    mutation UpdateMessage($messageId: Int!, $chatId: String!, $content: String!) {
        message {
            updateMessage(messageId: $messageId, chatId: $chatId, content: $content) {
                messageId
                chatId
                senderId
                content
                type
                replyToId
                createdAt
                updatedAt
                isEdited
            }
        }
    }
    """

    static let deleteMessage = """
    mutation DeleteMessage($messageId: Int!, $chatId: String!) {
        message {
            deleteMessage(messageId: $messageId, chatId: $chatId)
        }
    }
    """
    
    static let getUser = """
    query GetUser($userId: String!) {
        user {
            get(id: $userId) {
                userId
                nickName
                firstName
                lastName
                middleName
                email
                phone
                avatarUrl
                bio
                lastSeen
                isOnline
                status
                emailVerified
                phoneVerified
                isAdmin
                createdAt
                updatedAt
            }
        }
    }
    """
    
    static let getChatMembers = """
    query GetChatMembers($chatId: String!) {
        chat {
            members(chatId: $chatId) {
                user {
                    userId
                    nickName
                    avatarUrl
                    isOnline
                }
                role
                status
                joinedAt
                leftAt
                bannedUntil
            }
        }
    }
    """

    static let getChatMemberIds = """
    query GetChatMemberIds($chatId: String!) {
        chat {
            members(chatId: $chatId) {
                user {
                    userId
                }
            }
        }
    }
    """
    
    static let getMessage = """
    query GetMessage($messageId: Int!, $chatId: String!) {
        message {
            getMessage(messageId: $messageId, chatId: $chatId) {
                messageId
                chatId
                senderId
                content
                type
                replyToId
                createdAt
                updatedAt
                isEdited
                attachments {
                    attachmentId
                    fileName
                    fileSize
                    mimeType
                    storagePath
                }
                reactions {
                    messageId
                    userId
                    emoji
                    createdAt
                }
            }
        }
    }
    """
    
    static let updateUser = """
    mutation UpdateUser($userId: String!, $nickName: String, $firstName: String, $lastName: String, $middleName: String, $email: String, $phone: String, $avatarUrl: String, $bio: String) {
        user {
            update(userId: $userId, nickName: $nickName, firstName: $firstName, lastName: $lastName, middleName: $middleName, email: $email, phone: $phone, avatarUrl: $avatarUrl, bio: $bio) {
                userId
                nickName
                firstName
                lastName
                middleName
                email
                phone
                avatarUrl
                bio
                lastSeen
                isOnline
                status
                emailVerified
                phoneVerified
                isAdmin
                createdAt
                updatedAt
            }
        }
    }
    """

    static let myProfile = """
    query MyProfile {
        user {
            myProfile {
                userId
                nickName
                firstName
                lastName
                middleName
                email
                phone
                avatarUrl
                bio
                lastSeen
                isOnline
                status
                emailVerified
                phoneVerified
                isAdmin
                createdAt
                updatedAt
            }
        }
    }
    """

    static let myPrivacy = """
    query MyPrivacy {
        user {
            myPrivacy {
                whoCanWriteMe
                whoCanAddToGroups
                whoCanSeePhone
                whoCanSeeLastSeen
                updatedAt
            }
        }
    }
    """

    static let updatePrivacy = """
    mutation UpdatePrivacy($whoCanWriteMe: String, $whoCanAddToGroups: String, $whoCanSeePhone: String, $whoCanSeeLastSeen: String) {
        user {
            updatePrivacy(input: {
                whoCanWriteMe: $whoCanWriteMe
                whoCanAddToGroups: $whoCanAddToGroups
                whoCanSeePhone: $whoCanSeePhone
                whoCanSeeLastSeen: $whoCanSeeLastSeen
            }) {
                whoCanWriteMe
                whoCanAddToGroups
                whoCanSeePhone
                whoCanSeeLastSeen
                updatedAt
            }
        }
    }
    """

    static let listSessions = """
    query ListSessions {
        auth {
            sessions {
                sessionId
                deviceInfo
                userAgent
                ipAddress
                createdAt
                lastSeenAt
                isCurrent
            }
        }
    }
    """

    static let revokeSession = """
    mutation RevokeSession($sessionId: String!) {
        auth {
            revokeSession(sessionId: $sessionId)
        }
    }
    """

    static let logoutAllOtherSessions = """
    mutation LogoutAllOtherSessions {
        auth {
            logoutAllOtherSessions
        }
    }
    """
    
    static let updateChat = """
    mutation UpdateChat($chatId: String!, $name: String, $description: String, $avatarUrl: String, $isPublic: Boolean, $maxMembers: Int) {
        chat {
            update(chatId: $chatId, name: $name, description: $description, avatarUrl: $avatarUrl, isPublic: $isPublic, maxMembers: $maxMembers) {
                chatId
                chatType
                name
                description
                avatarUrl
                isPublic
                maxMembers
                membersCount
            }
        }
    }
    """

    static let deleteChat = """
    mutation DeleteChat($chatId: String!) {
        chat { delete(chatId: $chatId) }
    }
    """

    // Исправленный запрос – возвращает Boolean, без выбора полей
    static let updateChatMember = """
    mutation UpdateChatMember($chatId: String!, $userId: String!, $role: String) {
        chat {
            updateChatMember(chatId: $chatId, userId: $userId, role: $role)
        }
    }
    """

    static let kickMember = """
    mutation KickMember($chatId: String!, $userId: String!) {
        chat { kickMember(chatId: $chatId, userId: $userId) }
    }
    """

    static let banMember = """
    mutation BanMember($chatId: String!, $userId: String!, $bannedUntil: String) {
        chat { banMember(chatId: $chatId, userId: $userId, bannedUntil: $bannedUntil) }
    }
    """

    static let unbanMember = """
    mutation UnbanMember($chatId: String!, $userId: String!) {
        chat { unbanMember(chatId: $chatId, userId: $userId) }
    }
    """

    static let leaveChat = """
    mutation LeaveChat($chatId: String!) {
        chat { leaveChat(chatId: $chatId) }
    }
    """

    static let joinChatWithToken = """
    mutation JoinChatWithToken($inviteToken: String!) {
        chat {
            joinChat(inviteToken: $inviteToken)
        }
    }
    """

    static let generateInviteLink = """
    query GenerateInviteLink($chatId: String!) {
        chat {
            generateInviteLink(chatId: $chatId)
        }
    }
    """
}

struct UpdateMessageResponse: Decodable {
    let message: UpdateMessageWrapper
}
struct UpdateMessageWrapper: Decodable {
    let updateMessage: Message
}

struct DeleteMessageResponse: Decodable {
    let message: DeleteMessageWrapper
}
struct DeleteMessageWrapper: Decodable {
    let deleteMessage: Bool
}

struct ChatMemberIdsResponse: Decodable {
    let chat: ChatMemberIdsWrapper
}
struct ChatMemberIdsWrapper: Decodable {
    let members: [ChatMemberIdItem]
}
struct ChatMemberIdItem: Decodable {
    let user: UserIdWrapper
    
    var userId: UUID {
        user.userId
    }
}

struct UserIdWrapper: Decodable {
    let userId: UUID
}

struct Tokens: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    
    enum CodingKeys: String, CodingKey {
        case access_token = "accessToken"
        case refresh_token = "refreshToken"
        case expires_in = "expiresIn"
    }
}


// Models.swift (фрагмент)
// Models.swift (только структура Attachment, остальное без изменений)
struct Attachment: Codable {
    let attachmentId: UUID
    let fileName: String
    let fileSize: Int?
    let mimeType: String?
    let storagePath: String
    let uploadedAt: Date?
    let messageCreatedAt: Date?      // новое поле
    
    enum CodingKeys: String, CodingKey {
        case attachmentId
        case fileName
        case fileSize
        case mimeType
        case storagePath
        case uploadedAt
        case messageCreatedAt = "message_created_at"
    }
}

struct GetMessageResponse: Decodable {
    let message: GetMessageWrapper
}
struct GetMessageWrapper: Decodable {
    let getMessage: Message
}

struct BanMemberResponse: Decodable {
    let chat: BanMemberWrapper
}
struct BanMemberWrapper: Decodable {
    let banMember: Bool
}
