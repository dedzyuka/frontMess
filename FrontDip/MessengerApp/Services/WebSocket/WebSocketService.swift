import Foundation
import Combine

final class WebSocketService: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()

    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private var userId: UUID?
    private var accessToken: String?
    private var isManualDisconnect = false
    private var isReconnectingWithFreshToken = false

    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func connect(userId: UUID) {
        guard let token = TokenManager.shared.accessToken else {
            print("No access token for WebSocket")
            return
        }

        self.userId = userId
        self.accessToken = token
        self.isManualDisconnect = false
        connectInternal()
    }

    func reconnectWithFreshToken(userId: UUID) {
        guard let token = TokenManager.shared.accessToken else {
            print("No fresh access token for WebSocket reconnect")
            return
        }

        print("🔄 Reconnecting WebSocket with fresh token")
        self.userId = userId
        self.accessToken = token
        self.isManualDisconnect = false
        self.isReconnectingWithFreshToken = true
        self.reconnectAttempts = 0

        reconnectTimer?.invalidate()
        reconnectTimer = nil

        pingTimer?.invalidate()
        pingTimer = nil

        if let currentTask = webSocketTask {
            currentTask.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }

        session?.invalidateAndCancel()
        session = nil
        isConnected = false

        connectInternal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isReconnectingWithFreshToken = false
        }
    }

    private func connectInternal() {
        if let latestToken = TokenManager.shared.accessToken {
            accessToken = latestToken
        }

        guard let token = accessToken, userId != nil else {
            print("❌ WebSocket connect skipped: no token or userId")
            return
        }

        reconnectTimer?.invalidate()
        reconnectTimer = nil

        pingTimer?.invalidate()
        pingTimer = nil

        if let currentTask = webSocketTask {
            currentTask.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }

        session?.invalidateAndCancel()
        session = nil

        guard var components = URLComponents(url: AppConfig.websocketURL, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to build WebSocket URL components")
            return
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "access_token" }
        queryItems.append(URLQueryItem(name: "access_token", value: token))
        components.queryItems = queryItems

        guard let url = components.url else {
            print("❌ Failed to build WebSocket URL")
            return
        }

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        self.session = session

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        listenForMessages()
        startPing()
        print("WebSocket connecting...")
    }

    func disconnect() {
        isManualDisconnect = true
        isReconnectingWithFreshToken = false

        reconnectTimer?.invalidate()
        reconnectTimer = nil

        pingTimer?.invalidate()
        pingTimer = nil

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        session?.invalidateAndCancel()
        session = nil

        isConnected = false
        reconnectAttempts = 0
    }

    private func scheduleReconnect() {
        guard !isManualDisconnect else {
            print("WebSocket reconnect skipped: manual disconnect")
            return
        }

        guard !isReconnectingWithFreshToken else {
            print("WebSocket reconnect skipped: fresh-token reconnect in progress")
            return
        }

        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnect attempts reached")
            return
        }

        reconnectTimer?.invalidate()
        let delay = min(10, Double(reconnectAttempts + 1) * 2)

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.reconnectAttempts += 1
            self.accessToken = TokenManager.shared.accessToken
            self.connectInternal()
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.listenForMessages()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    NotificationCenter.default.post(name: .websocketDisconnected, object: nil)
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("📨 WebSocket string message: \(text.prefix(200))")
            processJSON(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                processJSON(text)
            } else {
                print("📨 WebSocket binary message, length: \(data.count)")
            }

        @unknown default:
            break
        }
    }

    private func processJSON(_ text: String) {
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
            let payload = json["payload"] as? [String: Any] ?? [:]
            print("📢 Received typing event: \(event), payload: \(payload)")
            handleTyping(json, event: event)

        case "message.ack":
            handleAck(json)

        case "reaction.add":
            handleReactionAdd(json)

        case "reaction.remove":
            handleReactionRemove(json)

        case "status.update":
            handleStatusUpdate(json)

        case "user.online":
            handleUserOnline(json)

        case "call.incoming":
            handleCallIncoming(json)

        case "call.updated":
            handleCallUpdated(json)

        case "call.ended":
            handleCallEnded(json)

        case "pong":
            print("Pong received")

        default:
            print("Unhandled event: \(event)")
        }
    }

    private func handleCallIncoming(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let callIdString = payload["call_id"] as? String,
              let chatIdString = payload["chat_id"] as? String,
              let initiatorIdString = payload["initiator_id"] as? String,
              let type = payload["type"] as? String,
              let startedAtString = payload["started_at"] as? String,
              let callId = UUID(uuidString: callIdString),
              let chatId = UUID(uuidString: chatIdString),
              let initiatorId = UUID(uuidString: initiatorIdString),
              let startedAt = isoDateFormatter.date(from: startedAtString) else {
            return
        }

        if initiatorId == AppState.shared.currentUser?.userId {
            print("🔇 Ignoring incoming call from self")
            return
        }

        let call = Call(
            callId: callId,
            chatId: chatId,
            initiatorId: initiatorId,
            status: "pending",
            type: type,
            startedAt: startedAt,
            endedAt: nil
        )

        DispatchQueue.main.async {
            if let existing = CallService.shared.activeCall,
               existing.callId != call.callId,
               ["pending", "active"].contains(existing.status.lowercased()) {
                print("⚠️ Ignoring call.incoming because another live call is already in memory")
                return
            }

            CallService.shared.activeCall = call
            NotificationCenter.default.post(name: .incomingCall, object: call)
        }
    }

    private func handleCallUpdated(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let callIdString = payload["call_id"] as? String,
              let status = payload["status"] as? String,
              let callId = UUID(uuidString: callIdString) else {
            return
        }

        DispatchQueue.main.async {
            let currentUserId = AppState.shared.currentUser?.userId

            if let existingCall = CallService.shared.activeCall,
               existingCall.callId == callId {
                let updatedCall = Call(
                    callId: existingCall.callId,
                    chatId: existingCall.chatId,
                    initiatorId: existingCall.initiatorId,
                    status: status,
                    type: existingCall.type,
                    startedAt: existingCall.startedAt,
                    endedAt: existingCall.endedAt
                )

                CallService.shared.activeCall = updatedCall
                NotificationCenter.default.post(name: .callStatusChanged, object: updatedCall)

                if ["ended", "declined", "missed", "completed"].contains(status.lowercased()) {
                    Task {
                        await CallService.shared.disconnect(clearActiveCall: false)
                        await MainActor.run {
                            if CallService.shared.activeCall?.callId == callId {
                                CallService.shared.activeCall = nil
                            }
                            NotificationCenter.default.post(name: .callEnded, object: callId)
                        }
                    }
                }
                return
            }

            if status.lowercased() == "pending" {
                guard let chatIdString = payload["chat_id"] as? String,
                      let initiatorIdString = payload["initiator_id"] as? String,
                      let startedAtString = payload["started_at"] as? String,
                      let chatId = UUID(uuidString: chatIdString),
                      let initiatorId = UUID(uuidString: initiatorIdString),
                      let startedAt = self.isoDateFormatter.date(from: startedAtString) else {
                    return
                }

                if initiatorId == currentUserId {
                    print("🔇 Ignoring incoming call from self (updated)")
                    return
                }

                let call = Call(
                    callId: callId,
                    chatId: chatId,
                    initiatorId: initiatorId,
                    status: status,
                    type: payload["type"] as? String ?? "video",
                    startedAt: startedAt,
                    endedAt: nil
                )

                CallService.shared.activeCall = call
                NotificationCenter.default.post(name: .incomingCall, object: call)
                return
            }

            if ["ended", "declined", "missed", "completed"].contains(status.lowercased()) {
                NotificationCenter.default.post(name: .callEnded, object: callId)
                return
            }

            print("⚠️ call.updated for unknown call \(callId) with status \(status)")
        }
    }

    private func handleCallEnded(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let callIdString = payload["call_id"] as? String,
              let callId = UUID(uuidString: callIdString) else {
            return
        }

        DispatchQueue.main.async {
            if CallService.shared.activeCall?.callId == callId {
                Task {
                    await CallService.shared.disconnect(clearActiveCall: false)
                    await MainActor.run {
                        if CallService.shared.activeCall?.callId == callId {
                            CallService.shared.activeCall = nil
                        }
                        NotificationCenter.default.post(name: .callEnded, object: callId)
                    }
                }
            } else {
                NotificationCenter.default.post(name: .callEnded, object: callId)
            }
        }
    }

    func sendCallStart(chatId: UUID, type: String = "video") {
        let envelope: [String: Any] = [
            "event": "call.start",
            "payload": [
                "chat_id": chatId.uuidString,
                "type": type
            ]
        ]
        send(envelope)
    }

    func sendCallAccept(callId: UUID) {
        let envelope: [String: Any] = [
            "event": "call.accept",
            "payload": [
                "call_id": callId.uuidString
            ]
        ]
        send(envelope)
    }

    func sendCallReject(callId: UUID) {
        let envelope: [String: Any] = [
            "event": "call.reject",
            "payload": [
                "call_id": callId.uuidString
            ]
        ]
        send(envelope)
    }

    func sendCallEnd(callId: UUID) {
        let envelope: [String: Any] = [
            "event": "call.end",
            "payload": [
                "call_id": callId.uuidString
            ]
        ]
        send(envelope)
    }

    // MARK: - Message handlers

    private func handleNewMessage(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value,
              let chatIdString = payload["chat_id"] as? String,
              let senderIdString = payload["sender_id"] as? String,
              let createdAtString = payload["created_at"] as? String,
              let createdAt = isoDateFormatter.date(from: createdAtString),
              let chatId = UUID(uuidString: chatIdString),
              let senderId = UUID(uuidString: senderIdString) else {
            print("❌ Failed to parse message.new payload")
            return
        }

        let content = payload["content"] as? String
        let replyToId = (payload["reply_to_id"] as? NSNumber)?.int64Value
        var attachments: [Attachment] = []

        if let attachmentsArray = payload["attachments"] as? [[String: Any]] {
            for attDict in attachmentsArray {
                if let attachmentIdString = attDict["attachment_id"] as? String,
                   let attachmentId = UUID(uuidString: attachmentIdString),
                   let fileName = attDict["file_name"] as? String,
                   let storagePath = attDict["storage_path"] as? String {

                    let attachment = Attachment(
                        attachmentId: attachmentId,
                        fileName: fileName,
                        fileSize: (attDict["file_size"] as? NSNumber)?.intValue,
                        mimeType: attDict["mime_type"] as? String,
                        storagePath: storagePath,
                        uploadedAt: Date(),
                        messageCreatedAt: createdAt,
                        duration: (attDict["duration"] as? NSNumber)?.intValue,
                        waveform: attDict["waveform"] as? String,
                        thumbnailUrl: attDict["thumbnail_url"] as? String,
                        isCircular: attDict["is_circular"] as? Bool
                    )

                    print("📎 New attachment from WebSocket: isCircular = \(attachment.isCircular ?? false)")
                    attachments.append(attachment)
                }
            }
        }

        let message = Message(
            messageId: messageId,
            chatId: chatId,
            senderId: senderId,
            replyToId: replyToId,
            content: content,
            type: payload["type"] as? String ?? "text",
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil,
            isEdited: false,
            deliveredAt: nil,
            readAt: nil,
            reactions: nil,
            attachments: attachments,
            forwardedFromUserId: (payload["forwarded_from_user_id"] as? String).flatMap(UUID.init),
            forwardedFromNickname: payload["forwarded_from_nickname"] as? String,
            senderNickname: payload["sender_nickname"] as? String,
            replyToSenderName: nil,
            replyToContent: nil
        )

        if !LocalDatabase.shared.messageExists(messageId) {
            print("💾 About to save message \(message.messageId), attachment isCircular = \(attachments.first?.isCircular ?? false)")
            _ = LocalDatabase.shared.saveMessage(message)
            if !attachments.isEmpty {
                _ = LocalDatabase.shared.saveAttachments(attachments, for: messageId, messageCreatedAt: createdAt)
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newMessageReceived, object: message)
        }
    }

    private func handleStatusUpdate(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value,
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

        print("📢 Posting .statusUpdated for message \(messageId), delivered = \(deliveredAt != nil), read = \(readAt != nil)")
        NotificationCenter.default.post(name: .statusUpdated, object: update)
    }

    private func handleMessageUpdate(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value,
              let chatIdString = payload["chat_id"] as? String,
              let content = payload["content"] as? String,
              let isEdited = payload["is_edited"] as? Bool,
              let chatId = UUID(uuidString: chatIdString) else {
            return
        }

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
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value,
              let chatIdString = payload["chat_id"] as? String,
              let chatId = UUID(uuidString: chatIdString) else {
            return
        }

        NotificationCenter.default.post(name: .messageDeleted, object: (messageId, chatId))
    }

    private func handleChatCreated(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let chatJSON = payload["chat"] as? [String: Any],
              let chatData = try? JSONSerialization.data(withJSONObject: chatJSON),
              let chat = try? JSONDecoder.snakeCaseDecoder.decode(Chat.self, from: chatData) else {
            return
        }

        NotificationCenter.default.post(name: .chatCreated, object: chat)
    }

    private func handleTyping(_ json: [String: Any], event: String) {
        guard let payload = json["payload"] as? [String: Any],
              let chatIdString = payload["chat_id"] as? String,
              let userIdString = payload["user_id"] as? String,
              let chatId = UUID(uuidString: chatIdString),
              let userId = UUID(uuidString: userIdString) else {
            return
        }

        let name = event == "typing.start" ? Notification.Name.typingStarted : .typingStopped
        NotificationCenter.default.post(name: name, object: nil, userInfo: [
            "chatId": chatId,
            "userId": userId
        ])
    }

    private func handleAck(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value else {
            return
        }

        NotificationCenter.default.post(name: .messageAcknowledged, object: messageId)
    }

    private func handleReactionAdd(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value,
              let userIdString = payload["user_id"] as? String,
              let emoji = payload["emoji"] as? String,
              let createdAtString = payload["created_at"] as? String,
              let userId = UUID(uuidString: userIdString) else {
            return
        }

        let createdAt = isoDateFormatter.date(from: createdAtString) ?? Date()
        let reaction = Reaction(messageId: messageId, userId: userId, emoji: emoji, createdAt: createdAt)
        _ = LocalDatabase.shared.saveReaction(reaction)
        NotificationCenter.default.post(name: .reactionAdded, object: reaction)
    }

    private func handleReactionRemove(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let messageId = (payload["message_id"] as? NSNumber)?.int64Value,
              let userIdString = payload["user_id"] as? String,
              let emoji = payload["emoji"] as? String,
              let userId = UUID(uuidString: userIdString) else {
            print("❌ Failed to parse reaction.remove payload")
            return
        }

        let deleted = LocalDatabase.shared.deleteReaction(messageId: messageId, userId: userId, emoji: emoji)
        if deleted {
            print("✅ Deleted reaction for msg \(messageId)")
        } else {
            print("⚠️ Reaction not found for deletion")
        }

        let removalInfo: [String: Any] = [
            "messageId": messageId,
            "userId": userId,
            "emoji": emoji
        ]
        NotificationCenter.default.post(name: .reactionRemoved, object: removalInfo)
    }

    private func handleUserOnline(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let userIdString = payload["user_id"] as? String,
              let isOnline = payload["is_online"] as? Bool,
              let userId = UUID(uuidString: userIdString) else {
            return
        }

        let update: [String: Any] = [
            "userId": userId,
            "is_online": isOnline
        ]
        NotificationCenter.default.post(name: .statusUpdated, object: update)
    }

    // MARK: - Sending

    func sendMessage(chatId: UUID, content: String) {
        let envelope: [String: Any] = [
            "event": "message.send",
            "payload": [
                "chat_id": chatId.uuidString,
                "content": content
            ]
        ]
        send(envelope)
    }

    func sendTyping(chatId: UUID, isTyping: Bool) {
        let event = isTyping ? "typing.start" : "typing.stop"
        let envelope: [String: Any] = [
            "event": event,
            "payload": [
                "chat_id": chatId.uuidString
            ]
        ]
        send(envelope)
    }

    func sendAck(messageId: Int64, chatId: UUID) {
        let envelope: [String: Any] = [
            "event": "message.ack",
            "payload": [
                "message_id": messageId,
                "chat_id": chatId.uuidString
            ]
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
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        webSocketTask?.send(.string(string)) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
            NotificationCenter.default.post(name: .websocketConnected, object: nil)
            print("WebSocket connected")
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        DispatchQueue.main.async {
            self.isConnected = false
            NotificationCenter.default.post(name: .websocketDisconnected, object: nil)
            print("WebSocket disconnected")
            self.scheduleReconnect()
        }
    }
}
