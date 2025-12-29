// ./FrontDip/MessengerApp/Services/Network/ChatAPIService.swift
import Foundation

class ChatAPIService {
    static let shared = ChatAPIService()
    
    private let baseURL = "http://localhost:8000/api/v1"
    private let decoder = JSONDecoder.flexibleISO8601
    
    // Создать чат
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
            print("Ответ от сервера: \(responseString)")
        }
        
        if httpResponse.statusCode == 201 {
            return try decoder.decode(Chat.self, from: data)
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Получить чаты пользователя
    func getUserChats(userId: UUID, deviceId: String) async throws -> [Chat] {
        let url = URL(string: "\(baseURL)/chats/?user_id=\(userId.uuidString)")!
        
        var request = URLRequest(url: url)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([Chat].self, from: data)
    }
}
