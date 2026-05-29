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
        print("ChatViewModel initialized for chat: \(chat.id)")
        setupNotifications()
        loadMessages()
        Task { await loadChatTitle() }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                print("📢 ChatViewModel received .newMessageReceived")
                guard let self = self,
                      let message = notification.object as? Message,
                      message.chatId == self.chat.id else {
                    print("❌ .newMessageReceived condition failed")
                    return
                }
                self.addMessage(message)
                self.sendDeliveredIfNeeded(for: message)
            }
            .store(in: &cancellables)
        
        // Обновление сообщения
        NotificationCenter.default.publisher(for: .messageUpdated)
            .sink { [weak self] notification in
                print("📢 ChatViewModel received .messageUpdated notification")
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64,
                      let chatId = info["chatId"] as? UUID,
                      chatId == self.chat.id else {
                    print("❌ .messageUpdated condition failed – wrong chat or missing data")
                    return
                }
                let content = info["content"] as? String ?? ""
                let isEdited = info["isEdited"] as? Bool ?? false
                print("✅ .messageUpdated valid – messageId=\(messageId), new content='\(content)'")
                self.updateMessageLocally(messageId: messageId, newContent: content, isEdited: isEdited)
            }
            .store(in: &cancellables)
        
        // Удаление сообщения
        NotificationCenter.default.publisher(for: .messageDeleted)
            .sink { [weak self] notification in
                guard let self = self,
                      let (messageId, chatId) = notification.object as? (Int64, UUID),
                      chatId == self.chat.id else { return }
                print("✅ ChatViewModel: message deleted, id=\(messageId)")
                self.deleteMessageLocally(messageId: messageId)
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
                print("📢 ChatViewModel received .statusUpdated notification")
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64,
                      let chatId = info["chatId"] as? UUID,
                      chatId == self.chat.id else {
                    print("❌ .statusUpdated ignored – wrong chat or missing data")
                    return
                }
                let deliveredAt = info["deliveredAt"] as? Date
                let readAt = info["readAt"] as? Date
                print("✅ Updating status for message \(messageId): delivered=\(deliveredAt != nil), read=\(readAt != nil)")
                self.updateStatus(messageId: messageId, deliveredAt: deliveredAt, readAt: readAt)
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
                
                // Загружаем локальные сообщения (с уже сохранёнными статусами)
                let localMessages = database.getMessages(for: chat.id)
                
                // Сливаем: статусы из локальной БД
                var mergedMessages = loadedMessages
                for i in 0..<mergedMessages.count {
                    if let local = localMessages.first(where: { $0.messageId == mergedMessages[i].messageId }) {
                        mergedMessages[i].deliveredAt = local.deliveredAt
                        mergedMessages[i].readAt = local.readAt
                    } else {
                        // Если локального сообщения нет, сохраняем текущее (без статусов)
                        _ = database.saveMessage(mergedMessages[i])
                    }
                }
                
                // Также добавляем сообщения, которые есть в локальной БД, но ещё не пришли с сервера
                for local in localMessages {
                    if !mergedMessages.contains(where: { $0.messageId == local.messageId }) {
                        mergedMessages.append(local)
                    }
                }
                mergedMessages.sort(by: { $0.createdAt < $1.createdAt })
                
                await MainActor.run {
                    self.messages = mergedMessages
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

        // Временное сообщение (оптимистичное обновление)
        let tempId = Int64(Date().timeIntervalSince1970 * -1000)
        let tempMessage = Message(
            messageId: tempId, chatId: chat.id, senderId: currentUserId,
            replyToId: nil, content: content, type: "text",
            createdAt: Date(), updatedAt: Date(), deletedAt: nil,
            isEdited: false, deliveredAt: nil, readAt: nil
        )

        DispatchQueue.main.async {
            self.messages.append(tempMessage)
            self.newMessageText = ""
            self.objectWillChange.send()
            print("📤 sendMessage: temporary message \(tempId) added to UI")
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
                    if let index = self.messages.firstIndex(where: { $0.messageId == tempId }) {
                        self.messages[index] = newMsg
                    } else {
                        self.messages.append(newMsg)
                    }
                    self.messages.sort(by: { $0.createdAt < $1.createdAt })
                    self.objectWillChange.send()
                    print("✅ sendMessage: real message \(newMsg.messageId) replaced temp")
                }
            } catch {
                await MainActor.run {
                    self.messages.removeAll(where: { $0.messageId == tempId })
                    NotificationService.shared.showError("Не удалось отправить сообщение")
                    self.objectWillChange.send()
                    print("❌ sendMessage: failed, removed temp message")
                }
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
                if let deliveredAt = deliveredAt { msg.deliveredAt = deliveredAt }
                if let readAt = readAt { msg.readAt = readAt }
                self.messages[index] = msg
                _ = LocalDatabase.shared.updateMessageStatus(messageId: messageId, deliveredAt: deliveredAt, readAt: readAt)
                self.objectWillChange.send()
                print("🔄 Status updated for message \(messageId): delivered=\(deliveredAt != nil), read=\(readAt != nil)")
            } else {
                _ = LocalDatabase.shared.updateMessageStatus(messageId: messageId, deliveredAt: deliveredAt, readAt: readAt)
            }
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
        // Оптимистичное обновление
        await MainActor.run {
            if let index = self.messages.firstIndex(where: { $0.messageId == message.messageId }) {
                var updated = self.messages[index]
                updated.content = newContent
                updated.isEdited = true
                updated.updatedAt = Date()
                self.messages[index] = updated
                self.objectWillChange.send()
                print("✏️ editMessage: optimistic update for message \(message.messageId)")
            }
        }

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
            let updatedMsg = response.message.updateMessage
            await MainActor.run {
                if let index = self.messages.firstIndex(where: { $0.messageId == updatedMsg.messageId }) {
                    self.messages[index] = updatedMsg
                    self.objectWillChange.send()
                    print("✅ editMessage: server confirmed update for \(updatedMsg.messageId)")
                }
            }
            return true
        } catch {
            await MainActor.run {
                // Откат – перезагружаем список сообщений из сети
                self.loadMessages()
                self.objectWillChange.send()
            }
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
    
   
    private func addMessage(_ message: Message) {
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.messageId == message.messageId }) {
                var newMessages = self.messages
                newMessages.append(message)
                newMessages.sort(by: { $0.createdAt < $1.createdAt })
                self.messages = newMessages
                self.objectWillChange.send()   // ← добавить
                print("➕ WebSocket: message \(message.messageId) added, total: \(self.messages.count)")
            } else {
                print("⚠️ WebSocket: message \(message.messageId) already exists")
            }
        }
    }


    private func updateMessageLocally(messageId: Int64, newContent: String, isEdited: Bool) {
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                var updated = self.messages[index]
                updated.content = newContent
                updated.isEdited = isEdited
                updated.updatedAt = Date()
                self.messages[index] = updated
                // Принудительно уведомляем SwiftUI об изменении
                self.objectWillChange.send()
                print("🔄 Message \(messageId) updated in UI, new content: \(newContent)")
            } else {
                print("⚠️ Message \(messageId) not found in local messages array")
            }
        }
    }

    private func deleteMessageLocally(messageId: Int64) {
        DispatchQueue.main.async {
            self.messages.removeAll(where: { $0.messageId == messageId })
            self.objectWillChange.send()
            print("🗑️ WebSocket deleteMessageLocally: message \(messageId) removed from UI")
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
