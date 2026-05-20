import Foundation

class TokenManager {
    static let shared = TokenManager()
    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: accessKey) }
        set { UserDefaults.standard.set(newValue, forKey: accessKey) }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshKey) }
        set { UserDefaults.standard.set(newValue, forKey: refreshKey) }
    }
    
    func clear() {
        accessToken = nil
        refreshToken = nil
    }
}
