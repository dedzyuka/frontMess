// ./FrontDip/MessengerApp/Services/Message/MessageService.swift
import Foundation
import Combine

class MessageService: ObservableObject {
    static let shared = MessageService()
    
    private let webSocketService = WebSocketService.shared
    private let database = LocalDatabase.shared
    private let keychainService = KeychainService.shared
    
    @Published var unreadMessagesCount: Int = 0
    
    private var pendingMessages: [UUID: Message] = [:] // messageId: Message
    private var retryTimers: [UUID: Timer] = [:] // Таймеры для повторной отправки
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWebSocketHandlers()
    }
    
    private func setupWebSocketHandlers() {
        // Подписываемся на входящие сообщения через NotificationCenter
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                if let message = notification.object as? Message {
                    self?.handleIncomingMessages([message])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Отправка сообщений
    
    func sendMessage(_ message: Message, to chatId: UUID) {
        guard let messageId = message.id else {
            print("❌ Ошибка: у сообщения нет ID")
            return
        }
        
        print("📤 Отправка сообщения в чат \(chatId.uuidString.prefix(8))...")
        
        // 1. Проверяем, нет ли уже такого сообщения в базе
        if database.messageExists(messageId) {
            print("⚠️ Сообщение уже существует в базе, пропускаем сохранение")
        } else {
            // 2. Сохраняем в локальную БД
            _ = database.saveMessage(message)
        }
        
        // 3. Добавляем в очередь ожидания
        pendingMessages[messageId] = message
        
        // 4. Отправляем через WebSocket
        sendViaWebSocket(message: message, chatId: chatId)
        
        // 5. Запускаем таймер для повторной отправки
        startRetryTimer(for: messageId, chatId: chatId)
    }
    
    private func sendViaWebSocket(message: Message, chatId: UUID) {
        guard let messageId = message.id else {
            print("❌ Message ID is nil")
            return
        }
        
        let webSocketMessage = WebSocketMessage(
            type: "chat_message",
            chatId: chatId,
            content: message.content,
            messageId: messageId,
            timestamp: message.timestamp
        )
        
        webSocketService.sendMessage(webSocketMessage)
    }
    
    private func startRetryTimer(for messageId: UUID, chatId: UUID) {
        // Отменяем старый таймер, если есть
        retryTimers[messageId]?.invalidate()
        
        // Создаем новый таймер
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Проверяем, все ли еще сообщение в очереди
            guard let message = self.pendingMessages[messageId] else {
                print("✅ Сообщение \(messageId.uuidString.prefix(8)) удалено из очереди")
                timer.invalidate()
                self.retryTimers.removeValue(forKey: messageId)
                return
            }
            
            print("🔄 Повторная отправка сообщения \(messageId.uuidString.prefix(8))...")
            self.sendViaWebSocket(message: message, chatId: chatId)
        }
        
        retryTimers[messageId] = timer
    }
    
    private func stopRetryTimer(for messageId: UUID) {
        retryTimers[messageId]?.invalidate()
        retryTimers.removeValue(forKey: messageId)
    }
    
    // MARK: - Обработка входящих сообщений
    
    func handleIncomingMessages(_ messages: [Message]) {
        for message in messages {
            // 1. Проверяем, нет ли уже такого сообщения
            if let messageId = message.id, database.messageExists(messageId) {
                print("⚠️ Сообщение \(messageId.uuidString.prefix(8)) уже есть в базе")
                continue
            }
            
            // 2. Сохраняем в локальную БД
            _ = database.saveMessage(message)
            
            // 3. Отправляем подтверждение получения
            sendMessageAck(for: message)
            
            // 4. Уведомляем UI о новом сообщении
            NotificationCenter.default.post(
                name: .newMessageReceived,
                object: message
            )
            
            // 5. Увеличиваем счетчик непрочитанных
            unreadMessagesCount += 1
            
            print("📩 Сообщение сохранено: \(message.content.prefix(30))...")
        }
    }
    
    private func sendMessageAck(for message: Message) {
        guard let messageId = message.id,
              let currentUser = AppState.shared.currentUser else { return }
        
        // Исправленный порядок аргументов
        let ackMessage = WebSocketMessage(
            type: "message_ack",
            chatId: nil,
            content: nil, // content должен идти перед originalSenderId
            messageId: messageId,
            timestamp: Date(),
            senderId: nil,
            recipientId: nil,
            originalSenderId: message.senderId, // теперь originalSenderId после recipientId
            requestId: nil,
            ackSenderId: currentUser.id
        )
        
        webSocketService.sendMessage(ackMessage)
    }
    
    // MARK: - Обработка подтверждений
    
    func handleMessageAck(messageId: UUID, from recipientId: UUID) {
        print("✅ Подтверждение получения сообщения \(messageId.uuidString.prefix(8)) от \(recipientId.uuidString.prefix(8))")
        
        // 1. Удаляем из очереди ожидания
        pendingMessages.removeValue(forKey: messageId)
        
        // 2. Останавливаем таймер
        stopRetryTimer(for: messageId)
        
        // 3. Обновляем статус в локальной БД
        database.updateMessageStatus(
            messageId: messageId,
            isSent: true,
            isDelivered: true
        )
    }
    
    // MARK: - Получение сообщений
    
    func getMessages(for chatId: UUID) -> [Message] {
        return database.getMessages(for: chatId)
    }
    
    func clearChatMessages(for chatId: UUID) {
        database.clearMessages(for: chatId)
    }
    
    // MARK: - Очистка
    
    func clearAll() {
        // Останавливаем все таймеры
        for timer in retryTimers.values {
            timer.invalidate()
        }
        retryTimers.removeAll()
        
        // Очищаем очередь
        pendingMessages.removeAll()
        
        // Сбрасываем счетчик
        unreadMessagesCount = 0
    }
}
