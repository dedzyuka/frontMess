
import Foundation

struct AppConstants {
    static let baseURL = "http://localhost:8000/api/v1"
    static let deviceIdKey = "messenger_device_id"
    static let userIdKey = "messenger_user_id"
    
    struct API {
        static let users = "/users"
        static let chats = "/chats"
        static let messages = "/messages"
    }
}
