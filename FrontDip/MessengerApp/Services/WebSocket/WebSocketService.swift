// ./FrontDip/MessengerApp/Services/WebSocket/WebSocketService.swift
import Foundation
import Combine

// MARK: - WebSocket Message Model
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

// MARK: - WebSocket Service
class WebSocketService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    private let baseURL = "ws://localhost:8000"
    private var currentUserId: UUID?
    
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var pendingMessages: [WebSocketMessage] = []
    
    private var messageHandlers: [String: (WebSocketMessage) -> Void] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus: String {
        case disconnected = "🔴 Отключен"
        case connecting = "🟡 Подключение..."
        case connected = "🟢 Подключен"
    }
    
    private override init() {
        super.init()
        setupURLSession()
        setupMessageHandlers()
        setupBindings()
    }
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        urlSession = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: OperationQueue()
        )
    }
    
    private func setupMessageHandlers() {
        messageHandlers = [
            "chat_message": handleChatMessage,
            "contact_request": handleContactRequest,
            "contact_accept": handleContactAccept,
            "contact_request_sent": handleContactRequestSent,
            "message_ack": handleMessageAck,
            "pong": handlePong
        ]
    }
    
    private func setupBindings() {
        $connectionStatus
            .sink { [weak self] status in
                switch status {
                case .disconnected:
                    self?.scheduleReconnect()
                case .connected:
                    self?.cancelReconnectTimer()
                    self?.startHeartbeat()
                    self?.sendPendingMessages()
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
            return
        }
        
        guard connectionStatus != .connecting else {
            print("⚠️ Already connecting")
            return
        }
        
        if let currentUserId = currentUserId, currentUserId != userId {
            disconnect()
        }
        
        currentUserId = userId
        connectionStatus = .connecting
        lastError = nil
        
        let encodedDeviceId = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
        
        // ИСПРАВЛЯЕМ ЗДЕСЬ:
        let urlString = "\(baseURL)/ws/\(userId)?device_id=\(encodedDeviceId)"
        
        print("🔗 Connecting to WebSocket: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid WebSocket URL: \(urlString)")
            connectionStatus = .disconnected
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        listenForMessages()
        sendPing()
    }
    
    func disconnect() {
        print("🔌 Disconnecting WebSocket...")
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        connectionStatus = .disconnected
        isConnected = false
        currentUserId = nil
        
        print("✅ WebSocket disconnected")
    }
    
    func sendMessage(_ message: WebSocketMessage) {
        guard connectionStatus == .connected else {
            print("⚠️ WebSocket not connected, saving message for later")
            pendingMessages.append(message)
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
                        self?.pendingMessages.append(message)
                    } else {
                        print("✅ Message sent: \(message.type)")
                    }
                }
            }
        } catch {
            print("❌ Error encoding message: \(error)")
        }
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
                self.listenForMessages()
            case .failure(let error):
                print("❌ Error receiving message: \(error)")
                self.connectionStatus = .disconnected
                self.isConnected = false
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
            let decoder = JSONDecoder()
            
            // Используем ISO8601DateFormatter отдельно
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Сначала пробуем ISO8601 с дробными секундами
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                
                // Пробуем стандартный ISO8601
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                
                // Пробуем старые форматы как fallback
                let legacyFormatters: [DateFormatter] = [
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        return f
                    }(),
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone(secondsFromGMT: 0)
                        return f
                    }()
                ]
                
                for formatter in legacyFormatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }
            
            let message = try decoder.decode(WebSocketMessage.self, from: data)
            print("📩 Received message type: \(message.type)")
            
            if let handler = messageHandlers[message.type] {
                DispatchQueue.main.async {
                    handler(message)
                }
            } else {
                print("⚠️ No handler for message type: \(message.type)")
            }
            
        } catch {
            print("❌ Error parsing message JSON: \(error)")
            print("📄 Raw data: \(text)")
        }
    }
    
    private func handleChatMessage(_ message: WebSocketMessage) {
        guard let chatId = message.chatId,
              let senderId = message.senderId,
              let content = message.content,
              let messageId = message.messageId,
              let timestamp = message.timestamp else {
            print("❌ Invalid chat message format")
            return
        }
        
        let chatMessage = Message(
            id: messageId,
            chatId: chatId,
            senderId: senderId,
            content: content,
            type: .text,
            timestamp: timestamp,
            isEncrypted: true
        )
        
        _ = LocalDatabase.shared.saveMessage(chatMessage)
        
        NotificationCenter.default.post(
            name: .newMessageReceived,
            object: chatMessage
        )
        
        print("📩 Chat message saved: \(content.prefix(20))...")
    }
    
    // В методе handleContactRequest добавляем сохранение в локальную базу:
    private func handleContactRequest(_ message: WebSocketMessage) {
        guard let requestId = message.requestId,
              let senderId = message.senderId,
              let senderNickname = message.senderNickname,
              let senderPublicKey = message.senderPublicKey else {
            print("❌ Invalid contact request format")
            return
        }
        
        print("📩 Received contact request from: \(senderNickname) (\(senderId))")
        
        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Проверяем, что запрос не от самого себя
        guard let currentUser = AppState.shared.currentUser else {
            print("❌ Current user not found")
            return
        }
        
        if senderId == currentUser.id {
            print("⚠️ Игнорируем запрос от самого себя")
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
        
        _ = LocalDatabase.shared.saveContactRequest(request)
        
        ContactService.shared.handleIncomingContactRequest(request)
        
        print("✅ Запрос сохранен локально")
    }

    // В методе handleContactAccept:
    private func handleContactAccept(_ message: WebSocketMessage) {
        guard let acceptedUserId = message.acceptedUserId,
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
        
        // Сохраняем в локальную базу
        _ = LocalDatabase.shared.saveContact(contact)
        
        // Уведомляем ContactService
        ContactService.shared.handleContactRequestAccepted(contact)
        
        print("✅ Contact accepted from \(acceptedNickname)")
    }
    
    private func handleContactRequestSent(_ message: WebSocketMessage) {
        print("✅ Contact request sent confirmation received")
        
        DispatchQueue.main.async {
            NotificationService.shared.showInfo("Запрос на контакт отправлен")
        }
    }
    
    private func handleMessageAck(_ message: WebSocketMessage) {
        guard let messageId = message.messageId,
              let ackSenderId = message.ackSenderId else {
            return
        }
        
        print("✅ Message \(messageId) acknowledged by \(ackSenderId)")
        
        MessageService.shared.handleMessageAck(
            messageId: messageId,
            from: ackSenderId
        )
    }
    
    private func handlePong(_ message: WebSocketMessage) {
        print("❤️ Pong received")
    }
    
    private func sendPing() {
        let pingMessage = WebSocketMessage(type: "ping", timestamp: Date())
        sendMessage(pingMessage)
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectTimer == nil else { return }
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            guard let self = self,
                  let userId = self.currentUserId else {
                return
            }
            
            print("🔄 Attempting to reconnect...")
            self.connect(userId: userId)
        }
    }
    
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func sendPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        print("📤 Sending \(pendingMessages.count) pending messages...")
        
        let messages = pendingMessages
        pendingMessages.removeAll()
        
        for message in messages {
            sendMessage(message)
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession,
                   webSocketTask: URLSessionWebSocketTask,
                   didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connection opened")
        
        DispatchQueue.main.async {
            self.connectionStatus = .connected
            self.isConnected = true
            self.lastError = nil
            
            NotificationCenter.default.post(
                name: .websocketConnected,
                object: nil
            )
        }
    }
    
    func urlSession(_ session: URLSession,
                   webSocketTask: URLSessionWebSocketTask,
                   didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                   reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown"
        print("🔌 WebSocket closed with code: \(closeCode), reason: \(reasonString)")
        
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isConnected = false
            
            if closeCode != .normalClosure {
                NotificationCenter.default.post(
                    name: .websocketDisconnected,
                    object: reasonString
                )
            }
        }
    }
}
