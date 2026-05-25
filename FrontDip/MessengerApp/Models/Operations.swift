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
    mutation CreateUser($nickName: String!, $email: String!, $password: String!, $phone: String) {
        user {
            create(nickName: $nickName, email: $email, password: $password, phone: $phone) {
                userId
                nickName
                email
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
          maxMembers
          membersCount
          createdAt
          lastMessage
        }
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
    
    static let getChatMembers = """
    query GetChatMembers($chatId: String!) {
        chat {
            members(chatId: $chatId)
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

struct ChatMembersIdResponse: Decodable {
    let chat: MembersIdWrapper
}
struct MembersIdWrapper: Decodable {
    let members: [String]
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


