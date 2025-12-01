// ./FrontDip/MessengerApp/Models/User/User.swift
import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let nickname: String
    let publicKey: String
    let deviceId: String
    let createdAt: String?  // Изменяем на опциональное
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case nickname
        case publicKey = "public_key"
        case deviceId = "device_id"
        case createdAt = "created_at"
    }
    
    // Кастомный инициализатор для обработки отсутствующего created_at
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)
        publicKey = try container.decode(String.self, forKey: .publicKey)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}
