// ./FrontDip/MessengerApp/Services/Network/APIService.swift
import Foundation


class APIService {
    static let shared = APIService()
    
    let baseURL = "http://localhost:8000/api/v1"
    
    private init() {}
    
    // MARK: - Custom JSONDecoder
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Пробуем разные форматы дат
            let formatters: [DateFormatter] = [
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.timeZone = TimeZone(secondsFromGMT: 0)
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
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
            
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        
        return decoder
    }
    
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
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 201 {
            return try decoder.decode(User.self, from: data)
        } else {
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
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(Chat.self, from: data)
    }
    
    func getUserChats(userId: UUID, deviceId: String) async throws -> [Chat] {
        let url = URL(string: "\(baseURL)/chats/?user_id=\(userId.uuidString)")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([Chat].self, from: data)
    }
    
    // MARK: - Search Users
    
    func searchUsers(query: String, deviceId: String) async throws -> [UserPublicResponse] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(baseURL)/users/search?query=\(encodedQuery)&limit=50")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([UserPublicResponse].self, from: data)
    }
    
    // MARK: - Chat Members
    
    func getChatMembers(chatId: UUID) async throws -> [ChatMemberDetailed] {
        let url = URL(string: "\(baseURL)/chats/\(chatId.uuidString)/members/detailed")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try decoder.decode(ChatMembersResponse.self, from: data)
        return response.members
    }
    
    func inviteUserToChat(chatId: UUID, userId: UUID, deviceId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/chats/\(chatId.uuidString)/invite")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let body: [String: Any] = [
            "user_id": userId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return httpResponse.statusCode == 200
    }
}
