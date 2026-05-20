import Foundation

struct GraphQLQueries {
    // MARK: - Users
    static let createUser = """
    mutation CreateUser($nickname: String!, $email: String!, $password: String!, $phone: String!) {
      user {
        create(nick_name: $nickname, email: $email, password: $password, phone: $phone) {
          user_id
          nick_name
          email
          phone
          created_at
          updated_at
        }
      }
    }
    """
    
    static let getUser = """
    query GetUser($userId: UUID!) {
      getUser(user_id: $userId) {
        user_id
        nick_name
        email
        phone
        created_at
        updated_at
      }
    }
    """
    
    // MARK: - Auth
    static let login = """
    mutation Login($login: String!, $password: String!) {
      auth {
        login(login: $login, password: $password) {
          tokens {
            access_token
            refresh_token
            expires_in
          }
          user {
            user_id
            nick_name
            email
            created_at
            updated_at
          }
        }
      }
    }
    """
    
    static let refreshToken = """
    mutation RefreshToken($refreshToken: String!) {
      auth {
        refreshToken(refresh_token: $refreshToken) {
          tokens {
            access_token
            refresh_token
            expires_in
          }
          user {
            user_id
            nick_name
            email
            created_at
            updated_at
          }
        }
      }
    }
    """
    
    // MARK: - Chats
    static let listChats = """
    query ListChats($userId: UUID!) {
      listChats(user_id: $userId) {
        chats {
          chat_id
          name
          members_count
          created_at
        }
        total_count
      }
    }
    """
    
    static let createChat = """
    mutation CreateChat($input: CreateChatInput!) {
      createChat(input: $input) {
        chat_id
        name
        members_count
        created_at
      }
    }
    """
    
    static let getChatMembers = """
    query GetChatMembers($chatId: UUID!) {
      chatMembers(chat_id: $chatId) {
        user_id
        nickname
        public_key
        joined_at
        device_id
      }
    }
    """
    
    static let listChatMembers = """
    query ListChatMembers($chatId: UUID!) {
      listChatMembers(chat_id: $chatId) {
        members {
          user_id
          nickname
          public_key
          joined_at
          device_id
        }
      }
    }
    """
    
    static let addChatMember = """
    mutation AddChatMember($chatId: UUID!, $userId: UUID!) {
      addChatMember(chat_id: $chatId, user_id: $userId) {
        user_id
      }
    }
    """
    
    // MARK: - Contacts
    static let listContacts = """
    query ListContacts($status: String) {
      contacts(status: $status) {
        user_id
        contact_user_id
        status
        created_at
        contact_user {
          user_id
          nick_name
          public_key
        }
      }
    }
    """
    
    static let addContact = """
    mutation AddContact($contactUserId: UUID!) {
      addContact(contact_user_id: $contactUserId) {
        user_id
        contact_user_id
        status
        created_at
      }
    }
    """
    
    static let acceptContact = """
    mutation AcceptContact($contactUserId: UUID!) {
      acceptContact(contact_user_id: $contactUserId) {
        user_id
        contact_user_id
        status
        created_at
      }
    }
    """
    
    static let removeContact = """
    mutation RemoveContact($contactUserId: UUID!) {
      removeContact(contact_user_id: $contactUserId) {
        user_id
        contact_user_id
        status
      }
    }
    """
}

// MARK: - Response Models
struct CreateUserResponse: Decodable {
    let user: UserResponse
}

struct LoginResponse: Decodable {
    let auth: AuthLoginResult
}

struct AuthLoginResult: Decodable {
    let tokens: Tokens
    let user: UserResponse
}

struct Tokens: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

struct UserResponse: Decodable {
    let userId: UUID
    let nickName: String
    let email: String?
    let phone: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickName = "nick_name"
        case email
        case phone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ListChatsResponse: Decodable {
    let listChats: ChatListResult
}

struct ChatListResult: Decodable {
    let chats: [ChatResponse]
    let totalCount: Int
}

struct ChatResponse: Decodable {
    let chatId: UUID
    let name: String?
    let membersCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case name
        case membersCount = "members_count"
        case createdAt = "created_at"
    }
}

struct ChatMembersListResponse: Decodable {
    let listChatMembers: ChatMembersResult
}

struct ChatMembersResult: Decodable {
    let members: [ChatMemberItem]
}

struct ChatMemberItem: Decodable {
    let userId: UUID
    let nickname: String
    let publicKey: String
    let joinedAt: Date
    let deviceId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
        case publicKey = "public_key"
        case joinedAt = "joined_at"
        case deviceId = "device_id"
    }
}

struct AddChatMemberResponse: Decodable {
    let addChatMember: AddChatMemberResult
    struct AddChatMemberResult: Decodable {}
}

struct AddContactResponse: Decodable {
    let addContact: ContactResponseData
}

struct AcceptContactResponse: Decodable {
    let acceptContact: ContactResponseData
}

struct RemoveContactResponse: Decodable {
    let removeContact: ContactResponseData?
}

struct ListContactsResponse: Decodable {
    let contacts: [ContactResponseData]
}

struct ContactResponseData: Decodable {
    let userId: UUID
    let contactUserId: UUID
    let status: String
    let createdAt: Date
    let contactUser: ContactUserInfo?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contactUserId = "contact_user_id"
        case status
        case createdAt = "created_at"
        case contactUser = "contact_user"
    }
}

struct ContactUserInfo: Decodable {
    let userId: UUID
    let nickName: String
    let publicKey: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickName = "nick_name"
        case publicKey = "public_key"
    }
}

struct CreateChatGraphQLResponse: Decodable {
    let createChat: CreatedChat
}

// Если CreatedChat уже есть в CreateChatViewModel, можно удалить дубликат.
// Для уверенности оставим:

