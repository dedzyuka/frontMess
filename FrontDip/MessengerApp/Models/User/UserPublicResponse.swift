
import Foundation

struct UserPublicResponse: Identifiable, Codable {
    var id: UUID { user_id }
    let user_id: UUID
    let nickname: String
    let public_key: String
}
