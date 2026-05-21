import Foundation

struct GraphQLQueries {
    // MARK: - Users
    static let createUser = """
    mutation CreateUser($nickName: String!, $email: String!, $password: String!, $phone: String!) {
        user {
            create(nickName: $nickName, email: $email, password: $password, phone: $phone) {
                userId
                nickName
                email
                createdAt
                updatedAt
            }
        }
    }
    """
    
    static let login = """
    mutation Login($login: String!, $password: String!) {
        auth {
            login(login: $login, password: $password) {
                tokens {
                    accessToken
                    refreshToken
                    expiresIn
                }
                user {
                    userId
                    nickName
                    email
                    createdAt
                    updatedAt
                }
            }
        }
    }
    """
    
    static let refreshToken = """
    mutation RefreshToken($refreshToken: String!) {
        auth {
            refreshToken(refreshToken: $refreshToken) {
                tokens {
                    accessToken
                    refreshToken
                    expiresIn
                }
                user {
                    userId
                    nickName
                    email
                    createdAt
                    updatedAt
                }
            }
        }
    }
    """
    
    // MARK: - Chats
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
                membersCount
                createdAt
                updatedAt
                lastMessagePreview {
                    messageId
                    senderId
                    type
                    textPreview
                    createdAt
                    isDeleted
                }
            }
        }
    }
    """
    
    static let createChat = """
    mutation CreateChat($chatType: String!, $name: String, $memberIds: [String!]!, $isPublic: Boolean) {
        chat {
            create(chatType: $chatType, name: $name, memberIds: $memberIds, isPublic: $isPublic) {
                chatId
                name
                membersCount
                createdAt
            }
        }
    }
    """
    
    static let getChatMembers = """
    query GetChatMembers($chatId: String!) {
        chat {
            members(chatId: $chatId) {
                userId
                nickname
                joinedAt
            }
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
    
    // MARK: - Messages
    static let listMessages = """
    query ListMessages($chatId: String!, $limit: Int, $offset: Int) {
        message {
            listMessages(chatId: $chatId, limit: $limit, offset: $offset) {
                messageId
                chatId
                senderId
                content
                type
                createdAt
                updatedAt
                isEdited
            }
        }
    }
    """
    
    static let sendMessage = """
    mutation SendMessage($chatId: String!, $content: String!) {
        message {
            sendMessage(chatId: $chatId, content: $content) {
                messageId
                chatId
                senderId
                content
                type
                createdAt
                updatedAt
                isEdited
            }
        }
    }
    """
    
    // MARK: - Search
    static let searchUsers = """
    query SearchUsers($query: String!) {
        user {
            search(query: $query, page: 1, pageSize: 20) {
                userId
                nickName
                avatarUrl
                isOnline
            }
        }
    }
    """
}
// MARK: - Response Models

// User
struct CreateUserResponse: Decodable {
    let user: UserResponseWrapper
}
struct UserResponseWrapper: Decodable {
    let create: UserData
}
struct UserData: Decodable {
    let user_id: UUID
    let nick_name: String
    let email: String?
    let created_at: Date
    let updated_at: Date
}

// Auth
struct LoginResponse: Decodable {
    let auth: AuthResult
}
struct AuthResult: Decodable {
    let tokens: Tokens
    let user: UserData
}
struct Tokens: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

// Chat list
struct ListChatsResponse: Decodable {
    let chat: ChatListWrapper
}
struct ChatListWrapper: Decodable {
    let list: [ChatResponse]
}
struct ChatResponse: Decodable {
    let chat_id: UUID
    let chat_type: String
    let name: String?
    let description: String?
    let avatar_url: String?
    let creator_id: UUID?
    let is_public: Bool
    let members_count: Int
    let created_at: Date
    let updated_at: Date
    let last_message_preview: MessagePreviewResponse?
}
struct MessagePreviewResponse: Decodable {
    let message_id: Int
    let sender_id: String
    let type: String
    let text_preview: String?
    let created_at: Date
    let is_deleted: Bool
}

// Create chat
struct CreateChatResponse: Decodable {
    let chat: CreateChatWrapper
}
struct CreateChatWrapper: Decodable {
    let create: CreatedChat
}
struct CreatedChat: Decodable {
    let chat_id: UUID
    let chat_type: String
    let name: String?
    let created_at: Date
    let updated_at: Date
    let members_count: Int
}

// Chat members
struct ChatMembersResponse: Decodable {
    let chat: ChatMembersWrapper
}
struct ChatMembersWrapper: Decodable {
    let members: [ChatMemberItem]
}

struct AddChatMemberResponse: Decodable {
    let chat: AddChatMemberWrapper
}
struct AddChatMemberWrapper: Decodable {
    let add_member: AddMemberResult
}
struct AddMemberResult: Decodable {
    let user_id: UUID
}

// Contacts
struct ListContactsResponse: Decodable {
    let contact: ContactListWrapper
}
struct ContactListWrapper: Decodable {
    let list: [ContactResponseData]
}
struct ContactResponseData: Decodable {
    let user_id: UUID
    let contact_user_id: UUID
    let status: String
    let created_at: Date
    let updated_at: Date
    let contact_user: ContactUserInfo?
}

struct ContactUserInfo: Decodable {
    let user_id: UUID
    let nick_name: String
    let avatar_url: String?
}
struct AddContactResponse: Decodable {
    let contact: ContactAddWrapper
}
struct ContactAddWrapper: Decodable {
    let add: ContactResponseData
}
struct AcceptContactResponse: Decodable {
    let contact: ContactAcceptWrapper
}
struct ContactAcceptWrapper: Decodable {
    let accept: ContactResponseData
}
struct RemoveContactResponse: Decodable {
    let contact: ContactRemoveWrapper
}
struct ContactRemoveWrapper: Decodable {
    let remove: Bool
}

// Messages
struct ListMessagesResponse: Decodable {
    let message: MessageListWrapper
}
struct MessageListWrapper: Decodable {
    let list_messages: [MessageResponse]
}
struct MessageResponse: Decodable {
    let message_id: Int
    let chat_id: UUID
    let sender_id: UUID
    let content: String
    let type: String
    let created_at: Date
    let updated_at: Date
    let is_edited: Bool
}
struct SendMessageResponse: Decodable {
    let message: SendMessageWrapper
}
struct SendMessageWrapper: Decodable {
    let send_message: MessageResponse
}

// Search
struct SearchUsersResponse: Decodable {
    let user: SearchUsersWrapper
}
struct SearchUsersWrapper: Decodable {
    let search: [SearchedUser]
}
struct SearchedUser: Decodable {
    let user_id: UUID
    let nick_name: String
    let avatar_url: String?
    let is_online: Bool
}
