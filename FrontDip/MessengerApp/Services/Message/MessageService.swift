// MessageService.swift
import Foundation
import Combine

class MessageService: ObservableObject {
    static let shared = MessageService()
    
    private let webSocketService = WebSocketService.shared
    private let database = LocalDatabase.shared
    
    @Published var unreadMessagesCount: Int = 0
    
    private var pendingMessages: [Int64: Message] = [:]      // ключ Int64
    private var retryTimers: [Int64: Timer] = [:]           // ключ Int64
    private var retryAttempts: [Int64: Int] = [:]           // ключ Int64
    private let maxRetryAttempts = 3
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWebSocketHandlers()
    }
    
    private func setupWebSocketHandlers() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let message = notification.object as? Message {
                    self?.handleIncomingMessages([message])
                }
            }
            .store(in: &cancellables)
    }
    
    func sendMessage(_ message: Message, to chatId: UUID) {
        let messageId = message.message_id   // Int64
        print("📤 Sending message to chat \(chatId)")
        
        if !database.messageExists(messageId) {
            _ = database.saveMessage(message)
        }
        pendingMessages[messageId] = message
        sendViaWebSocket(message: message)
        startRetryTimer(for: messageId)
    }
    
    private func sendViaWebSocket(message: Message) {
        let messageId = message.message_id
        let wsMessage = WebSocketMessage(
            type: "chat_message",
            chatId: message.chat_id,
            content: message.content,
            messageId: messageId,
            timestamp: message.created_at
        )
        webSocketService.sendMessage(wsMessage)
    }
    
    private func startRetryTimer(for messageId: Int64) {
        retryTimers[messageId]?.invalidate()
        let attempt = (retryAttempts[messageId] ?? 0) + 1
        retryAttempts[messageId] = attempt
        if attempt > maxRetryAttempts {
            pendingMessages.removeValue(forKey: messageId)
            retryAttempts.removeValue(forKey: messageId)
            return
        }
        let delay = TimeInterval(pow(3.0, Double(attempt - 1)) * 5)
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let msg = self.pendingMessages[messageId] else { return }
            self.sendViaWebSocket(message: msg)
        }
        retryTimers[messageId] = timer
    }
    
    private func stopRetryTimer(for messageId: Int64) {
        retryTimers[messageId]?.invalidate()
        retryTimers.removeValue(forKey: messageId)
        retryAttempts.removeValue(forKey: messageId)
    }
    
    private func handleIncomingMessages(_ messages: [Message]) {
        for message in messages {
            let messageId = message.message_id
            if database.messageExists(messageId) { continue }
            _ = database.saveMessage(message)
            sendMessageAck(for: message)
            NotificationCenter.default.post(name: .newMessageReceived, object: message)
        }
    }
    
    private func sendMessageAck(for message: Message) {
        guard let currentUser = AppState.shared.currentUser else { return }
        let ackMessage = WebSocketMessage(
            type: "message_ack",
            messageId: message.message_id,
            timestamp: Date(),
            originalSenderId: message.sender_id,
            ackSenderId: currentUser.id
        )
        webSocketService.sendMessage(ackMessage)
    }
    
    func handleMessageAck(messageId: Int64, from recipientId: UUID) {
        guard pendingMessages[messageId] != nil else { return }
        pendingMessages.removeValue(forKey: messageId)
        stopRetryTimer(for: messageId)
        _ = database.updateMessageStatus(messageId: messageId, isSent: true, isDelivered: true)
    }
    
    func getMessages(for chatId: UUID) -> [Message] {
        return database.getMessages(for: chatId)
    }
    
    func clearChatMessages(for chatId: UUID) {
        database.clearMessages(for: chatId)
    }
    
    func clearAll() {
        for timer in retryTimers.values { timer.invalidate() }
        retryTimers.removeAll()
        retryAttempts.removeAll()
        pendingMessages.removeAll()
        unreadMessagesCount = 0
    }
}
