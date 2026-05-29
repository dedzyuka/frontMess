import Foundation
import Combine

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
        @Published var isLoading = false
        @Published var errorMessage: String?
        
        private let graphQL = GraphQLClient.shared
        private var cancellables = Set<AnyCancellable>()   // ← добавить
        
        init() {
            setupNotifications()   // ← добавить
        }
    
    private func setupNotifications() {
            NotificationCenter.default.publisher(for: .newMessageReceived)
                .sink { [weak self] notification in
                    guard let message = notification.object as? Message else { return }
                    // Обновляем lastMessage в соответствующем чате
                    if let index = self?.chats.firstIndex(where: { $0.id == message.chatId }) {
                        var chat = self?.chats[index]
                        chat?.lastMessage = message.content
                        if let updatedChat = chat {
                            self?.chats[index] = updatedChat
                        }
                    }
                }
                .store(in: &cancellables)
        }
    
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

    func findOrCreatePrivateChat(with userId: UUID) async -> Chat? {
        // Сначала ищем существующий
        if let existing = await findExistingPrivateChat(with: userId) {
            return existing
        }
        // Создаём новый
        return await createPrivateChat(with: userId)
    }

    private func findExistingPrivateChat(with userId: UUID) async -> Chat? {
        guard let currentUserId = AppState.shared.currentUser?.userId else { return nil }
        do {
            let response: ListChatsResponse = try await graphQL.perform(
                query: GraphQLQueries.listChats,
                variables: [:],
                responseType: ListChatsResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let chats = response.chat.list
            for chat in chats where chat.chatType == "1" || chat.chatType.lowercased() == "private" {
                let members = await getChatMembers(chatId: chat.id)
                if members.contains(currentUserId) && members.contains(userId) {
                    return chat
                }
            }
            return nil
        } catch {
            print("Error finding private chat: \(error)")
            return nil
        }
    }
    func addChat(_ chat: Chat) {
        DispatchQueue.main.async {
            if !self.chats.contains(where: { $0.id == chat.id }) {
                self.chats.insert(chat, at: 0)
            }
        }
    }

    private func getChatMembers(chatId: UUID) async -> [UUID] {
        do {
            let variables = ["chatId": chatId.uuidString]
            let response: ChatMembersIdResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMembers,
                variables: variables,
                responseType: ChatMembersIdResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.chat.members.compactMap { UUID(uuidString: $0) }
        } catch {
            return []
        }
    }

    private func createPrivateChat(with userId: UUID) async -> Chat? {
        guard let currentUserId = AppState.shared.currentUser?.userId else { return nil }
        let variables: [String: Any] = [
            "chatType": "PRIVATE",
            "memberIds": [currentUserId.uuidString, userId.uuidString],
            "isPublic": false
        ]
        do {
            let response: CreateChatResponse = try await graphQL.perform(
                query: GraphQLQueries.createChat,
                variables: variables,
                responseType: CreateChatResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let newChatData = response.chat.create
            let chat = Chat(
                chatId: newChatData.chatId,
                chatType: newChatData.chatType,
                name: newChatData.name,
                description: nil,
                avatarUrl: nil,
                creatorId: currentUserId,
                isPublic: false,
                maxMembers: newChatData.membersCount,
                createdAt: newChatData.createdAt,
                membersCount: newChatData.membersCount,
                lastMessage: nil
            )
            NotificationCenter.default.post(name: .chatCreated, object: chat)
            return chat
        } catch {
            print("Error creating private chat: \(error)")
            return nil
        }
    }

    
    
}
