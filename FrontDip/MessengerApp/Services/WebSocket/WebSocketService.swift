// WebSocketService.swift (полностью переработан)
import Foundation
import Combine

class WebSocketService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    @Published var isConnected = false
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    
    private var userId: UUID?
    private var accessToken: String?
    
    // Добавить статический форматтер в класс WebSocketService (внутри класса, до методов)
    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // Заменить handleStatusUpdate
    private func handleStatusUpdate(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64,
              let userIdString = payload["user_id"] as? String,
              let chatIdString = payload["chat_id"] as? String,
              let chatId = UUID(uuidString: chatIdString),
              let userId = UUID(uuidString: userIdString) else {
            print("❌ Failed to parse status.update payload")
            return
        }
        
        let deliveredAt = (payload["delivered_at"] as? String).flatMap { isoDateFormatter.date(from: $0) }
        let readAt = (payload["read_at"] as? String).flatMap { isoDateFormatter.date(from: $0) }
        
        let update: [String: Any] = [
            "messageId": messageId,
            "chatId": chatId,
            "userId": userId,
            "deliveredAt": deliveredAt as Any,
            "readAt": readAt as Any
        ]
        print("📢 Posting .statusUpdated for message \(messageId), delivered=\(deliveredAt != nil), read=\(readAt != nil)")
        NotificationCenter.default.post(name: .statusUpdated, object: update)
    }

    // Заменить handleNewMessage – добавить принудительный вызов в главном потоке и логирование
    private func handleNewMessage(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64,
              let chatIdString = payload["chat_id"] as? String,
              let senderIdString = payload["sender_id"] as? String,
              let content = payload["content"] as? String,
              let createdAtString = payload["created_at"] as? String,
              let createdAt = isoDateFormatter.date(from: createdAtString) else {
            print("❌ Failed to parse message.new payload")
            return
        }
        guard let chatId = UUID(uuidString: chatIdString),
              let senderId = UUID(uuidString: senderIdString) else {
            print("❌ Invalid UUID in message.new")
            return
        }

        let message = Message(
            messageId: messageId, chatId: chatId, senderId: senderId,
            replyToId: nil, content: content, type: "text",
            createdAt: createdAt, updatedAt: createdAt, deletedAt: nil,
            isEdited: false, deliveredAt: nil, readAt: nil
        )
        
        // Сохраняем в локальную БД
        if !LocalDatabase.shared.messageExists(messageId) {
            _ = LocalDatabase.shared.saveMessage(message)
            print("💾 WebSocket: saved message \(messageId) to DB")
        }
        
        DispatchQueue.main.async {
            print("📢 Posting .newMessageReceived for message \(messageId) in chat \(chatId)")
            NotificationCenter.default.post(name: .newMessageReceived, object: message)
        }
    }

    // Улучшить handleMessage для обработки бинарных сообщений
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("📨 WebSocket string message: \(text.prefix(200))")
            processJSON(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                print("📨 WebSocket data as string: \(text.prefix(200))")
                processJSON(text)
            } else {
                print("📨 WebSocket binary message, length: \(data.count)")
            }
        @unknown default:
            break
        }
    }
    
    func connect(userId: UUID) {
        guard let token = TokenManager.shared.accessToken else {
            print("No access token for WebSocket")
            return
        }
        self.userId = userId
        self.accessToken = token
        connectInternal()
    }
    
    private func connectInternal() {
        guard let token = accessToken, let userId = userId else { return }
        let urlString = "\(AppConfig.websocketURL.absoluteString)?access_token=\(token)"
        guard let url = URL(string: urlString) else { return }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        listenForMessages()
        startPing()
        print("WebSocket connecting...")
    }
    
    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        reconnectAttempts = 0
    }
    
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnect attempts reached")
            return
        }
        let delay = min(10, Double(reconnectAttempts + 1) * 2)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.reconnectAttempts += 1
            self?.connectInternal()
        }
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.listenForMessages()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.scheduleReconnect()
                }
            }
        }
    }
    

    
    private func processJSON(_ text: String) {
        print("📨 WebSocket raw message: \(text)")
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else {
            print("❌ Failed to parse WebSocket message")
            return
        }
        print("✅ WebSocket event: \(event)")
        
        switch event {
        case "message.new":
            handleNewMessage(json)
        case "message.update":
            handleMessageUpdate(json)
        case "message.delete":
            handleMessageDelete(json)
        case "chat.created":
            handleChatCreated(json)
        case "typing.start", "typing.stop":
            handleTyping(json, event: event)
        case "message.ack":
            handleAck(json)
        case "reaction.add":
            handleReactionAdd(json)
        case "reaction.remove":
            handleReactionRemove(json)
        case "status.update":
            handleStatusUpdate(json)
        case "pong":
            print("Pong received")
        default:
            print("Unhandled event: \(event)")
        }
    }
    
    // MARK: - Обработчики событий
    
    
    
    private func handleMessageUpdate(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64,
              let chatIdString = payload["chat_id"] as? String,
              let content = payload["content"] as? String,
              let isEdited = payload["is_edited"] as? Bool,
              let chatId = UUID(uuidString: chatIdString) else { return }
        
        let updateInfo: [String: Any] = [
            "messageId": messageId,
            "chatId": chatId,
            "content": content,
            "isEdited": isEdited
        ]
        NotificationCenter.default.post(name: .messageUpdated, object: updateInfo)
    }
    
    private func handleMessageDelete(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64,
              let chatIdString = payload["chat_id"] as? String,
              let chatId = UUID(uuidString: chatIdString) else { return }
        NotificationCenter.default.post(name: .messageDeleted, object: (messageId, chatId))
    }
    
    private func handleChatCreated(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let chatJSON = payload["chat"] as? [String: Any],
              let chatData = try? JSONSerialization.data(withJSONObject: chatJSON),
              let chat = try? JSONDecoder.snakeCaseDecoder.decode(Chat.self, from: chatData) else { return }
        NotificationCenter.default.post(name: .chatCreated, object: chat)
    }
    
    private func handleTyping(_ json: [String: Any], event: String) {
        guard let payload = json["payload"] as? [String: Any],
              let chatIdString = payload["chat_id"] as? String,
              let userIdString = payload["user_id"] as? String,
              let chatId = UUID(uuidString: chatIdString),
              let userId = UUID(uuidString: userIdString) else { return }
        let name = event == "typing.start" ? Notification.Name.typingStarted : .typingStopped
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["chatId": chatId, "userId": userId])
    }
    
    private func handleAck(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64 else { return }
        NotificationCenter.default.post(name: .messageAcknowledged, object: messageId)
    }
    
    private func handleReactionAdd(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64,
              let userIdString = payload["user_id"] as? String,
              let emoji = payload["emoji"] as? String,
              let createdAtString = payload["created_at"] as? String else { return }
        guard let userId = UUID(uuidString: userIdString) else { return }
        let reaction = Reaction(
            messageId: messageId,
            userId: userId,
            emoji: emoji,
            createdAt: ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        )
        NotificationCenter.default.post(name: .reactionAdded, object: reaction)
    }
    
    private func handleReactionRemove(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = payload["message_id"] as? Int64,
              let userIdString = payload["user_id"] as? String,
              let emoji = payload["emoji"] as? String else { return }
        guard let userId = UUID(uuidString: userIdString) else { return }
        let removalInfo: [String: Any] = ["messageId": messageId, "userId": userId, "emoji": emoji]
        NotificationCenter.default.post(name: .reactionRemoved, object: removalInfo)
    }
    
    
    
    // MARK: - Отправка сообщений
    
    func sendMessage(chatId: UUID, content: String) {
        let envelope: [String: Any] = [
            "event": "message.send",
            "payload": ["chat_id": chatId.uuidString, "content": content]
        ]
        send(envelope)
    }
    
    func sendTyping(chatId: UUID, isTyping: Bool) {
        let event = isTyping ? "typing.start" : "typing.stop"
        let envelope: [String: Any] = ["event": event, "payload": ["chat_id": chatId.uuidString]]
        send(envelope)
    }
    
    func sendAck(messageId: Int64, chatId: UUID) {
        let envelope: [String: Any] = [
            "event": "message.ack",
            "payload": ["message_id": messageId, "chat_id": chatId.uuidString]
        ]
        send(envelope)
    }
    
    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.send(["event": "ping"])
        }
    }
    
    private func send(_ envelope: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: envelope),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(string)) { error in
            if let error = error { print("Send error: \(error)") }
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
            self.reconnectTimer?.invalidate()
            NotificationCenter.default.post(name: .websocketConnected, object: nil)
            print("WebSocket connected")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            NotificationCenter.default.post(name: .websocketDisconnected, object: nil)
            print("WebSocket disconnected")
            self.scheduleReconnect()
        }
    }
}
