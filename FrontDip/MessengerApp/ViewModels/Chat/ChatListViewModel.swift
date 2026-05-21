import Foundation
import Combine

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    
    func loadChats() async {
        guard TokenManager.shared.accessToken != nil else { return }
        await MainActor.run { isLoading = true }
        
        do {
            let response: ListChatsResponse = try await graphQL.perform(
                query: GraphQLQueries.listChats,
                variables: [:],
                responseType: ListChatsResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await MainActor.run {
                self.chats = response.chat.list
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func createChat(name: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let currentUserId = AppState.shared.currentUser?.userId.uuidString else {
            await MainActor.run { errorMessage = "Пользователь не авторизован" }
            return false
        }
        
        let variables: [String: Any] = [
            "chatType": "group",
            "name": trimmedName,
            "memberIds": [currentUserId],
            "isPublic": false
        ]
        
        do {
            let response: CreateChatResponse = try await graphQL.perform(
                query: GraphQLQueries.createChat,
                variables: variables,
                responseType: CreateChatResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let created = response.chat.create
            let newChat = Chat(
                chatId: created.chatId,
                chatType: created.chatType,
                name: created.name,
                description: nil,
                avatarUrl: nil,
                creatorId: UUID(uuidString: currentUserId),
                isPublic: false,
                maxMembers: 200,
                createdAt: created.createdAt,
                membersCount: created.membersCount,
                lastMessage: nil
            )
            await MainActor.run {
                self.chats.insert(newChat, at: 0)
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
            }
            return false
        }
    }
}
