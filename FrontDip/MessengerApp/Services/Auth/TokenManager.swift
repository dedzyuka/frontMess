import Foundation

final class TokenManager {
    static let shared = TokenManager()

    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"
    private let expiresAtKey = "access_token_expires_at"

    private init() {}

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

    var accessTokenExpiresAt: Date? {
        get {
            UserDefaults.standard.object(forKey: expiresAtKey) as? Date
        }
        set {
            print("🔑 TokenManager set accessTokenExpiresAt: \(String(describing: newValue))")
            UserDefaults.standard.set(newValue, forKey: expiresAtKey)
        }
    }

    var isAccessTokenExpired: Bool {
        guard let expiresAt = accessTokenExpiresAt else { return true }
        return Date() >= expiresAt
    }

    func saveSession(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        print("🔑 Session saved. Expires in: \(expiresIn) sec")
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        accessTokenExpiresAt = nil
        print("🔑 TokenManager cleared")
    }
}
