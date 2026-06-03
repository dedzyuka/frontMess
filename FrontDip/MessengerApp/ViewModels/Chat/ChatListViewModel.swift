// ./FrontDip/MessengerApp/ViewModels/Chat/ChatListViewModel.swift
import Foundation
import Combine

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let graphQL = GraphQLClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: UUID? { AppState.shared.currentUser?.userId }
    
    private var unreadCounts: [UUID: Int] = [:]
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .chatCreated)
            .sink { [weak self] notification in
                if let newChat = notification.object as? Chat {
                    self?.addChat(newChat)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let message = notification.object as? Message else { return }
                self?.handleNewMessage(message)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .messageUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64,
                      let chatId = info["chatId"] as? UUID,
                      let content = info["content"] as? String else { return }
                self?.handleMessageUpdated(chatId: chatId, messageId: messageId, newContent: content)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .messageDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let (messageId, chatId) = notification.object as? (Int64, UUID) else { return }
                self?.handleMessageDeleted(chatId: chatId, messageId: messageId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .statusUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let info = notification.object as? [String: Any],
                      let messageId = info["messageId"] as? Int64,
                      let chatId = info["chatId"] as? UUID,
                      let userId = info["userId"] as? UUID else { return }
                self?.handleStatusUpdate(chatId: chatId, messageId: messageId, userId: userId, info: info)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .chatOpened)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let chatId = notification.object as? UUID {
                    self?.resetUnreadCount(for: chatId)
                }
            }
            .store(in: &cancellables)
        
        // НОВАЯ ПОДПИСКА: обновление онлайн-статуса для приватных чатов
        NotificationCenter.default.publisher(for: .statusUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let info = notification.object as? [String: Any],
                      let userId = info["userId"] as? UUID,
                      let isOnline = info["is_online"] as? Bool else { return }
                for i in 0..<self.chats.count where self.chats[i].otherUserId == userId {
                    self.chats[i].otherUserIsOnline = isOnline
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
            let loadedChats = response.chat.list
            await MainActor.run {
                var updatedChats = loadedChats
                for i in 0..<updatedChats.count {
                    let chatId = updatedChats[i].id
                    updatedChats[i].unreadCount = self.unreadCounts[chatId] ?? 0
                    if let preview = updatedChats[i].lastMessagePreview,
                       preview.senderId == self.currentUserId {
                        updatedChats[i].lastMessageStatus = self.fetchMessageStatus(for: preview.messageId)
                    }
                }
                self.chats = updatedChats.sorted { $0.lastActivityDate > $1.lastActivityDate }
                self.isLoading = false
                self.errorMessage = nil
            }
            // Обогащаем приватные чаты информацией о втором участнике
            await enrichPrivateChats()
            await MainActor.run { self.objectWillChange.send() }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка загрузки чатов: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // НОВЫЙ МЕТОД: загрузка данных о втором участнике для приватных чатов
    private func enrichPrivateChats() async {
        guard let currentUserId = currentUserId else { return }
        for i in 0..<chats.count where chats[i].chatType.lowercased() == "private" {
            let chatId = chats[i].id
            // Пропускаем уже загруженные
            if chats[i].otherUserId != nil { continue }
            let memberIds = await getChatMemberIds(for: chatId)
            let otherId = memberIds.first(where: { $0 != currentUserId })
            guard let otherId else { continue }
            do {
                let otherUser = try await UserService.shared.getUser(userId: otherId)
                await MainActor.run {
                    if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                        self.chats[index].otherUserId = otherId
                        self.chats[index].otherUserNickname = otherUser.nickName
                        self.chats[index].otherUserAvatarUrl = otherUser.avatarUrl
                        self.chats[index].otherUserIsOnline = otherUser.isOnline ?? false
                        self.objectWillChange.send()  // Принудительное обновление UI
                    }
                }
            } catch {
                print("Failed to load other user for chat \(chatId): \(error)")
            }
        }
    }
    
    private func getChatMemberIds(for chatId: UUID) async -> [UUID] {
        let variables = ["chatId": chatId.uuidString]
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
    

    private func handleNewMessage(_ message: Message) {
        guard let index = chats.firstIndex(where: { $0.id == message.chatId }) else {
            Task { await loadChats() }
            return
        }
        
        var updatedChat = chats[index]
        let preview = MessagePreview(
            messageId: message.messageId,
            senderId: message.senderId,
            senderNickname: nil,
            textPreview: message.content ?? (message.attachments != nil ? "[Вложение]" : ""),
            createdAt: message.createdAt,
            type: message.type
        )
        updatedChat.lastMessagePreview = preview
        
        if message.senderId != currentUserId {
            updatedChat.unreadCount += 1
            unreadCounts[message.chatId] = updatedChat.unreadCount
        } else {
            updatedChat.lastMessageStatus = .sending
        }
        
        chats[index] = updatedChat
        chats.sort { $0.lastActivityDate > $1.lastActivityDate }
    }
    
    private func handleMessageUpdated(chatId: UUID, messageId: Int64, newContent: String) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }),
              var preview = chats[index].lastMessagePreview,
              preview.messageId == messageId else { return }
        let updatedPreview = MessagePreview(
            messageId: preview.messageId,
            senderId: preview.senderId,
            senderNickname: preview.senderNickname,
            textPreview: newContent,
            createdAt: preview.createdAt,
            type: preview.type
        )
        var updatedChat = chats[index]
        updatedChat.lastMessagePreview = updatedPreview
        chats[index] = updatedChat
        chats.sort { $0.lastActivityDate > $1.lastActivityDate }
    }

    private func handleMessageDeleted(chatId: UUID, messageId: Int64) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }),
              let preview = chats[index].lastMessagePreview,
              preview.messageId == messageId else { return }
        Task {
            await refreshChat(chatId)
        }
    }
    func refreshChat(_ chatId: UUID) async {
        // Опционально: сделать запрос одного чата, пока перезагружаем все
        await loadChats()
    }
    
    private func handleStatusUpdate(chatId: UUID, messageId: Int64, userId: UUID, info: [String: Any]) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }),
              let preview = chats[index].lastMessagePreview,
              preview.messageId == messageId,
              let deliveredAt = info["deliveredAt"] as? Date?,
              let readAt = info["readAt"] as? Date? else { return }
        
        var updatedChat = chats[index]
        if readAt != nil {
            updatedChat.lastMessageStatus = .read
        } else if deliveredAt != nil {
            updatedChat.lastMessageStatus = .delivered
        } else {
            updatedChat.lastMessageStatus = .sending
        }
        chats[index] = updatedChat
    }
    
    private func refreshLastMessage(for chatId: UUID) async {
        await loadChats()
    }
    
    private func fetchMessageStatus(for messageId: Int64) -> MessageStatusType? {
        // Получаем статус из локальной БД для данного сообщения
        guard let (deliveredAt, readAt) = LocalDatabase.shared.getMessageStatus(for: messageId, userId: currentUserId ?? UUID()) else { return nil }
        if readAt != nil { return .read }
        if deliveredAt != nil { return .delivered }
        return .sending
    }
    
    // MARK: - Сброс непрочитанных
    func resetUnreadCount(for chatId: UUID) {
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            var chat = chats[index]
            chat.unreadCount = 0
            chats[index] = chat
            unreadCounts[chatId] = 0
        }
    }
    
    // MARK: - Существующие методы (без изменений)
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
        if let existing = await findExistingPrivateChat(with: userId) {
            return existing
        }
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
                let members = await getChatMemberIds(for: chat.id)
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
    
    func addChat(_ chat: Chat) {
        DispatchQueue.main.async {
            if !self.chats.contains(where: { $0.id == chat.id }) {
                self.chats.insert(chat, at: 0)
            }
        }
    }
}
