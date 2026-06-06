import Foundation

class ChatService {
    static let shared = ChatService()
    private let graphQL = GraphQLClient.shared
    private init() {}
    
    // MARK: - Update Chat
    func updateChat(chatId: UUID, name: String?, description: String?, avatarUrl: String?, isPublic: Bool?, maxMembers: Int?) async throws -> Chat {
        var variables: [String: Any] = ["chatId": chatId.uuidString]
        if let name = name { variables["name"] = name }
        if let description = description { variables["description"] = description }
        if let avatarUrl = avatarUrl { variables["avatarUrl"] = avatarUrl }
        if let isPublic = isPublic { variables["isPublic"] = isPublic }
        if let maxMembers = maxMembers { variables["maxMembers"] = maxMembers }
        let response: UpdateChatResponse = try await graphQL.perform(
            query: GraphQLQueries.updateChat,
            variables: variables,
            responseType: UpdateChatResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.chat.update
    }
    
    // MARK: - Delete Chat
    func deleteChat(chatId: UUID) async throws -> Bool {
        let response: DeleteChatResponse = try await graphQL.perform(
            query: GraphQLQueries.deleteChat,
            variables: ["chatId": chatId.uuidString],
            responseType: DeleteChatResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.chat.delete
    }
    
    // MARK: - Update Member Role (исправлен тип ответа)
    func updateMemberRole(chatId: UUID, userId: UUID, role: String) async throws {
        let variables: [String: Any] = ["chatId": chatId.uuidString, "userId": userId.uuidString, "role": role]
        // Ответ теперь просто Boolean, обёрнутый в структуру
        struct BoolResponse: Decodable {
            let chat: BoolWrapper
        }
        struct BoolWrapper: Decodable {
            let unbanMember: Bool?   // может быть kickMember или unbanMember
            let kickMember: Bool?
            
            enum CodingKeys: String, CodingKey {
                case unbanMember
                case kickMember
            }
        }
        let _: BoolResponse = try await graphQL.perform(
            query: GraphQLQueries.updateChatMember,
            variables: variables,
            responseType: BoolResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    // MARK: - Kick Member
    func kickMember(chatId: UUID, userId: UUID) async throws {
        let variables: [String: Any] = ["chatId": chatId.uuidString, "userId": userId.uuidString]
        let _: KickMemberResponse = try await graphQL.perform(
            query: GraphQLQueries.kickMember,
            variables: variables,
            responseType: KickMemberResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    func addChatMember(chatId: UUID, userId: UUID, role: String = "member") async throws {
        let variables: [String: Any] = [
            "chatId": chatId.uuidString,
            "userId": userId.uuidString,
            "role": role
        ]
        let _: AddChatMemberResponse = try await graphQL.perform(
            query: GraphQLQueries.addChatMember,
            variables: variables,
            responseType: AddChatMemberResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    // MARK: - Ban Member
    func banMember(chatId: UUID, userId: UUID, bannedUntil: Date? = nil) async throws {
        var variables: [String: Any] = ["chatId": chatId.uuidString, "userId": userId.uuidString]
        if let until = bannedUntil {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            variables["bannedUntil"] = formatter.string(from: until)
        }
        let _: BanMemberResponse = try await graphQL.perform(
            query: GraphQLQueries.banMember,
            variables: variables,
            responseType: BanMemberResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    // MARK: - Unban Member
    func unbanMember(chatId: UUID, userId: UUID) async throws {
        let variables: [String: Any] = ["chatId": chatId.uuidString, "userId": userId.uuidString]
        let _: UnbanMemberResponse = try await graphQL.perform(
            query: GraphQLQueries.unbanMember,
            variables: variables,
            responseType: UnbanMemberResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    // MARK: - Leave Chat
    func leaveChat(chatId: UUID) async throws {
        let variables = ["chatId": chatId.uuidString]
        let _: LeaveChatResponse = try await graphQL.perform(
            query: GraphQLQueries.leaveChat,
            variables: variables,
            responseType: LeaveChatResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    // MARK: - Join Chat by invite token
    func joinChat(inviteToken: String) async throws {
        let variables = ["inviteToken": inviteToken]
        let _: JoinChatResponse = try await graphQL.perform(
            query: GraphQLQueries.joinChatWithToken,
            variables: variables,
            responseType: JoinChatResponse.self,
            authToken: TokenManager.shared.accessToken
        )
    }
    
    // MARK: - Generate Invite Link
    func generateInviteLink(chatId: UUID) async throws -> String {
        let variables = ["chatId": chatId.uuidString]
        let response: InviteLinkResponse = try await graphQL.perform(
            query: GraphQLQueries.generateInviteLink,
            variables: variables,
            responseType: InviteLinkResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.chat.generateInviteLink
    }
}

// Остальные структуры ответов оставляем без изменений
