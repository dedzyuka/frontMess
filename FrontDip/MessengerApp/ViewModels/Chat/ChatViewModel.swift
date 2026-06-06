//
//  ChatViewModel.swift
//  MessengerApp
//

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
    @Published var isSomeoneTyping: Bool = false
    @Published var myRole: String = "member"
    @Published var searchQuery = ""
    @Published var searchResults: [Message] = []
    @Published var isSearching = false
    @Published var highlightMessageId: Int64?
    @Published var scrollToMessageId: Int64?
    var pendingForward: PendingForward?
    
    // MARK: - Pending Forward Data
    struct PendingForward {
        let originalContent: String
        let forwardedFromUserId: UUID
        let forwardedFromNickname: String
        let attachmentId: UUID?
    }
    
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
    private var chatMemberIds: [UUID] = []
    var forwardMessageData: (original: Message, fromUserId: UUID, fromNickname: String)?
    
    init(chat: Chat) {
        self.chat = chat
        print("ChatViewModel initialized for chat: \(chat.id)")
        setupNotifications()
        loadMessages()
        Task{ await loadMyRole()}
        Task { await loadChatTitle() }
        Task { await loadOtherUserIfNeeded() }
        loadChatMemberIds()
    }
    func clearPendingForward() {
            pendingForward = nil
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
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] notification in
                        if let reaction = notification.object as? Reaction {
                            self?.addReactionLocally(reaction)
                        }
                    }
                    .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .reactionRemoved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64 else { return }
                
                if let userIdString = info["userId"] as? String,
                   let emoji = info["emoji"] as? String,
                   let userId = UUID(uuidString: userIdString) {
                    self.removeReactionLocally(messageId: messageId, userId: userId, emoji: emoji)
                }
                
                Task {
                    if let freshMessage = await self.fetchMessage(byId: messageId) {
                        await MainActor.run {
                            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                                self.messages[index] = freshMessage
                                self.reactionsDict[messageId] = freshMessage.reactions
                                _ = self.database.saveMessage(freshMessage)
                                if let reactions = freshMessage.reactions {
                                    for reaction in reactions {
                                        _ = self.database.saveReaction(reaction)
                                    }
                                }
                                self.objectWillChange.send()
                            }
                        }
                    }
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let userId = info["userId"] as? UUID,
                      let isOnline = info["is_online"] as? Bool,
                      userId == self.otherUser?.userId else { return }
                self.isOtherUserOnline = isOnline
                self.otherUser?.isOnline = isOnline
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .typingStarted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let chatId = notification.userInfo?["chatId"] as? UUID,
                      chatId == self.chat.id,
                      let userId = notification.userInfo?["userId"] as? UUID,
                      userId != self.currentUserId else { return }
                self.isSomeoneTyping = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if self?.isSomeoneTyping == true {
                        self?.isSomeoneTyping = false
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .typingStopped)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let chatId = notification.userInfo?["chatId"] as? UUID,
                      chatId == self.chat.id else { return }
                self.isSomeoneTyping = false
            }
            .store(in: &cancellables)
    }
    

    
    private func loadMyRole() async {
        guard let currentUserId = currentUserId else { return }
        let membersWithRoles = await getChatMemberIdsWithRoles()
        if let role = membersWithRoles.first(where: { $0.userId == currentUserId })?.role {
            await MainActor.run {
                self.myRole = role ?? "member"
            }
        }
    }
    
    func sendForwardMessage(_ original: Message, forwardedFromUserId: UUID, forwardedFromNickname: String) async -> Bool {
        var attachmentId: UUID? = nil
        if let attachments = original.attachments, let first = attachments.first {
            attachmentId = first.attachmentId
        }
        return await sendMessage(
            attachmentId: attachmentId,
            storagePath: nil,
            fileName: nil,
            fileSize: nil,
            mimeType: nil,
            replyToId: nil,
            forwardedFromUserId: forwardedFromUserId,
            forwardedFromNickname: forwardedFromNickname,
            customContent: original.content ?? ""
        )
    }
    
    private func getChatMemberIdsWithRoles() async -> [(userId: UUID, role: String?)] {
        let variables = ["chatId": chat.id.uuidString]
        do {
            let response: ChatMembersResponse = try await graphQL.perform(
                query: GraphQLQueries.getChatMembers,
                variables: variables,
                responseType: ChatMembersResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            return response.chat.members.map { ($0.userId, $0.role) }
        } catch {
            print("Failed to load chat member roles: \(error)")
            return []
        }
    }
    
    func getUserNickname(for userId: UUID) -> String {
        if userId == currentUserId {
            return AppState.shared.currentUser?.nickName ?? "Вы"
        }
        if let user = usersCache[userId] {
            return user.nickName
        }
        // Пробуем загрузить асинхронно (но для отображения нужно вернуть что-то сейчас)
        Task {
            if let user = try? await UserService.shared.getUser(userId: userId) {
                await MainActor.run {
                    self.usersCache[userId] = user
                    self.objectWillChange.send()
                }
            }
        }
        return "Пользователь"
    }
    func getNicknameForForward(for userId: UUID) -> String {
        if userId == AppState.shared.currentUser?.userId {
            return AppState.shared.currentUser?.nickName ?? "Вы"
        }
        return usersCache[userId]?.nickName ?? "Пользователь"
    }
    private func loadUserIfNeeded(_ userId: UUID) {
        guard usersCache[userId] == nil, userId != currentUserId else { return }
        Task {
            if let user = try? await UserService.shared.getUser(userId: userId) {
                await MainActor.run {
                    self.usersCache[userId] = user
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    private func removeDuplicateMessages(_ messages: [Message]) -> [Message] {
        var seen = Set<Int64>()
        return messages.filter { seen.insert($0.messageId).inserted }
    }
    
    // MARK: - Загрузка сообщений
    func loadMessages() {
        Task {
            let cached = await loadMessagesFromDatabase()
            let uniqueCached = removeDuplicateMessages(cached)
            await MainActor.run {
                self.messages = cached
                self.enrichMessagesWithReplies()
                self.objectWillChange.send()
                self.markVisibleMessagesAsRead()
            }

            do {
                let freshMessages = try await fetchMessagesFromServer()
                let sortedFresh = freshMessages.sorted { $0.createdAt < $1.createdAt }
                let uniqueFresh = removeDuplicateMessages(sortedFresh)
                await MainActor.run {
                    self.messages = sortedFresh
                    self.enrichMessagesWithReplies()
                    self.saveMessagesToDatabase(freshMessages)
                    self.objectWillChange.send()
                    self.markVisibleMessagesAsRead()
                    self.updateSentMessagesStatuses()
                }
                self.lastSyncDate = Date()
            } catch {
                print("Network load error: \(error)")
            }
        }
    }
    func highlightMessage(_ id: Int64, duration: TimeInterval = 1.0) {
        highlightMessageId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if self?.highlightMessageId == id {
                self?.highlightMessageId = nil
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
            if let currentId = currentUserId, msg.senderId != currentId {
                if let (deliveredAt, readAt) = database.getMessageStatus(for: msg.messageId, userId: currentId) {
                    msg.deliveredAt = deliveredAt
                    msg.readAt = readAt
                }
            }
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
            _ = database.saveMessage(msg)
            if let attachments = msg.attachments, !attachments.isEmpty {
                _ = database.saveAttachments(attachments, for: msg.messageId, messageCreatedAt: msg.createdAt)
            }
            if let reactions = msg.reactions {
                for reaction in reactions { _ = database.saveReaction(reaction) }
            }
        }
        return messages
    }
    func searchMessages() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                self.searchResults = []
            }
            return
        }
        isSearching = true
        Task {
            do {
                let variables: [String: Any] = [
                    "chatId": chat.id.uuidString,
                    "query": trimmed,
                    "page": 1,
                    "pageSize": 50
                ]
                let response: SearchMessagesResponse = try await graphQL.perform(
                    query: GraphQLQueries.searchMessages,
                    variables: variables,
                    responseType: SearchMessagesResponse.self,
                    authToken: TokenManager.shared.accessToken
                )
                await MainActor.run {
                    self.searchResults = response.message.searchMessages
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    print("Search error: \(error)")
                }
            }
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
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
                _ = database.saveAttachments(attachments, for: msg.messageId, messageCreatedAt: msg.createdAt)
            }
            if let reactions = msg.reactions {
                for reaction in reactions { _ = database.saveReaction(reaction) }
            }
        }
    }
    
    // MARK: - Участники и статусы
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
    
    func getChatMemberIds() async -> [UUID] {
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
    
    // MARK: - Read status
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
                    if let deliveredAt = deliveredAt { msg.deliveredAt = deliveredAt }
                    if let readAt = readAt { msg.readAt = readAt }
                } else {
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
                } else {
                    reactionsDict[messageId] = [reaction]
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
    
    func reactionsForMessage(_ messageId: Int64) -> [Reaction] {
        return reactionsDict[messageId] ?? []
    }
    
    private func addReactionLocally(_ reaction: Reaction) {
        DispatchQueue.main.async {
            _ = self.database.saveReaction(reaction)
            var list = self.reactionsDict[reaction.messageId] ?? []
            if !list.contains(where: { $0.userId == reaction.userId && $0.emoji == reaction.emoji }) {
                list.append(reaction)
                self.reactionsDict[reaction.messageId] = list
            }
            if let index = self.messages.firstIndex(where: { $0.messageId == reaction.messageId }) {
                var msg = self.messages[index]
                var newReactions = msg.reactions ?? []
                if !newReactions.contains(where: { $0.userId == reaction.userId && $0.emoji == reaction.emoji }) {
                    newReactions.append(reaction)
                    msg.reactions = newReactions
                    self.messages.remove(at: index)
                    self.messages.insert(msg, at: index)
                }
            }
            self.objectWillChange.send()
        }
    }

    private func removeReactionLocally(messageId: Int64, userId: UUID, emoji: String) {
        DispatchQueue.main.async {
            _ = self.database.deleteReaction(messageId: messageId, userId: userId, emoji: emoji)
            if var list = self.reactionsDict[messageId] {
                list.removeAll(where: { $0.userId == userId && $0.emoji == emoji })
                if list.isEmpty {
                    self.reactionsDict.removeValue(forKey: messageId)
                } else {
                    self.reactionsDict[messageId] = list
                }
            }
            if let index = self.messages.firstIndex(where: { $0.messageId == messageId }) {
                var msg = self.messages[index]
                msg.reactions?.removeAll(where: { $0.userId == userId && $0.emoji == emoji })
                self.messages[index] = msg
            }
            self.objectWillChange.send()
        }
    }
    
    func isCurrentUser(senderId: UUID) -> Bool {
        return senderId == AppState.shared.currentUser?.userId
    }
    
    func getUser(for senderId: UUID) -> User? {
        return usersCache[senderId]
    }
    
    // MARK: - Send message (с поддержкой pending forward)
    func sendMessage(attachmentId: UUID? = nil,
                     storagePath: String? = nil,
                     fileName: String? = nil,
                     fileSize: Int? = nil,
                     mimeType: String? = nil,
                     replyToId: Int64? = nil,
                     forwardedFromUserId: UUID? = nil,
                     forwardedFromNickname: String? = nil,
                     customContent: String? = nil) async -> Bool {
        
        let content = (customContent ?? newMessageText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || attachmentId != nil else { return false }
        guard let currentUserId = currentUserId else { return false }
        
        let tempId = Int64(Date().timeIntervalSince1970 * -1000)
        var tempMessage = Message(
            messageId: tempId, chatId: chat.id, senderId: currentUserId,
            replyToId: replyToId,
            content: content, type: "text",
            createdAt: Date(), updatedAt: Date(), deletedAt: nil,
            isEdited: false, deliveredAt: nil, readAt: nil
        )
        tempMessage.forwardedFromUserId = forwardedFromUserId
        tempMessage.forwardedFromNickname = forwardedFromNickname
        
        if let aid = attachmentId, let fname = fileName, let storage = storagePath {
            let localAttachment = Attachment(
                attachmentId: aid,
                fileName: fname,
                fileSize: fileSize,
                mimeType: mimeType,
                storagePath: storage,
                uploadedAt: Date(),
                messageCreatedAt: nil
            )
            tempMessage.attachments = [localAttachment]
            await MainActor.run {
                self.messages.append(tempMessage)
                if customContent == nil { self.newMessageText = "" }
                self.objectWillChange.send()
            }
        } else {
            await MainActor.run {
                self.messages.append(tempMessage)
                if customContent == nil { self.newMessageText = "" }
                self.objectWillChange.send()
            }
        }
        
        do {
            var variables: [String: Any] = [
                "chatId": chat.id.uuidString,
                "content": content
            ]
            if let aid = attachmentId {
                variables["attachmentId"] = aid.uuidString
            }
            if let replyId = replyToId {
                variables["replyToId"] = Int(replyId)
            }
            if let forwardUserId = forwardedFromUserId {
                variables["forwardedFromUserId"] = forwardUserId.uuidString
            }
            if let forwardNick = forwardedFromNickname {
                variables["forwardedFromNickname"] = forwardNick
            }
            
            let response: SendMessageResponse = try await graphQL.perform(
                query: GraphQLQueries.sendMessage,
                variables: variables,
                responseType: SendMessageResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let realMsg = response.message.sendMessage
            
            await MainActor.run {
                self.messages.removeAll { $0.messageId == tempId }
                self.messages.append(realMsg)
                self.messages.sort { $0.createdAt < $1.createdAt }
                self.enrichMessagesWithReplies()
                _ = self.database.saveMessage(realMsg)
                if let attachments = realMsg.attachments, !attachments.isEmpty {
                    _ = self.database.saveAttachments(attachments, for: realMsg.messageId, messageCreatedAt: realMsg.createdAt)
                }
                self.objectWillChange.send()
                self.enrichMessageWithReplyIfNeeded(realMsg)
                self.newMessageText = ""
            }
            return true
        } catch {
            await MainActor.run {
                self.messages.removeAll { $0.messageId == tempId }
                NotificationService.shared.showError("Не удалось отправить сообщение")
                self.objectWillChange.send()
            }
            return false
        }
    }
    

    func scrollToMessage(messageId: Int64, completion: @escaping () -> Void) {
        print("🔵 scrollToMessage вызван для messageId = \(messageId)")
        
        if messages.contains(where: { $0.messageId == messageId }) {
            print("✅ сообщение уже есть в массиве, устанавливаю scrollToMessageId")
            scrollToMessageId = messageId
            completion()
            return
        }
        
        if let message = database.getMessage(byId: messageId, chatId: chat.id) {
            print("📀 сообщение найдено в БД, добавляю в массив")
            DispatchQueue.main.async {
                self.messages.append(message)
                self.messages.sort { $0.createdAt < $1.createdAt }
                self.objectWillChange.send()
                self.scrollToMessageId = messageId
                completion()
            }
            return
        }
        
        Task {
            print("🌐 загружаем сообщение с сервера")
            if let message = await fetchMessage(byId: messageId) {
                await MainActor.run {
                    if !self.messages.contains(where: { $0.messageId == message.messageId }) {
                        self.messages.append(message)
                        self.messages.sort { $0.createdAt < $1.createdAt }
                        _ = self.database.saveMessage(message)
                        self.objectWillChange.send()
                    }
                    self.scrollToMessageId = messageId
                    completion()
                }
            } else {
                print("❌ сообщение не найдено нигде")
                completion()
            }
        }
    }

    // MARK: - Enrich messages with replies
    private func enrichMessagesWithReplies() {
        var dict = [Int64: Message]()
        for msg in messages {
            dict[msg.messageId] = msg
        }
        for i in 0..<messages.count {
            if let replyId = messages[i].replyToId, let parent = dict[replyId] {
                messages[i].replyToContent = parent.content ?? (parent.attachments != nil ? "[Вложение]" : "")
            } else {
                messages[i].replyToContent = nil
            }
        }
    }

    private func enrichMessageWithReplyIfNeeded(_ message: Message) {
        guard let replyId = message.replyToId else { return }
        
        if let parent = messages.first(where: { $0.messageId == replyId }) {
            updateReplyFields(for: message, with: parent)
            return
        }
        
        if let parent = database.getMessage(byId: replyId, chatId: chat.id) {
            updateReplyFields(for: message, with: parent)
            if !messages.contains(where: { $0.messageId == parent.messageId }) {
                messages.append(parent)
                messages.sort { $0.createdAt < $1.createdAt }
                _ = database.saveMessage(parent)
            }
            return
        }
        
        Task {
            if let parent = await fetchMessage(byId: replyId) {
                await MainActor.run {
                    if !self.messages.contains(where: { $0.messageId == parent.messageId }) {
                        self.messages.append(parent)
                        self.messages.sort { $0.createdAt < $1.createdAt }
                        _ = self.database.saveMessage(parent)
                    }
                    self.updateReplyFields(for: message, with: parent)
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func updateReplyFields(for message: Message, with parent: Message) {
        guard let index = messages.firstIndex(where: { $0.messageId == message.messageId }) else { return }
        messages[index].replyToContent = parent.content ?? (parent.attachments != nil ? "[Вложение]" : "")
        objectWillChange.send()
    }
    
    func fetchMessage(byId messageId: Int64) async -> Message? {
        print("🔄 [fetchMessage] Запрашиваем сообщение \(messageId) с сервера...")
        let variables: [String: Any] = ["messageId": messageId, "chatId": chat.id.uuidString]
        do {
            let response: GetMessageResponse = try await graphQL.perform(
                query: GraphQLQueries.getMessage,
                variables: variables,
                responseType: GetMessageResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            let fetched = response.message.getMessage
            print("✅ [fetchMessage] Получено сообщение \(messageId), реакций: \(fetched.reactions?.count ?? 0)")
            return fetched
        } catch {
            print("❌ [fetchMessage] Ошибка: \(error)")
            return nil
        }
    }
    
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
        guard chat.isPrivate else { return }
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
        guard chat.isPrivate else {
            chatTitle = "Чат"
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
            _ = self.database.deleteMessage(messageId)
            self.objectWillChange.send()
        }
    }
    
    private func addMessage(_ message: Message) {
        DispatchQueue.main.async {
            guard !self.messages.contains(where: { $0.messageId == message.messageId }) else {
                print("⚠️ Duplicate message \(message.messageId) ignored")
                return
            }
            var newMessages = self.messages
            newMessages.append(message)
            newMessages.sort(by: { $0.createdAt < $1.createdAt })
            self.messages = newMessages
            self.enrichMessagesWithReplies()
            _ = self.database.saveMessage(message)
            if let attachments = message.attachments, !attachments.isEmpty {
                _ = self.database.saveAttachments(attachments, for: message.messageId, messageCreatedAt: message.createdAt)
            }
            if let reactions = message.reactions {
                for reaction in reactions { _ = self.database.saveReaction(reaction) }
            }
            self.objectWillChange.send()
            self.enrichMessageWithReplyIfNeeded(message)
        }
    }
    
    private func sendDeliveredIfNeeded(for message: Message) {
        guard message.senderId != currentUserId else { return }
        WebSocketService.shared.sendAck(messageId: message.messageId, chatId: chat.id)
    }
    
    func refreshOtherUserStatus() async {
        guard let otherUser = otherUser else { return }
        do {
            let updatedUser = try await UserService.shared.getUser(userId: otherUser.userId)
            await MainActor.run {
                self.otherUser = updatedUser
                self.isOtherUserOnline = updatedUser.isOnline ?? false
                self.objectWillChange.send()
            }
        } catch {
            print("Failed to refresh user status: \(error)")
        }
    }
}

private struct EmptyResponse: Decodable {}
