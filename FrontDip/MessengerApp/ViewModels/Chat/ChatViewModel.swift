import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var usersCache: [UUID: User] = [:]
    @Published var chatTitle: String = ""
    @Published var reactionsDict: [Int64: [Reaction]] = [:]
    @Published var otherUser: User?
    @Published var isOtherUserOnline: Bool = false
    
    
    let chat: Chat
    private let graphQL = GraphQLClient.shared
    private let database = LocalDatabase.shared
    private var cancellables = Set<AnyCancellable>()
    private var visibleMessageIds = Set<Int64>()
    private var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "last_sync_\(chat.id.uuidString)") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "last_sync_\(chat.id.uuidString)") }
    }
    private var currentUserId: UUID? { AppState.shared.currentUser?.userId }
    private var chatMemberIds: [UUID] = []  // ID участников чата
    
    init(chat: Chat) {
        self.chat = chat
        print("ChatViewModel initialized for chat: \(chat.id)")
        setupNotifications()
        loadMessages()
        Task { await loadChatTitle() }
        Task { await loadOtherUserIfNeeded() }
        loadChatMemberIds()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let message = notification.object as? Message,
                      message.chatId == self.chat.id else { return }
                self.addMessage(message)
                self.sendDeliveredIfNeeded(for: message)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .messageUpdated)
            .sink { [weak self] notification in
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64,
                      let chatId = info["chatId"] as? UUID,
                      chatId == self.chat.id else { return }
                let content = info["content"] as? String ?? ""
                let isEdited = info["isEdited"] as? Bool ?? false
                self.updateMessageLocally(messageId: messageId, newContent: content, isEdited: isEdited)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .messageDeleted)
            .sink { [weak self] notification in
                guard let self = self,
                      let (messageId, chatId) = notification.object as? (Int64, UUID),
                      chatId == self.chat.id else { return }
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
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64,
                      let chatId = info["chatId"] as? UUID,
                      let userId = info["userId"] as? UUID,
                      chatId == self.chat.id else { return }
                let deliveredAt = info["deliveredAt"] as? Date
                let readAt = info["readAt"] as? Date
                self.updateStatusLocally(messageId: messageId, deliveredAt: deliveredAt, readAt: readAt, userId: userId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .statusUpdated)
            .sink { [weak self] notification in
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let userId = info["userId"] as? UUID,
                      let isOnline = info["is_online"] as? Bool,
                      userId == self.otherUser?.userId else { return }
                DispatchQueue.main.async {
                    self.isOtherUserOnline = isOnline
                    self.otherUser?.isOnline = isOnline
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Загрузка сообщений (кэш + сеть)
    func loadMessages() {
        Task {
            // 1. Загружаем кэш из БД
            let cached = await loadMessagesFromDatabase()
            await MainActor.run {
                self.messages = cached
                self.objectWillChange.send()
                self.markVisibleMessagesAsRead()
            }
            
            // 2. Загружаем свежие с сервера
            do {
                let newMessages = try await fetchMessagesFromServer()
                if !newMessages.isEmpty {
                    let merged = mergeMessages(current: cached, new: newMessages)
                    await MainActor.run {
                        self.messages = merged
                        self.saveMessagesToDatabase(merged)
                        self.objectWillChange.send()
                        self.markVisibleMessagesAsRead()
                        self.updateSentMessagesStatuses()  // обновим статусы отправленных сообщений
                    }
                    lastSyncDate = Date()
                }
            } catch {
                print("Network load error: \(error)")
            }
        }
    }
    
    private func loadMessagesFromDatabase() async -> [Message] {
        let dbMessages = database.getMessages(for: chat.id)
        var result: [Message] = []
        var reactions: [Int64: [Reaction]] = [:]
        for var msg in dbMessages {
            let attachments = database.getAttachments(for: msg.messageId)
            msg.attachments = attachments
            let msgReactions = database.getReactions(for: msg.messageId)
            msg.reactions = msgReactions
            if !msgReactions.isEmpty {
                reactions[msg.messageId] = msgReactions
            }
            // Статусы: для чужих сообщений – мой статус
            if let currentId = currentUserId, msg.senderId != currentId {
                if let (deliveredAt, readAt) = database.getMessageStatus(for: msg.messageId, userId: currentId) {
                    msg.deliveredAt = deliveredAt
                    msg.readAt = readAt
                }
            }
            // для своих сообщений readAt пока не трогаем – обновим после загрузки участников
            result.append(msg)
        }
        await MainActor.run {
            self.reactionsDict = reactions
        }
        return result
    }
    
    private func fetchMessagesFromServer() async throws -> [Message] {
        let variables: [String: Any] = ["chatId": chat.id.uuidString]
        let response: ListMessagesResponse = try await graphQL.perform(
            query: GraphQLQueries.listMessages,
            variables: variables,
            responseType: ListMessagesResponse.self,
            authToken: TokenManager.shared.accessToken
        )
        let messages = response.message.listMessages
        for msg in messages {
            if let attachments = msg.attachments, !attachments.isEmpty {
                _ = database.saveAttachments(attachments, for: msg.messageId)
            }
            if let reactions = msg.reactions {
                for reaction in reactions {
                    _ = database.saveReaction(reaction)
                }
            }
        }
        return messages
    }
    
    private func mergeMessages(current: [Message], new: [Message]) -> [Message] {
        var dict = Dictionary(uniqueKeysWithValues: current.map { ($0.messageId, $0) })
        for msg in new {
            dict[msg.messageId] = msg
        }
        return Array(dict.values).sorted { $0.createdAt < $1.createdAt }
    }
    
    private func saveMessagesToDatabase(_ messages: [Message]) {
        for msg in messages {
            _ = database.saveMessage(msg)
            if let attachments = msg.attachments, !attachments.isEmpty {
                _ = database.saveAttachments(attachments, for: msg.messageId)
            }
            if let reactions = msg.reactions {
                for reaction in reactions {
                    _ = database.saveReaction(reaction)
                }
            }
        }
    }
    
    // MARK: - Участники чата и статусы отправленных сообщений
    private func loadChatMemberIds() {
        Task {
            let ids = await getChatMemberIds()
            await MainActor.run {
                self.chatMemberIds = ids
                self.updateSentMessagesStatuses()
            }
        }
    }
    
    private func updateSentMessagesStatuses() {
        guard let currentId = currentUserId, !chatMemberIds.isEmpty else { return }
        let otherIds = chatMemberIds.filter { $0 != currentId }
        guard let otherId = otherIds.first else { return }
        
        for (index, var msg) in messages.enumerated() where msg.senderId == currentId && msg.readAt == nil {
            if let (_, readAt) = database.getMessageStatus(for: msg.messageId, userId: otherId), readAt != nil {
                msg.readAt = readAt
                messages[index] = msg
                print("✅ Updated sent message status for msg \(msg.messageId): readAt=\(readAt!)")
            }
        }
        objectWillChange.send()
    }
    
    private func getChatMemberIds() async -> [UUID] {
        let variables = ["chatId": chat.id.uuidString]
        do {
            let response: ChatMemberIdsResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMemberIds,
                variables: variables,
                responseType: ChatMemberIdsResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.chat.members.map { $0.userId }
        } catch {
            print("Failed to load chat member ids: \(error)")
            return []
        }
    }
    
    // MARK: - Read status delivery
    func markVisibleMessagesAsRead() {
        guard let currentId = currentUserId else { return }
        for message in messages where message.senderId != currentId && message.readAt == nil {
            if !visibleMessageIds.contains(message.messageId) {
                visibleMessageIds.insert(message.messageId)
                Task { await markAsReadOnServer(messageId: message.messageId) }
            }
        }
    }
    
    func markMessageAsReadIfNeeded(messageId: Int64) {
        guard let currentId = currentUserId,
              let msg = messages.first(where: { $0.messageId == messageId }),
              msg.senderId != currentId && msg.readAt == nil else { return }
        if !visibleMessageIds.contains(messageId) {
            visibleMessageIds.insert(messageId)
            Task { await markAsReadOnServer(messageId: messageId) }
        }
    }
    
    private func markAsReadOnServer(messageId: Int64) async {
        do {
            let _: EmptyResponse = try await graphQL.perform(
                query: GraphQLQueries.markAsRead,
                variables: ["messageId": messageId, "chatId": chat.id.uuidString],
                responseType: EmptyResponse.self,
                authToken: TokenManager.shared.accessToken
            )
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }
    
    // MARK: - Status update from WebSocket
    func updateStatusLocally(messageId: Int64, deliveredAt: Date?, readAt: Date?, userId: UUID) {
        print("💾 Saving status for msg \(messageId): delivered=\(deliveredAt != nil), read=\(readAt != nil), userId=\(userId)")
        _ = database.saveMessageStatus(messageId: messageId, userId: userId, deliveredAt: deliveredAt, readAt: readAt)
        
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                var msg = self.messages[index]
                if userId == self.currentUserId {
                    // Чужое сообщение: статус текущего пользователя
                    if let deliveredAt = deliveredAt { msg.deliveredAt = deliveredAt }
                    if let readAt = readAt { msg.readAt = readAt }
                } else {
                    // Моё сообщение: статус получателя – показываем две галочки
                    if let readAt = readAt, readAt != nil {
                        msg.readAt = readAt
                    }
                }
                self.messages[index] = msg
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Reactions
    func addReaction(to messageId: Int64, emoji: String) async {
        let currentUserId = AppState.shared.currentUser?.userId ?? UUID()
        let reaction = Reaction(messageId: messageId, userId: currentUserId, emoji: emoji, createdAt: Date())
        
        await MainActor.run {
            _ = database.saveReaction(reaction)
            if var list = reactionsDict[messageId] {
                if !list.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
                    list.append(reaction)
                    reactionsDict[messageId] = list
                }
            } else {
                reactionsDict[messageId] = [reaction]
            }
            if let index = messages.firstIndex(where: { $0.messageId == messageId }) {
                var updatedMsg = messages[index]
                var newReactions = updatedMsg.reactions ?? []
                if !newReactions.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
                    newReactions.append(reaction)
                    updatedMsg.reactions = newReactions
                    messages[index] = updatedMsg
                }
            }
            objectWillChange.send()
        }
        
        do {
            let variables: [String: Any] = ["messageId": messageId, "chatId": chat.id.uuidString, "emoji": emoji]
            let _: AddReactionResponse = try await graphQL.perform(
                query: GraphQLQueries.addReaction,
                variables: variables,
                responseType: AddReactionResponse.self,
                authToken: TokenManager.shared.accessToken
            )
        } catch {
            await MainActor.run {
                _ = database.deleteReaction(messageId: messageId, userId: currentUserId, emoji: emoji)
                if var list = reactionsDict[messageId] {
                    list.removeAll(where: { $0.userId == currentUserId && $0.emoji == emoji })
                    reactionsDict[messageId] = list
                }
                if let index = messages.firstIndex(where: { $0.messageId == messageId }) {
                    var msg = messages[index]
                    msg.reactions?.removeAll(where: { $0.userId == currentUserId && $0.emoji == emoji })
                    messages[index] = msg
                }
                objectWillChange.send()
            }
            print("Add reaction failed: \(error)")
        }
    }
    
    func removeReaction(from messageId: Int64, emoji: String) async {
        let currentUserId = AppState.shared.currentUser?.userId ?? UUID()
        await MainActor.run {
            _ = database.deleteReaction(messageId: messageId, userId: currentUserId, emoji: emoji)
            if var list = reactionsDict[messageId] {
                list.removeAll(where: { $0.userId == currentUserId && $0.emoji == emoji })
                reactionsDict[messageId] = list
            }
            if let index = messages.firstIndex(where: { $0.messageId == messageId }) {
                var msg = messages[index]
                msg.reactions?.removeAll(where: { $0.userId == currentUserId && $0.emoji == emoji })
                messages[index] = msg
            }
            objectWillChange.send()
        }
        do {
            let variables: [String: Any] = ["messageId": messageId, "chatId": chat.id.uuidString, "emoji": emoji]
            let _: RemoveReactionResponse = try await graphQL.perform(
                query: GraphQLQueries.removeReaction,
                variables: variables,
                responseType: RemoveReactionResponse.self,
                authToken: TokenManager.shared.accessToken
            )
        } catch {
            let reaction = Reaction(messageId: messageId, userId: currentUserId, emoji: emoji, createdAt: Date())
            await MainActor.run {
                _ = database.saveReaction(reaction)
                if var list = reactionsDict[messageId] {
                    if !list.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
                        list.append(reaction)
                        reactionsDict[messageId] = list
                    }
                }
                if let index = messages.firstIndex(where: { $0.messageId == messageId }) {
                    var msg = messages[index]
                    var newReactions = msg.reactions ?? []
                    if !newReactions.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
                        newReactions.append(reaction)
                        msg.reactions = newReactions
                        messages[index] = msg
                    }
                }
                objectWillChange.send()
            }
            print("Remove reaction failed: \(error)")
        }
    }
    
    private func addReactionLocally(_ reaction: Reaction) {
        DispatchQueue.main.async {
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
    
    private func removeReactionLocally(messageId: Int64, userId: UUID, emoji: String) {
        DispatchQueue.main.async {
            _ = self.database.deleteReaction(messageId: messageId, userId: userId, emoji: emoji)
            if var list = self.reactionsDict[messageId] {
                list.removeAll(where: { $0.userId == userId && $0.emoji == emoji })
                self.reactionsDict[messageId] = list
            }
        }
    }
    
    // MARK: - Helper for reactions display
    func reactionsForMessage(_ messageId: Int64) -> [Reaction] {
        return reactionsDict[messageId] ?? []
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.userId
    }
    
    func getUser(for senderId: UUID) -> User? {
        return usersCache[senderId]
    }
    
    // MARK: - Send message
    func sendMessage(attachmentId: UUID? = nil, storagePath: String? = nil, fileName: String? = nil, fileSize: Int? = nil, mimeType: String? = nil) async -> Bool {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || attachmentId != nil else { return false }
        guard let currentUserId = currentUserId else { return false }

        let tempId = Int64(Date().timeIntervalSince1970 * -1000)
        let tempMessage = Message(
            messageId: tempId, chatId: chat.id, senderId: currentUserId,
            replyToId: nil, content: content, type: "text",
            createdAt: Date(), updatedAt: Date(), deletedAt: nil,
            isEdited: false, deliveredAt: nil, readAt: nil
        )

        // Временное вложение для локального отображения
        var localAttachment: Attachment? = nil
        if let aid = attachmentId, let fname = fileName, let storage = storagePath {
            localAttachment = Attachment(
                attachmentId: aid,
                fileName: fname,
                fileSize: fileSize,
                mimeType: mimeType,
                storagePath: storage,
                uploadedAt: Date()
            )
            var msgWithAtt = tempMessage
            msgWithAtt.attachments = [localAttachment!]
            await MainActor.run {
                self.messages.append(msgWithAtt)
                self.newMessageText = ""
                self.objectWillChange.send()
            }
        } else {
            await MainActor.run {
                self.messages.append(tempMessage)
                self.newMessageText = ""
                self.objectWillChange.send()
            }
        }

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
            let realMsg = response.message.sendMessage   // теперь содержит attachments

            await MainActor.run {
                if let index = self.messages.firstIndex(where: { $0.messageId == tempId }) {
                    self.messages[index] = realMsg
                    _ = self.database.saveMessage(realMsg)
                    if let attachments = realMsg.attachments, !attachments.isEmpty {
                        _ = self.database.saveAttachments(attachments, for: realMsg.messageId)
                    }
                    self.objectWillChange.send()
                }
            }

            // 🚫 Удаляем этот блок (дополнительный fetch через 1.5 секунды)
            // Task {
            //     try? await Task.sleep(nanoseconds: 1_500_000_000)
            //     if let fullMsg = await self.fetchMessage(byId: realMessageId) { ... }
            // }

            return true
        } catch {
            await MainActor.run {
                self.messages.removeAll(where: { $0.messageId == tempId })
                NotificationService.shared.showError("Не удалось отправить сообщение")
                self.objectWillChange.send()
            }
            return false
        }
    }

    // Вспомогательный метод (добавить в конец класса)
    private func fetchMessage(byId messageId: Int64) async -> Message? {
        let variables: [String: Any] = ["messageId": messageId, "chatId": chat.id.uuidString]
        do {
            let response: GetMessageResponse = try await graphQL.perform(
                query: GraphQLQueries.getMessage,
                variables: variables,
                responseType: GetMessageResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.message.getMessage
        } catch {
            print("Failed to fetch message: \(error)")
            return nil
        }
    }

    // Вспомогательный метод для получения полного сообщения
    
    
    // MARK: - Edit / Delete
    func editMessage(_ message: Message, newContent: String) async -> Bool {
        await MainActor.run {
            if let index = self.messages.firstIndex(where: { $0.messageId == message.messageId }) {
                var updated = self.messages[index]
                updated.content = newContent
                updated.isEdited = true
                updated.updatedAt = Date()
                self.messages[index] = updated
                self.objectWillChange.send()
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
                    _ = self.database.updateMessage(updatedMsg)
                    self.objectWillChange.send()
                }
            }
            return true
        } catch {
            await MainActor.run { self.loadMessages() }
            return false
        }
    }
    
    func deleteMessage(_ message: Message) async -> Bool {
        do {
            let variables: [String: Any] = ["messageId": message.messageId, "chatId": chat.id.uuidString]
            let _: DeleteMessageResponse = try await graphQL.perform(
                query: GraphQLQueries.deleteMessage,
                variables: variables,
                responseType: DeleteMessageResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            await MainActor.run {
                self.messages.removeAll { $0.messageId == message.messageId }
                _ = self.database.deleteAttachments(for: message.messageId)
            }
            return true
        } catch {
            print("Delete error: \(error)")
            return false
        }
    }
    
    // MARK: - Chat title / other user
    func loadOtherUserIfNeeded() async {
        guard chat.chatType == "PRIVATE" || chat.chatType.lowercased() == "private" else { return }
        guard let currentUserId = currentUserId else { return }
        let memberIds = await getChatMemberIds()
        let otherId = memberIds.first(where: { $0 != currentUserId })
        guard let otherId = otherId else { return }
        do {
            let user = try await UserService.shared.getUser(userId: otherId)
            await MainActor.run {
                self.otherUser = user
                self.isOtherUserOnline = user.isOnline ?? false
                if self.chatTitle.isEmpty || self.chatTitle == "Чат" {
                    self.chatTitle = user.nickName
                }
            }
        } catch {
            print("Failed to load other user: \(error)")
        }
    }
    
    @MainActor
    func loadChatTitle() async {
        if let name = chat.name, !name.isEmpty {
            chatTitle = name
            return
        }
        guard let currentUserId = currentUserId else {
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
    
    // MARK: - Local message updates
    private func updateMessageLocally(messageId: Int64, newContent: String, isEdited: Bool) {
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                var updated = self.messages[index]
                updated.content = newContent
                updated.isEdited = isEdited
                updated.updatedAt = Date()
                self.messages[index] = updated
                _ = self.database.updateMessage(updated)
                self.objectWillChange.send()
            }
        }
    }
    
    private func deleteMessageLocally(messageId: Int64) {
        DispatchQueue.main.async {
            self.messages.removeAll(where: { $0.messageId == messageId })
            _ = self.database.deleteAttachments(for: messageId)
            self.objectWillChange.send()
        }
    }
    
    private func addMessage(_ message: Message) {
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.messageId == message.messageId }) {
                var newMessages = self.messages
                newMessages.append(message)
                newMessages.sort(by: { $0.createdAt < $1.createdAt })
                self.messages = newMessages
                _ = self.database.saveMessage(message)
                if let attachments = message.attachments, !attachments.isEmpty {
                    _ = self.database.saveAttachments(attachments, for: message.messageId)
                }
                if let reactions = message.reactions {
                    for reaction in reactions {
                        _ = self.database.saveReaction(reaction)
                    }
                }
                self.objectWillChange.send()
            }
        }
    }
    
    private func sendDeliveredIfNeeded(for message: Message) {
        guard message.senderId != currentUserId else { return }
        WebSocketService.shared.sendAck(messageId: message.messageId, chatId: chat.id)
    }
}

private struct EmptyResponse: Decodable {}
