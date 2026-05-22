import Foundation
import Combine

class ChatSidebarViewModel: ObservableObject {
    @Published var members: [ChatMemberItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    let chat: Chat
    
    init(chat: Chat) {
        self.chat = chat
    }
    
    func loadMembers() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                // 1. Получить список ID участников
                let variables: [String: Any] = ["chatId": chat.id.uuidString]
                let response: ChatMembersIdResponse = try await graphQL.perform(
                    query: GraphQLQueries.getChatMembers,
                    variables: variables,
                    responseType: ChatMembersIdResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let memberIds = response.chat.members.compactMap { UUID(uuidString: $0) }
                
                // 2. Для каждого ID получить пользователя (используем существующий UserService или ContactService)
                var items: [ChatMemberItem] = []
                for userId in memberIds {
                    if let user = try? await fetchUser(by: userId) {
                        items.append(ChatMemberItem(
                            userId: userId,
                            nickname: user.nickName,
                            joinedAt: Date() // бэк не отдаёт joinedAt, ставим текущую дату
                        ))
                    }
                }
                
                await MainActor.run {
                    self.members = items
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    private func fetchUser(by userId: UUID) async throws -> User {
        let query = """
        query GetUser($userId: String!) {
            user {
                get(id: $userId) {
                    userId
                    nickName
                    avatarUrl
                    isOnline
                }
            }
        }
        """
        struct Wrapper: Decodable { let user: UserGetWrapper }
        struct UserGetWrapper: Decodable { let get: User }
        let variables = ["userId": userId.uuidString]
        let response: Wrapper = try await graphQL.perform(
            query: query,
            variables: variables,
            responseType: Wrapper.self,
            authToken: TokenManager.shared.accessToken
        )
        return response.user.get
    }
    
    func addUserToChat(_ userId: UUID) async -> Bool {
        let variables: [String: Any] = [
            "chatId": chat.id.uuidString,
            "userId": userId.uuidString
        ]
        do {
            let _: AddChatMemberResponse = try await graphQL.perform(
                query: GraphQLQueries.addChatMember,
                variables: variables,
                responseType: AddChatMemberResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await loadMembers()
            return true
        } catch {
            return false
        }
    }
    
    func isUserInChat(_ userId: UUID) -> Bool {
        return members.contains(where: { $0.userId == userId })
    }
}
