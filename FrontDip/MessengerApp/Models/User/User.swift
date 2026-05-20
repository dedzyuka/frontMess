import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let nickName: String
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let bio: String?
    let isOnline: Bool
    let lastSeen: Date?
    let createdAt: Date
    let updatedAt: Date
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case nickName = "nick_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case bio
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case email
    }
    
    init(id: UUID, nickName: String, email: String?, createdAt: Date, updatedAt: Date,
         firstName: String? = nil, lastName: String? = nil, avatarUrl: String? = nil,
         bio: String? = nil, isOnline: Bool = false, lastSeen: Date? = nil) {
        self.id = id
        self.nickName = nickName
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
}
