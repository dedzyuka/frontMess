import Foundation
import Combine

class ChatSidebarViewModel: ObservableObject {
    @Published var members: [ChatMemberDetailed] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    let chat: Chat
    
    init(chat: Chat) {
        self.chat = chat
    }
    
    func loadMembers() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let variables: [String: Any] = ["chatId": chat.id.uuidString]
                let response: ChatMembersListResponse = try await graphQL.perform(
                    query: GraphQLQueries.listChatMembers,
                    variables: variables,
                    responseType: ChatMembersListResponse.self
                )
                
                let loadedMembers = response.listChatMembers.members.map { member in
                    ChatMemberDetailed(
                        user_id: member.userId,
                        nickname: member.nickname,
                        public_key: member.publicKey,
                        joined_at: member.joinedAt,
                        device_id: member.deviceId
                    )
                }
                
                await MainActor.run {
                    self.members = loadedMembers
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка загрузки участников: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
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
                responseType: AddChatMemberResponse.self
            )
            await loadMembers()
            return true
        } catch {
            print("❌ Ошибка добавления пользователя: \(error)")
            return false
        }
    }
    
    func isUserInChat(_ userId: UUID) -> Bool {
        return members.contains { $0.user_id == userId }
    }
}
