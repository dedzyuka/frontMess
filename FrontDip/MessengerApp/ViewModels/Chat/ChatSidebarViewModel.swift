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
                let variables: [String: Any] = ["chatId": chat.chat_id.uuidString]
                let response: ChatMembersResponse = try await graphQL.perform(
                    query: GraphQLQueries.getChatMembers,
                    variables: variables,
                    responseType: ChatMembersResponse.self
                )
                await MainActor.run {
                    self.members = response.chat.members
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

    func addUserToChat(_ userId: UUID) async -> Bool {
        let variables: [String: Any] = [
            "chatId": chat.chat_id.uuidString,
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
            return false
        }
    }
    
    func isUserInChat(_ userId: UUID) -> Bool {
        return members.contains(where: { $0.user_id == userId })
    }
}
