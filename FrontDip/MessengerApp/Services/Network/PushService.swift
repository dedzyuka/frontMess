import Foundation

class PushService {
    static let shared = PushService()
    
    func registerVoIPToken(_ token: String) async -> Bool {
        let url = URL(string: AppConfig.baseURL + "/push/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken = TokenManager.shared.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = ["device_token": token, "device_type": "ios"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            print("Push registration error: \(error)")
        }
        return false
    }
}
