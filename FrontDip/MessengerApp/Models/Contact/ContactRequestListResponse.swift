
import Foundation

struct ContactRequestListResponse: Codable {
    let requests: [ContactRequestAPI]
    let total_count: Int
}

struct ContactRequestAPI: Codable {
    let id: UUID
    let from_user_id: UUID
    let from_nickname: String
    let to_user_id: UUID
    let to_nickname: String
    let status: String
    let created_at: Date
    let responded_at: Date?
}

struct ContactListResponse: Codable {
    let contacts: [ContactAPI]
    let total_count: Int
}

struct ContactAPI: Codable {
    let user_id: UUID
    let nickname: String
    let public_key: String
    let created_at: Date
}
