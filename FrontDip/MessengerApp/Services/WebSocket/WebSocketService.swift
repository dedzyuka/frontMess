import Foundation
import Combine

class WebSocketService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var onlineUsers: Int = 0
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let baseURL = "ws://localhost:8000/ws" 
    
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var pingTimer: Timer?
    
    private var messageHandlers: [String: (Any) -> Void] = [:]
    private var pendingMessages: [WebSocketMessage] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus: String {
        case disconnected = "🔴 Отключен"
        case connecting = "🟡 Подключение..."
        case connected = "🟢 Подключен"
        case reconnecting = "🟠 Переподключение..."
    }
    
    private override init() {
        super.init()
        setupURLSession()
        setupMessageHandlers()
        setupBindings()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ WebSocket task failed: \(error)")
        }
    }
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }
    
    private func setupMessageHandlers() {
        // Регистрируем обработчики для разных типов сообщений
        messageHandlers = [
            "chat_message": handleChatMessage,
            "contact_request": handleContactRequest,
            "contact_accept": handleContactAccept,
            "contact_request_sent": handleContactRequestSent,
            "message_ack": handleMessageAck,
            "pong": handlePong,
            "user_status": handleUserStatus
        ]
    }
    
    private func setupBindings() {
        // Автоматическое переподключение при смене статуса
        $connectionStatus
            .sink { [weak self] status in
                switch status {
                case .disconnected:
                    self?.scheduleReconnect()
                case .connected:
                    self?.cancelReconnectTimer()
                    self?.startHeartbeat()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func connect(userId: UUID) {
        guard let deviceId = KeychainService.shared.loadDeviceId() else {
            print("❌ Device ID not found")
            lastError = "Device ID not found"
            return
        }
        
        guard connectionStatus != .connecting && connectionStatus != .connected else {
            print("⚠️ Already connecting or connected")
            return
        }
        
        connectionStatus = .connecting
        lastError = nil
        
        // Формируем URL с параметрами
        let encodedDeviceId = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
        guard let url = URL(string: "\(baseURL)/ws/\(userId)?device_id=\(encodedDeviceId)") else {
            print("❌ Invalid WebSocket URL")
            lastError = "Invalid WebSocket URL"
            connectionStatus = .disconnected
            return
        }
        
        print("🔗 Connecting to WebSocket: \(url)")
        
        // Создаем WebSocket задачу
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Начинаем слушать сообщения
        listenForMessages()
        
        // Отправляем начальный ping
        sendPing()
    }
    
    func disconnect() {
        print("🔌 Disconnecting WebSocket...")
        
        // Останавливаем таймеры
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        pingTimer?.invalidate()
        pingTimer = nil
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        // Закрываем соединение
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        connectionStatus = .disconnected
        isConnected = false
        
        print("✅ WebSocket disconnected")
    }
    
    func sendMessage(_ message: WebSocketMessage) {
        guard connectionStatus == .connected else {
            print("⚠️ Can't send message - not connected")
            
            // Сохраняем для отправки позже (кроме пингов)
            if message.type != "ping" {
                pendingMessages.append(message)
                print("💾 Message saved for later delivery: \(message.type)")
            }
            
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(message)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
                
                webSocketTask?.send(wsMessage) { [weak self] error in
                    if let error = error {
                        print("❌ Error sending message: \(error)")
                        self?.lastError = "Send error: \(error.localizedDescription)"
                        
                        // Сохраняем для повторной отправки
                        if message.type != "ping" {
                            self?.pendingMessages.append(message)
                        }
                    } else {
                        print("✅ Message sent: \(message.type)")
                    }
                }
            }
        } catch {
            print("❌ Error encoding message: \(error)")
            lastError = "Encode error: \(error.localizedDescription)"
        }
    }
    
    func sendChatMessage(chatId: UUID, content: String, messageId: UUID? = nil) {
        let message = WebSocketMessage(
            type: "chat_message",
            chatId: chatId,
            content: content,
            messageId: messageId ?? UUID(),
            timestamp: Date()
        )
        sendMessage(message)
    }
    
    func sendContactRequest(to userId: UUID) {
            guard let currentUser = AppState.shared.currentUser else {
                print("❌ Current user not found")
                return
            }
            
            let message = WebSocketMessage(
                type: "contact_request",
                chatId: nil,
                content: nil,
                messageId: nil,
                timestamp: Date(),
                senderId: currentUser.id,
                recipientId: userId,
                originalSenderId: nil,
                requestId: UUID(),
                ackSenderId: nil,
                senderNickname: currentUser.nickname,
                senderPublicKey: currentUser.publicKey
            )
            sendMessage(message)
        }
    
    func sendContactAccept(to userId: UUID) {
            guard let currentUser = AppState.shared.currentUser else {
                print("❌ Current user not found")
                return
            }
            
            let message = WebSocketMessage(
                type: "contact_accept",
                chatId: nil,
                content: nil,
                messageId: nil,
                timestamp: Date(),
                senderId: nil,
                recipientId: nil,
                originalSenderId: userId,
                requestId: nil,
                ackSenderId: nil,
                senderNickname: nil,
                senderPublicKey: nil,
                recipientNickname: nil,
                acceptedUserId: currentUser.id,
                acceptedNickname: currentUser.nickname,
                acceptedPublicKey: currentUser.publicKey
            )
            sendMessage(message)
        }
    
    // MARK: - Private Methods
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleWebSocketMessage(message)
                self.listenForMessages() // Продолжаем слушать
                
            case .failure(let error):
                print("❌ Error receiving message: \(error)")
                self.lastError = "Receive error: \(error.localizedDescription)"
                
                // Если это не преднамеренное отключение
                if (error as NSError).code != 57 { // Socket is not connected
                    self.connectionStatus = .disconnected
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
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
        guard let data = text.data(using: .utf8) else {
            print("❌ Cannot convert message to data")
            return
        }
        
        do {
            // Пытаемся декодировать в WebSocketMessage
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let message = try decoder.decode(WebSocketMessage.self, from: data)
            
            print("📩 Received message type: \(message.type)")
            
            // Вызываем соответствующий обработчик
            if let handler = messageHandlers[message.type] {
                handler(message)
            } else {
                print("⚠️ No handler for message type: \(message.type)")
            }
            
        } catch {
            print("❌ Error parsing message JSON: \(error)")
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleChatMessage(_ data: Any) {
        guard let message = data as? WebSocketMessage,
              let chatId = message.chatId,
              let senderId = message.senderId,
              let content = message.content,
              let messageId = message.messageId,
              let timestamp = message.timestamp else {
            print("❌ Invalid chat message format")
            return
        }
        
        // Создаем объект сообщения
        let messageObj = Message(
            id: messageId,
            chatId: chatId,
            senderId: senderId,
            content: content,
            type: .text,
            timestamp: timestamp,
            isEncrypted: true
        )
        
        // Сохраняем в локальную БД
        DispatchQueue.main.async {
            _ = LocalDatabase.shared.saveMessage(messageObj)
            
            // Уведомляем о новом сообщении
            NotificationCenter.default.post(
                name: .newMessageReceived,
                object: messageObj
            )
            
            print("📩 Chat message saved: \(content.prefix(20))...")
        }
    }
    
    private func handleContactRequest(_ data: Any) {
        guard let message = data as? WebSocketMessage,
              let requestId = message.requestId,
              let senderId = message.senderId,
              let senderNickname = message.senderNickname,
              let senderPublicKey = message.senderPublicKey else {
            print("❌ Invalid contact request format")
            return
        }
        
        let request = ContactRequest(
            id: requestId,
            fromUserId: senderId,
            fromNickname: senderNickname,
            fromPublicKey: senderPublicKey,
            status: "pending",
            createdAt: message.timestamp ?? Date()
        )
        
        // Передаем в ContactService
        ContactService.shared.handleIncomingContactRequest(request)
    }
    private var offlineMessages: [UUID: [WebSocketMessage]] = [:]

    func saveOfflineMessage(_ message: WebSocketMessage, for userId: UUID) {
        if offlineMessages[userId] == nil {
            offlineMessages[userId] = []
        }
        offlineMessages[userId]?.append(message)
    }

    func sendOfflineMessages(for userId: UUID) {
        guard let messages = offlineMessages[userId] else { return }
        
        for message in messages {
            sendMessage(message)
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        offlineMessages.removeValue(forKey: userId)
    }
    
    private func handleContactAccept(_ data: Any) {
        guard let message = data as? WebSocketMessage,
              let acceptedUserId = message.acceptedUserId,
              let acceptedNickname = message.acceptedNickname,
              let acceptedPublicKey = message.acceptedPublicKey else {
            print("❌ Invalid contact accept format")
            return
        }
        
        let contact = Contact(
            id: UUID(),
            userId: acceptedUserId,
            nickname: acceptedNickname,
            publicKey: acceptedPublicKey,
            addedAt: Date()
        )
        
        // Передаем в ContactService
        ContactService.shared.handleContactRequestAccepted(contact)
    }
    
    private func handleContactRequestSent(_ data: Any) {
        guard let message = data as? WebSocketMessage,
              let recipientNickname = message.recipientNickname else {
            return
        }
        
        DispatchQueue.main.async {
            NotificationService.shared.showSuccess("Запрос на контакт отправлен \(recipientNickname)")
            print("✅ Contact request sent to \(recipientNickname)")
        }
    }
    
    private func handleMessageAck(_ data: Any) {
        guard let message = data as? WebSocketMessage,
              let messageId = message.messageId,
              let ackSenderId = message.ackSenderId else {
            return
        }
        
        print("✅ Message \(messageId.uuidString.prefix(8)) acknowledged by \(ackSenderId.uuidString.prefix(8))")
        
        // Передаем в MessageService
        MessageService.shared.handleMessageAck(messageId: messageId, from: ackSenderId)
    }
    
    private func handlePong(_ data: Any) {
        print("❤️ Pong received")
        // Обновляем время последней активности
    }
    
    private func handleUserStatus(_ data: Any) {
        // Обработка статусов пользователей
        print("👤 User status update")
    }
    
    // MARK: - Connection Management
    
    private func sendPing() {
        let pingMessage = WebSocketMessage(type: "ping", timestamp: Date())
        sendMessage(pingMessage)
    }
    
    private func startHeartbeat() {
        // Останавливаем старый таймер
        heartbeatTimer?.invalidate()
        
        // Запускаем новый таймер для пинга каждые 30 секунд
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
        
        // Отправляем ожидающие сообщения
        sendPendingMessages()
    }
    
    private func sendPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        print("📤 Sending \(pendingMessages.count) pending messages...")
        
        let messagesToSend = pendingMessages
        pendingMessages.removeAll()
        
        for message in messagesToSend {
            sendMessage(message)
            // Небольшая задержка между сообщениями
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectTimer == nil else { return }
        
        print("🔄 Scheduling reconnect in 5 seconds...")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            guard let self = self,
                  let userId = AppState.shared.currentUser?.id,
                  self.connectionStatus == .disconnected else {
                return
            }
            
            print("🔄 Attempting to reconnect...")
            self.connectionStatus = .reconnecting
            self.connect(userId: userId)
        }
    }
    
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connection opened")
        
        DispatchQueue.main.async {
            self.connectionStatus = .connected
            self.isConnected = true
            self.lastError = nil
            
            // Уведомляем о успешном подключении
            NotificationCenter.default.post(
                name: .websocketConnected,
                object: nil
            )
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown"
        print("🔌 WebSocket closed with code: \(closeCode), reason: \(reasonString)")
        
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isConnected = false
            
            if closeCode != .normalClosure {
                self.lastError = "Connection closed: \(reasonString)"
                
                // Уведомляем о разрыве соединения
                NotificationCenter.default.post(
                    name: .websocketDisconnected,
                    object: reasonString
                )
            }
        }
    }
}

// MARK: - WebSocket Message Models

struct WebSocketMessage: Codable {
    let type: String
    var chatId: UUID?
    var content: String?
    var messageId: UUID?
    var timestamp: Date?
    var senderId: UUID?
    var recipientId: UUID?
    var originalSenderId: UUID?
    var requestId: UUID?
    var ackSenderId: UUID?
    var senderNickname: String?
    var senderPublicKey: String?
    var recipientNickname: String?
    var acceptedUserId: UUID?
    var acceptedNickname: String?
    var acceptedPublicKey: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case chatId = "chat_id"
        case content
        case messageId = "message_id"
        case timestamp
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case originalSenderId = "original_sender_id"
        case requestId = "request_id"
        case ackSenderId = "ack_sender_id"
        case senderNickname = "sender_nickname"
        case senderPublicKey = "sender_public_key"
        case recipientNickname = "recipient_nickname"
        case acceptedUserId = "accepted_user_id"
        case acceptedNickname = "accepted_nickname"
        case acceptedPublicKey = "accepted_public_key"
    }
    
    init(type: String,
         chatId: UUID? = nil,
         content: String? = nil,
         messageId: UUID? = nil,
         timestamp: Date? = nil,
         senderId: UUID? = nil,
         recipientId: UUID? = nil,
         originalSenderId: UUID? = nil,
         requestId: UUID? = nil,
         ackSenderId: UUID? = nil,
         senderNickname: String? = nil,
         senderPublicKey: String? = nil,
         recipientNickname: String? = nil,
         acceptedUserId: UUID? = nil,
         acceptedNickname: String? = nil,
         acceptedPublicKey: String? = nil) {
        self.type = type
        self.chatId = chatId
        self.content = content
        self.messageId = messageId
        self.timestamp = timestamp
        self.senderId = senderId
        self.recipientId = recipientId
        self.originalSenderId = originalSenderId
        self.requestId = requestId
        self.ackSenderId = ackSenderId
        self.senderNickname = senderNickname
        self.senderPublicKey = senderPublicKey
        self.recipientNickname = recipientNickname
        self.acceptedUserId = acceptedUserId
        self.acceptedNickname = acceptedNickname
        self.acceptedPublicKey = acceptedPublicKey
    }
}


