// ChatViewModel.swift
import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var usersCache: [UUID: User] = [:]
    @Published var chatTitle: String = ""
    @Published var reactionsDict: [Int64: [Reaction]] = [:] // messageId -> [Reaction]
    private let database = LocalDatabase.shared
    
    let chat: Chat
    private let graphQL = GraphQLClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var deliveredMessageIds = Set<Int64>()
    private var visibleMessageIds = Set<Int64>()
    
    init(chat: Chat) {
        self.chat = chat
        setupNotifications()
        loadMessages()
        Task { await loadChatTitle() }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let msg = notification.object as? Message, msg.chatId == self?.chat.id {
                    self?.addMessage(msg)
                    self?.sendDeliveredIfNeeded(for: msg)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .messageUpdated)
            .sink { [weak self] notification in
                if let info = notification.object as? [String: Any],
                   let messageId = info["messageId"] as? Int64,
                   let chatId = info["chatId"] as? UUID,
                   chatId == self?.chat.id {
                    let content = info["content"] as? String ?? ""
                    let isEdited = info["isEdited"] as? Bool ?? false
                    self?.updateMessage(messageId: messageId, content: content, isEdited: isEdited)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .messageDeleted)
            .sink { [weak self] notification in
                if let (messageId, chatId) = notification.object as? (Int64, UUID), chatId == self?.chat.id {
                    self?.deleteMessageLocally(messageId: messageId)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .reactionAdded)
            .sink { [weak self] notification in
                if let reaction = notification.object as? Reaction {
                    self?.addReactionLocally(reaction)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .reactionRemoved)
            .sink { [weak self] notification in
                if let info = notification.object as? [String: Any],
                   let messageId = info["messageId"] as? Int64,
                   let userId = info["userId"] as? String,
                   let emoji = info["emoji"] as? String {
                    self?.removeReactionLocally(messageId: messageId, userId: UUID(uuidString: userId)!, emoji: emoji)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .statusUpdated)
            .sink { [weak self] notification in
                if let info = notification.object as? [String: Any],
                   let messageId = info["messageId"] as? Int64,
                   let userId = info["userId"] as? String,
                   userId == AppState.shared.currentUser?.userId.uuidString {
                    self?.updateStatus(messageId: messageId, deliveredAt: info["deliveredAt"] as? Date, readAt: info["readAt"] as? Date)
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func loadChatTitle() async {
        if let name = chat.name, !name.isEmpty {
            chatTitle = name
            return
        }
        guard let currentUserId = AppState.shared.currentUser?.userId else {
            chatTitle = "Чат"
            return
        }
        let memberIds = await getChatMemberIds()
        let otherId = memberIds.first(where: { $0 != currentUserId })
        if let otherId = otherId, let user = try? await UserService.shared.getUser(userId: otherId) {
            chatTitle = user.nickName
        } else {
            chatTitle = "Чат"
        }
    }
    private func addReactionLocally(_ reaction: Reaction) {
        DispatchQueue.main.async {
            // Сохраняем в БД
            _ = self.database.saveReaction(reaction)

            if var list = self.reactionsDict[reaction.messageId] {
                if !list.contains(where: { $0.userId == reaction.userId && $0.emoji == reaction.emoji }) {
                    list.append(reaction)
                    self.reactionsDict[reaction.messageId] = list
                }
            } else {
                self.reactionsDict[reaction.messageId] = [reaction]
            }
        }
    }

    // При удалении реакции
    private func removeReactionLocally(messageId: Int64, userId: UUID, emoji: String) {
        DispatchQueue.main.async {
            // Удаляем из БД
            _ = self.database.removeReaction(messageId: messageId, userId: userId, emoji: emoji)

            if var list = self.reactionsDict[messageId] {
                list.removeAll(where: { $0.userId == userId && $0.emoji == emoji })
                self.reactionsDict[messageId] = list
            }
        }
    }

    
    private func getChatMemberIds() async -> [UUID] {
        let variables = ["chatId": chat.id.uuidString]
        do {
            let response: ChatMembersIdResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMembers,
                variables: variables,
                responseType: ChatMembersIdResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.chat.members.compactMap { UUID(uuidString: $0) }
        } catch {
            print("Failed to load chat members: \(error)")
            return []
        }
    }
    
    func loadMessages() {
        Task {
            await MainActor.run { isLoading = true }
            do {
                let variables: [String: Any] = ["chatId": chat.id.uuidString]
                let response: ListMessagesResponse = try await graphQL.perform(
                    query: GraphQLQueries.listMessages,
                    variables: variables,
                    responseType: ListMessagesResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let loadedMessages = response.message.listMessages.sorted(by: { $0.createdAt < $1.createdAt })
                await MainActor.run {
                    self.messages = loadedMessages
                    // Заполняем словарь реакций
                    for msg in loadedMessages {
                                            let savedReactions = self.database.getReactions(for: msg.messageId)
                                            if !savedReactions.isEmpty {
                                                self.reactionsDict[msg.messageId] = savedReactions
                                            }
                                        }
                    self.isLoading = false
                }
                await loadUsersForMessages(loadedMessages)
            } catch {
                print("Load messages error: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    func addReaction(to messageId: Int64, emoji: String) async {
        let currentUserId = AppState.shared.currentUser?.userId ?? UUID()
        let reaction = Reaction(messageId: messageId, userId: currentUserId, emoji: emoji, createdAt: Date())
        
        // Оптимистичное добавление
        await MainActor.run {
            self.addReactionLocally(reaction)
        }
        
        do {
            let variables: [String: Any] = [
                "messageId": messageId,
                "chatId": chat.id.uuidString,
                "emoji": emoji
            ]
            let _: AddReactionResponse = try await graphQL.perform(
                query: GraphQLQueries.addReaction,
                variables: variables,
                responseType: AddReactionResponse.self,
                authToken: TokenManager.shared.accessToken
            )
        } catch {
            // Откат
            await MainActor.run {
                self.removeReactionLocally(messageId: messageId, userId: currentUserId, emoji: emoji)
            }
            print("Add reaction failed: \(error)")
        }
    }

    func removeReaction(from messageId: Int64, emoji: String) async {
        let currentUserId = AppState.shared.currentUser?.userId ?? UUID()
        
        // Оптимистичное удаление
        await MainActor.run {
            self.removeReactionLocally(messageId: messageId, userId: currentUserId, emoji: emoji)
        }
        
        do {
            let variables: [String: Any] = [
                "messageId": messageId,
                "chatId": chat.id.uuidString,
                "emoji": emoji
            ]
            let _: RemoveReactionResponse = try await graphQL.perform(
                query: GraphQLQueries.removeReaction,
                variables: variables,
                responseType: RemoveReactionResponse.self,
                authToken: TokenManager.shared.accessToken
            )
        } catch {
            // Восстановить реакцию при ошибке
            let reaction = Reaction(messageId: messageId, userId: currentUserId, emoji: emoji, createdAt: Date())
            await MainActor.run {
                self.addReactionLocally(reaction)
            }
            print("Remove reaction failed: \(error)")
        }
    }
    
    private func loadReactionsForMessages(_ messages: [Message]) async {
        // Тут можно запросить реакции для каждого сообщения, но проще ожидать WebSocket
        // Пока просто инициализируем пустые словари
        await MainActor.run {
            for msg in messages {
                if reactionsDict[msg.messageId] == nil {
                    reactionsDict[msg.messageId] = []
                }
            }
        }
    }
    
    private func loadUsersForMessages(_ messages: [Message]) async {
        let uniqueSenderIds = Set(messages.map { $0.senderId })
        for userId in uniqueSenderIds {
            if usersCache[userId] == nil {
                do {
                    let user = try await UserService.shared.getUser(userId: userId)
                    await MainActor.run {
                        self.usersCache[userId] = user
                    }
                } catch {
                    print("Failed to load user \(userId): \(error)")
                }
            }
        }
    }
    
    func getUser(for senderId: UUID) -> User? {
        return usersCache[senderId]
    }
    
    func sendMessage(attachmentId: UUID? = nil) {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || attachmentId != nil else { return }
        guard let currentUserId = AppState.shared.currentUser?.userId else { return }
        
        // Временное локальное сообщение для оптимистичного UI
        let tempId = Int64(Date().timeIntervalSince1970 * -1000) // отрицательный временный ID
        let tempMessage = Message(
            messageId: tempId, chatId: chat.id, senderId: currentUserId,
            replyToId: nil, content: content, type: "text",
            createdAt: Date(), updatedAt: Date(), deletedAt: nil,
            isEdited: false, deliveredAt: nil, readAt: nil
        )
        DispatchQueue.main.async {
            self.messages.append(tempMessage)
            self.newMessageText = ""
        }
        
        Task {
            do {
                var variables: [String: Any] = ["chatId": chat.id.uuidString, "content": content]
                if let aid = attachmentId {
                    variables["attachmentId"] = aid.uuidString
                }
                let response: SendMessageResponse = try await graphQL.perform(
                    query: GraphQLQueries.sendMessage,
                    variables: variables,
                    responseType: SendMessageResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                let newMsg = response.message.sendMessage
                await MainActor.run {
                    // Заменить временное сообщение
                    if let index = self.messages.firstIndex(where: { $0.messageId == tempId }) {
                        self.messages[index] = newMsg
                    } else {
                        self.messages.append(newMsg)
                    }
                    self.messages.sort(by: { $0.createdAt < $1.createdAt })
                }
            } catch {
                // Если ошибка, удалить временное сообщение и показать ошибку
                await MainActor.run {
                    self.messages.removeAll(where: { $0.messageId == tempId })
                    NotificationService.shared.showError("Не удалось отправить сообщение")
                }
            }
        }
    }
    
    private func addMessage(_ message: Message) {
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.messageId == message.messageId }) {
                self.messages.append(message)
                self.messages.sort(by: { $0.createdAt < $1.createdAt })
            }
        }
    }
    
    private func updateMessage(messageId: Int64, content: String, isEdited: Bool) {
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                var updated = self.messages[index]
                updated.content = content
                updated.isEdited = isEdited
                updated.updatedAt = Date()
                self.messages[index] = updated
                self.objectWillChange.send()  // принудительное обновление SwiftUI
                _ = LocalDatabase.shared.updateMessage(updated)
            }
        }
    }

    private func updateStatus(messageId: Int64, deliveredAt: Date?, readAt: Date?) {
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                var msg = self.messages[index]
                if let deliveredAt = deliveredAt {
                    msg.deliveredAt = deliveredAt
                }
                if let readAt = readAt {
                    msg.readAt = readAt
                }
                self.messages[index] = msg
            }
        }
    }
    
    private func deleteMessageLocally(messageId: Int64) {
        DispatchQueue.main.async {
            self.messages.removeAll(where: { $0.messageId == messageId })
        }
    }
    
    
    
    
    
    private func sendDeliveredIfNeeded(for message: Message) {
        guard message.senderId != AppState.shared.currentUser?.userId else { return }
        if !deliveredMessageIds.contains(message.messageId) {
            deliveredMessageIds.insert(message.messageId)
            WebSocketService.shared.sendAck(messageId: message.messageId, chatId: chat.id)
        }
    }
    
    func markAsRead(messageId: Int64) {
        guard !visibleMessageIds.contains(messageId) else { return }
        visibleMessageIds.insert(messageId)
        Task {
            do {
                let _: EmptyResponse = try await graphQL.perform(
                    query: GraphQLQueries.markAsRead,
                    variables: ["messageId": messageId, "chatId": chat.id.uuidString],
                    responseType: EmptyResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
            } catch {
                if (error as? GraphQLError)?.localizedDescription.contains("Message status not found") == true {
                    print("Status not found for old message \(messageId)")
                } else {
                    print("Failed to mark as read: \(error)")
                }
            }
        }
    }
    
    func editMessage(_ message: Message, newContent: String) async -> Bool {
        do {
            let variables: [String: Any] = [
                "messageId": message.messageId,
                "chatId": chat.id.uuidString,
                "content": newContent
            ]
            let response: UpdateMessageResponse = try await graphQL.perform(
                query: GraphQLQueries.updateMessage,
                variables: variables,
                responseType: UpdateMessageResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let updated = response.message.updateMessage
            await MainActor.run {
                if let index = self.messages.firstIndex(where: { $0.messageId == updated.messageId }) {
                    self.messages[index] = updated
                }
            }
            return true
        } catch {
            print("Edit error: \(error)")
            return false
        }
    }
    
    func deleteMessage(_ message: Message) async -> Bool {
        do {
            let variables: [String: Any] = [
                "messageId": message.messageId,
                "chatId": chat.id.uuidString
            ]
            let _: DeleteMessageResponse = try await graphQL.perform(
                query: GraphQLQueries.deleteMessage,
                variables: variables,
                responseType: DeleteMessageResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await MainActor.run {
                self.messages.removeAll { $0.messageId == message.messageId }
            }
            return true
        } catch {
            print("Delete error: \(error)")
            return false
        }
    }
    
   
    
    
    
    func reactionsForMessage(_ messageId: Int64) -> [Reaction] {
        return reactionsDict[messageId] ?? []
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.userId
    }
}

// Пустой тип для ответа без данных
private struct EmptyResponse: Decodable {}
