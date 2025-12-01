
import Foundation
import Combine

class WebSocketService: ObservableObject {
    static let shared = WebSocketService()
    
    @Published var isConnected = false
    @Published var receivedMessages: [Message] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let baseURL = "ws://localhost:8000"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupURLSession()
        setupBindings()
    }
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        urlSession = URLSession(configuration: configuration)
    }
    
    private func setupBindings() {
        // Подписка на изменения статуса пользователя
//        AppState.shared.$currentUser
//            .sink { [weak self] user in
//                if let user = user {
//                    self?.connect(userId: user.id)
//                } else {
//                    self?.disconnect()
//                }
//            }
//            .store(in: &cancellables)
    }
    
    func connect(userId: UUID) {
        guard let url = URL(string: "\(baseURL)/ws/\(userId)") else {
            print("❌ Неверный URL WebSocket")
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        listenForMessages()
        startHeartbeat()
        
        print("✅ WebSocket подключен к: \(url)")
        isConnected = true
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
        print("🔌 WebSocket отключен")
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.listenForMessages() // Продолжаем слушать
            case .failure(let error):
                print("❌ Ошибка получения сообщения: \(error)")
                self?.isConnected = false
                self?.reconnect()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            processStringMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                processStringMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func processStringMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Невалидный JSON")
            return
        }
        
        guard let type = json["type"] as? String else {
            print("❌ Сообщение без типа")
            return
        }
        
        switch type {
        case "message":
            handlePrivateMessage(json)
        case "chat_message":
            handleChatMessage(json)
        case "message_ack":
            handleMessageAck(json)
        case "user_status":
            handleUserStatus(json)
        case "contact_request":  // НОВОЕ
            handleContactRequest(json)
        case "contact_accept":   // НОВОЕ
            handleContactAccept(json)
        case "pong":
            print("❤️ Понг получен")
        default:
            print("❓ Неизвестный тип сообщения: \(type)")
        }
    }
    
    private func handleContactRequest(_ data: [String: Any]) {
        guard let senderIdString = data["senderId"] as? String,
              let senderId = UUID(uuidString: senderIdString),
              let contactData = data["contactData"] as? [String: Any],
              let userIdString = contactData["userId"] as? String,
              let userId = UUID(uuidString: userIdString),
              let nickname = contactData["nickname"] as? String,
              let publicKey = contactData["publicKey"] as? String else {
            return
        }
        
        let request = ContactRequest(
            id: UUID(),
            fromUserId: senderId,
            fromNickname: nickname,
            fromPublicKey: publicKey,
            status: "pending",
            createdAt: Date()
        )
        
        // Уведомляем ContactService
        NotificationCenter.default.post(
            name: .newContactRequest,
            object: request
        )
        
        print("📩 Новый запрос на контакт от \(nickname)")
    }

    private func handleContactAccept(_ data: [String: Any]) {
        guard let contactData = data["contactData"] as? [String: Any],
              let userIdString = contactData["userId"] as? String,
              let userId = UUID(uuidString: userIdString),
              let nickname = contactData["nickname"] as? String,
              let publicKey = contactData["publicKey"] as? String else {
            return
        }
        
        let contact = Contact(
            id: UUID(),
            userId: userId,
            nickname: nickname,
            publicKey: publicKey,
            addedAt: Date()
        )
        
        // Уведомляем ContactService
        NotificationCenter.default.post(
            name: .contactRequestAccepted,
            object: contact
        )
        
        print("✅ Запрос на контакт принят: \(nickname)")
    }
    
    private func handlePrivateMessage(_ data: [String: Any]) {
        print("📩 Приватное сообщение: \(data)")
        // TODO: Обработка приватных сообщений
    }
    
    func handleChatMessage(_ data: [String: Any]) {
        guard let chatIdString = data["chat_id"] as? String,
              let chatId = UUID(uuidString: chatIdString),
              let senderIdString = data["sender_id"] as? String,
              let senderId = UUID(uuidString: senderIdString),
              let content = data["content"] as? String,
              let messageIdString = data["message_id"] as? String,
              let messageId = UUID(uuidString: messageIdString),
              let timestampString = data["timestamp"] as? String else {
            return
        }
        
        // Парсим timestamp
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: timestampString) ?? Date()
        
        // Создаем объект сообщения
        let message = Message(
            id: messageId,
            chatId: chatId,
            senderId: senderId,
            content: content,
            type: .text,
            timestamp: timestamp,
            isEncrypted: data["encrypted"] as? Bool ?? true
        )
        
        // Сохраняем в локальную БД через MessageService
        _ = LocalDatabase.shared.saveMessage(message)
        
        // Уведомляем MessageService о новом сообщении
        MessageService.shared.handleIncomingMessages([message])
        
        print("📩 Новое сообщение в чате \(chatIdString.prefix(8)) от \(senderIdString.prefix(8))")
    }
    
    private func handleMessageAck(_ data: [String: Any]) {
        guard let messageIdString = data["message_id"] as? String,
              let messageId = UUID(uuidString: messageIdString),
              let recipientIdString = data["recipient_id"] as? String,
              let recipientId = UUID(uuidString: recipientIdString) else {
            return
        }
        
        // Уведомляем MessageService о подтверждении
        MessageService.shared.handleMessageAck(messageId: messageId, from: recipientId)
    }
    
    private func handleUserStatus(_ data: [String: Any]) {
        guard let userId = data["user_id"] as? String,
              let isOnline = data["is_online"] as? Bool else {
            return
        }
        
        print("👤 Пользователь \(userId) теперь \(isOnline ? "онлайн" : "офлайн")")
    }
    
    func sendMessage(_ message: WebSocketMessage) {
        guard isConnected else {
            print("❌ WebSocket не подключен")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(message)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
                
                webSocketTask?.send(wsMessage) { error in
                    if let error = error {
                        print("❌ Ошибка отправки: \(error)")
                    }
                }
            }
        } catch {
            print("❌ Ошибка кодирования: \(error)")
        }
    }
    
    private func startHeartbeat() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.sendHeartbeat()
            }
            .store(in: &cancellables)
    }
    
    private func sendHeartbeat() {
        let heartbeat = WebSocketMessage(type: "ping")
        sendMessage(heartbeat)
    }
    
    private func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let userId = AppState.shared.currentUser?.id else { return }
            print("🔄 Переподключение WebSocket...")
            self?.connect(userId: userId)
        }
    }
    
    private func decryptMessage(_ encryptedContent: String, chatId: UUID) async -> String? {
        // TODO: Реализовать дешифрование с использованием ключей из Keychain
        return encryptedContent // Пока возвращаем как есть
    }
}



struct WebSocketMessage: Codable {
    let type: String
    var chatId: UUID?
    var senderId: UUID?  // senderId ДОЛЖЕН быть перед recipientId
    var recipientId: UUID?
    var content: String?
    var messageId: UUID?
    var timestamp: Date?
    var contactData: ContactData?
    
    struct ContactData: Codable {
        let userId: UUID
        let nickname: String
        let publicKey: String
    }
    
    init(type: String, chatId: UUID? = nil, senderId: UUID? = nil, recipientId: UUID? = nil,
         content: String? = nil, messageId: UUID? = nil, timestamp: Date? = nil,
         contactData: ContactData? = nil) {
        self.type = type
        self.chatId = chatId
        self.senderId = senderId
        self.recipientId = recipientId
        self.content = content
        self.messageId = messageId
        self.timestamp = timestamp
        self.contactData = contactData
    }
}
