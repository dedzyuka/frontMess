import Foundation
import CryptoKit
import Combine

class AuthViewModel: ObservableObject {
    @Published var nickname = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    
    private let cryptoService = CryptoService.shared
    private let keychainService = KeychainService.shared
    private let graphQL = GraphQLClient.shared
    
    var deviceId: String { cryptoService.generateDeviceId() }
    var canRegister: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
    
    // MARK: - Registration
    func register(nickname: String, email: String, password: String, phone: String = "") async -> Bool {
            await MainActor.run { isLoading = true; errorMessage = nil }

            let variables: [String: Any] = [
                "nickName": nickname.trimmingCharacters(in: .whitespaces),
                "email": email.trimmingCharacters(in: .whitespaces),
                "password": password,
                "phone": phone.trimmingCharacters(in: .whitespaces)
            ]

            do {
                let _: CreateUserResponse = try await graphQL.perform(
                    query: GraphQLQueries.createUser,
                    variables: variables,
                    responseType: CreateUserResponse.self
                )

                // После регистрации сразу логинимся
                let loginSuccess = await login(login: nickname, password: password)
                await MainActor.run { isLoading = false }
                return loginSuccess
            } catch {
                await MainActor.run {
                    errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                    isLoading = false
                }
                return false
            }
        }
    func login(login: String, password: String) async -> Bool {
           await MainActor.run { isLoading = true; errorMessage = nil }

           let variables: [String: Any] = ["login": login, "password": password]

           do {
               let response: LoginResponse = try await graphQL.perform(
                   query: GraphQLQueries.login,
                   variables: variables,
                   responseType: LoginResponse.self
               )

               let tokens = response.auth.tokens
               TokenManager.shared.accessToken = tokens.access_token
               TokenManager.shared.refreshToken = tokens.refresh_token

               let userData = response.auth.user
               let user = User(
                   user_id: userData.user_id,
                   nick_name: userData.nick_name,
                   first_name: nil,
                   last_name: nil,
                   middle_name: nil,
                   email: userData.email,
                   phone: nil,
                   avatar_url: nil,
                   bio: nil,
                   last_seen: nil,
                   is_online: true,
                   status: "active",
                   email_verified: false,
                   phone_verified: false,
                   is_admin: false,
                   created_at: userData.created_at,
                   updated_at: userData.updated_at
               )

               await MainActor.run {
                   AppState.shared.currentUser = user
                   AppState.shared.login()
                   isLoading = false
                   // Подключаем WebSocket
                   WebSocketService.shared.connect(userId: user.id)
               }
               return true
           } catch {
               await MainActor.run {
                   errorMessage = "Ошибка входа: \(error.localizedDescription)"
                   isLoading = false
               }
               return false
           }
       }
    
    // MARK: - Restore session
    func restoreSession() async -> Bool {
            guard let refreshToken = TokenManager.shared.refreshToken else { return false }

            let variables: [String: Any] = ["refreshToken": refreshToken]

            do {
                let response: LoginResponse = try await graphQL.perform(
                    query: GraphQLQueries.refreshToken,
                    variables: variables,
                    responseType: LoginResponse.self
                )

                TokenManager.shared.accessToken = response.auth.tokens.access_token
                TokenManager.shared.refreshToken = response.auth.tokens.refresh_token

                let userData = response.auth.user
                let user = User(
                    user_id: userData.user_id,
                    nick_name: userData.nick_name,
                    first_name: nil, last_name: nil, middle_name: nil,
                    email: userData.email, phone: nil,
                    avatar_url: nil, bio: nil,
                    last_seen: nil, is_online: true,
                    status: "active", email_verified: false, phone_verified: false,
                    is_admin: false,
                    created_at: userData.created_at, updated_at: userData.updated_at
                )

                await MainActor.run {
                    AppState.shared.currentUser = user
                    AppState.shared.login()
                    WebSocketService.shared.connect(userId: user.id)
                }
                return true
            } catch {
                print("Restore session error: \(error)")
                return false
            }
        }
    
    func autoLogin() {
        Task { await restoreSession() }
    }
    
    func logout() {
            WebSocketService.shared.disconnect()
            TokenManager.shared.clear()
            AppState.shared.logout()
        }
    
    func wipeAllData() {
        WebSocketService.shared.disconnect()
        TokenManager.shared.clear()
        keychainService.wipeAllData()
        LocalDatabase.shared.clearAllData()
        ChatKeyManager.shared.clearAllKeys()
        currentUser = nil
        nickname = ""
        email = ""
        phone = ""
        password = ""
        AppState.shared.logout()
        cryptoService.resetDeviceId()
    }
    
    func hasSavedUser() -> Bool {
        return TokenManager.shared.refreshToken != nil
    }
    
    
    @MainActor
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading { errorMessage = nil }
    }
    
    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
    
}
