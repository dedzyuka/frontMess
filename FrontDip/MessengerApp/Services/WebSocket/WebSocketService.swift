import Foundation
import Combine

class WebSocketService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    @Published var isConnected = false
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    
    func connect(userId: UUID) {
        guard let token = TokenManager.shared.accessToken else {
            print("No access token for WebSocket")
            return
        }
        connect(accessToken: token, userId: userId)
    }
    
    func connect(accessToken: String, userId: UUID) {
        let urlString = "ws://localhost:8000/ws/chat?access_token=\(accessToken)"
        guard let url = URL(string: urlString) else { return }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        listenForMessages()
        startPing()
        print("WebSocket connecting...")
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
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
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            processJSON(text)
        default: break
        }
    }
    
    // WebSocketService.swift
    private func processJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }
        
        switch event {
        case "message.new":
            if let payload = json["payload"] as? [String: Any],
               let messageId = payload["message_id"] as? Int64,
               let chatIdString = payload["chat_id"] as? String,
               let senderIdString = payload["sender_id"] as? String,
               let content = payload["content"] as? String,
               let createdAtString = payload["created_at"] as? String,
               let createdAt = ISO8601DateFormatter().date(from: createdAtString) {
                
                // Преобразуем строки в UUID
                guard let chatId = UUID(uuidString: chatIdString),
                      let senderId = UUID(uuidString: senderIdString) else {
                    print("Invalid UUID in message payload")
                    return
                }
                
                let message = Message(
                    message_id: messageId,
                    chat_id: chatId,
                    sender_id: senderId,
                    reply_to_id: nil,
                    content: content,
                    type: "text",
                    created_at: createdAt,
                    updated_at: createdAt,
                    deleted_at: nil,
                    is_edited: false
                )
                NotificationCenter.default.post(name: .newMessageReceived, object: message)
            }
        case "message.ack":
            // обработать подтверждение при необходимости
            break
        case "pong":
            print("Pong received")
        default:
            print("Unhandled event: \(event)")
        }
    }
    
    func sendMessage(_ message: WebSocketMessage) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                let envelope: [String: Any] = ["event": "message", "payload": jsonString]
                send(envelope)
            }
        } catch {
            print("Error encoding WebSocketMessage: \(error)")
        }
    }
    
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
    
    private func startPing() {
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
            NotificationCenter.default.post(name: .websocketConnected, object: nil)
            print("WebSocket connected")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            NotificationCenter.default.post(name: .websocketDisconnected, object: nil)
            print("WebSocket disconnected")
        }
    }
    func sendContactRequest(to userId: String) {
        let envelope: [String: Any] = [
            "event": "contact.request",
            "payload": ["contact_user_id": userId]
        ]
        send(envelope)
    }
}
