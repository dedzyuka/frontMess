import Foundation
class TokenManager {
    static let shared = TokenManager()
    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"
    
    var accessToken: String? {
        get {
            let token = UserDefaults.standard.string(forKey: accessKey)
            print("🔑 TokenManager get accessToken: \(token?.prefix(20) ?? "nil")")
            return token
        }
        set {
            print("🔑 TokenManager set accessToken: \(newValue?.prefix(20) ?? "nil")")
            UserDefaults.standard.set(newValue, forKey: accessKey)
        }
    }
    
    var refreshToken: String? {
        get {
            let token = UserDefaults.standard.string(forKey: refreshKey)
            print("🔑 TokenManager get refreshToken: \(token?.prefix(20) ?? "nil")")
            return token
        }
        set {
            print("🔑 TokenManager set refreshToken: \(newValue?.prefix(20) ?? "nil")")
            UserDefaults.standard.set(newValue, forKey: refreshKey)
        }
    }
    
    func clear() {
        accessToken = nil
        refreshToken = nil
        print("🔑 TokenManager cleared")
    }
}
