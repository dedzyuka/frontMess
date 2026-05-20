import Foundation
import Combine

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateChat = false
    
    private let graphQL = GraphQLClient.shared
    private let database = LocalDatabase.shared
    
    var currentUser: User? { AppState.shared.currentUser }
    
    func loadChats() async {
        guard let userId = currentUser?.id else {
            await MainActor.run { isLoading = false }
            return
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            let variables: [String: Any] = ["userId": userId.uuidString]
            let response: ListChatsResponse = try await graphQL.perform(
                query: GraphQLQueries.listChats,
                variables: variables,
                responseType: ListChatsResponse.self
            )
            
            let loadedChats = response.listChats.chats.map { chatResponse in
                Chat(
                    id: chatResponse.chatId,
                    chatType: "group",
                    name: chatResponse.name ?? "Chat",
                    description: nil,
                    avatarUrl: nil,
                    creatorId: nil,
                    isPublic: false,
                    membersCount: chatResponse.membersCount,
                    createdAt: chatResponse.createdAt,
                    updatedAt: chatResponse.createdAt,
                    lastMessagePreview: nil
                )
            }
            
            for chat in loadedChats {
                _ = database.saveOrUpdateChat(chat)
            }
            
            await MainActor.run {
                self.chats = loadedChats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
