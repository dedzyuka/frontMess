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
    
    private var retryAttempts: [UUID: Int] = [:] // Счетчик попыток для каждого сообщения
        private let maxRetryAttempts = 3
    
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
            // Отменяем старый таймер
            retryTimers[messageId]?.invalidate()
            
            // Увеличиваем счетчик попыток
            let attempt = (retryAttempts[messageId] ?? 0) + 1
            retryAttempts[messageId] = attempt
            
            // Если превысили лимит - удаляем из очереди
            if attempt > maxRetryAttempts {
                print("❌ Превышено максимальное количество попыток (\(maxRetryAttempts)) для сообщения \(messageId.uuidString.prefix(8))")
                pendingMessages.removeValue(forKey: messageId)
                retryAttempts.removeValue(forKey: messageId)
                return
            }
            
            // Экспоненциальная задержка: 5, 15, 45 секунд
            let delay = TimeInterval(pow(3.0, Double(attempt - 1)) * 5)
            
            print("⏰ Установлен таймер повторной отправки через \(delay) секунд (попытка \(attempt)/\(maxRetryAttempts))")
            
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                // Проверяем, все ли еще сообщение в очереди
                guard let message = self.pendingMessages[messageId] else {
                    print("✅ Сообщение \(messageId.uuidString.prefix(8)) удалено из очереди")
                    timer.invalidate()
                    self.retryTimers.removeValue(forKey: messageId)
                    self.retryAttempts.removeValue(forKey: messageId)
                    return
                }
                
                print("🔄 Повторная отправка сообщения \(messageId.uuidString.prefix(8)) (попытка \(attempt)/\(maxRetryAttempts))...")
                self.sendViaWebSocket(message: message, chatId: chatId)
            }
            
            retryTimers[messageId] = timer
        }
    
    private func stopRetryTimer(for messageId: UUID) {
            retryTimers[messageId]?.invalidate()
            retryTimers.removeValue(forKey: messageId)
            retryAttempts.removeValue(forKey: messageId) // 🔥 ВАЖНО: очищаем счетчик
            print("⏹️ Остановлен таймер для сообщения \(messageId.uuidString.prefix(8))")
        }
    
    // MARK: - Обработка входящих сообщений
    
    private func handleIncomingMessages(_ messages: [Message]) {
        for message in messages {
            guard let messageId = message.id else { continue }
            
            // Проверка ДО обработки
            if database.messageExists(messageId) {
                print("⚠️ Пропускаем дубликат: \(messageId)")
                continue
            }
            
            // Сохранение
            _ = database.saveMessage(message)
            
            // Отправка ACK
            sendMessageAck(for: message)
            
            // Уведомление UI
            NotificationCenter.default.post(name: .newMessageReceived, object: message)
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
    
    // В MessageService.swift
    func handleMessageAck(messageId: UUID, from recipientId: UUID) {
        print("✅ Подтверждение получения сообщения \(messageId.uuidString.prefix(8)) от \(recipientId.uuidString.prefix(8))")
        
        // 🔥 ДОБАВИТЬ: Проверяем, что сообщение еще в очереди
        guard pendingMessages[messageId] != nil else {
            print("⚠️ Сообщение уже удалено из очереди")
            return
        }
        
        // 1. Удаляем из очереди ожидания
        pendingMessages.removeValue(forKey: messageId)
        
        // 2. Останавливаем таймер
        stopRetryTimer(for: messageId)
        
        // 3. Обновляем статус в локальной БД
        let success = database.updateMessageStatus(
            messageId: messageId,
            isSent: true,
            isDelivered: true
        )
        
        if success {
            print("✅ Статус сообщения обновлен: доставлено")
        } else {
            print("⚠️ Не удалось обновить статус сообщения")
        }
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
            retryAttempts.removeAll() // 🔥 Очищаем счетчики
            
            // Очищаем очередь
            pendingMessages.removeAll()
            
            // Сбрасываем счетчик
            unreadMessagesCount = 0
        }
}
