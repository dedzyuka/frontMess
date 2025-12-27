import Foundation

class APIService {
    static let shared = APIService()
    
    let baseURL = "http://localhost:8000/api/v1"
    private let decoder = JSONDecoder.iso8601WithMilliseconds
    
    private init() {}
    
    // MARK: - User Endpoints
    
    func registerUser(nickname: String, publicKey: String, deviceId: String) async throws -> User {
        let url = URL(string: "\(baseURL)/users/register")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "nickname": nickname,
            "public_key": publicKey,
            "device_id": deviceId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            // Логирование для отладки
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("Отправляем JSON: \(jsonString)")
            }
            
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Статус код: \(httpResponse.statusCode)")
        
        // Всегда логируем ответ
        if let responseString = String(data: data, encoding: .utf8) {
            print("Ответ сервера: \(responseString)")
        }
        
        switch httpResponse.statusCode {
        case 201:
            // Используем кастомный декодер
            return try decoder.decode(User.self, from: data)
        case 400, 422:
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorDict["detail"] as? String {
                throw NSError(domain: "API", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: detail])
            } else {
                throw URLError(.badServerResponse)
            }
        default:
            throw URLError(.badServerResponse)
        }
    }
    
    func getUser(userId: UUID) async throws -> User {
        let url = URL(string: "\(baseURL)/users/\(userId.uuidString)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(User.self, from: data)
    }
    
    // MARK: - Chat Endpoints
    
    func createChat(name: String, creatorId: UUID, deviceId: String) async throws -> Chat {
        let url = URL(string: "\(baseURL)/chats/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "name": name,
            "creator_id": creatorId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Статус создания чата: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Ответ сервера: \(responseString)")
        }
        
        if httpResponse.statusCode == 201 {
            // Парсим вручную как ChatCreateResponse (а не ChatInviteResponse)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chatIdString = json["chat_id"] as? String,
                  let chatId = UUID(uuidString: chatIdString),
                  let inviteKey = json["invite_key"] as? String,
                  let createdAtString = json["created_at"] as? String else {
                throw URLError(.cannotParseResponse)
            }
            
            // Конвертируем строку в дату
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let createdAt = formatter.date(from: createdAtString) ?? Date()
            
            print("✅ Создан чат: \(name), ID: \(chatId)")
            
            return Chat(
                id: chatId,
                name: name,
                creatorId: creatorId,
                createdAt: createdAt,
                memberCount: 1
            )
        } else if httpResponse.statusCode == 400 {
            // Пробуем другой формат ответа
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                print("❌ Ошибка сервера: \(detail)")
            }
            throw URLError(.badServerResponse)
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    func getUserChats(userId: UUID, deviceId: String) async throws -> [Chat] {
        let url = URL(string: "\(baseURL)/chats/?user_id=\(userId.uuidString)")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([Chat].self, from: data)
    }
    
    // MARK: - Message Endpoints
    
    func sendMessage(chatId: UUID, content: String, deviceId: String) async throws -> Message {
        guard let userId = AppState.shared.currentUser?.id else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = URL(string: "\(baseURL)/messages/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "chat_id": chatId.uuidString,
            "sender_id": userId.uuidString,
            "content": content,
            "encrypted": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(Message.self, from: data)
    }
    
    func getChatMessages(chatId: UUID) async throws -> [Message] {
        let url = URL(string: "\(baseURL)/messages/\(chatId.uuidString)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([Message].self, from: data)
    }
    // В APIService.swift, замените метод searchUsers:

    func searchUsers(query: String, deviceId: String) async throws -> [UserPublicResponse] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(baseURL)/users/search?query=\(encodedQuery)&limit=50")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Поиск пользователей, статус: \(httpResponse.statusCode)")
        
        // Всегда логируем ответ
        if let responseString = String(data: data, encoding: .utf8) {
            print("Ответ сервера: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            // Используем существующий декодер
            return try decoder.decode([UserPublicResponse].self, from: data)
        } else {
            throw URLError(.badServerResponse)
        }
    }
    // MARK: - Chat Members Endpoints

    func getChatMembers(chatId: UUID) async throws -> [ChatMemberDetailed] {
        let url = URL(string: "\(baseURL)/chats/\(chatId.uuidString)/members/detailed")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try decoder.decode(ChatMembersResponse.self, from: data)
        return response.members
    }

    func addUserToChat(chatId: UUID, userId: UUID, deviceId: String) async throws -> Bool {
        // Будем использовать существующий endpoint /chats/{chat_id}/join
        let url = URL(string: "\(baseURL)/chats/\(chatId.uuidString)/join")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "user_id": userId.uuidString,
            "invite_key": chatId.uuidString // Используем chat_id как invite_key
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return httpResponse.statusCode == 200
    }

    // MARK: - Chat Invite Endpoint

    func inviteUserToChat(chatId: UUID, userId: UUID, deviceId: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/chats/\(chatId.uuidString)/invite")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "user_id": userId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Статус приглашения: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Ответ сервера: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json ?? [:]
        } else {
            throw URLError(.badServerResponse)
        }
    }
}
