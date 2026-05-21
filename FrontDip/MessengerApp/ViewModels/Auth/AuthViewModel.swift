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
            // Ожидаем правильный тип ответа
            let _: CreateUserResponse = try await graphQL.perform(
                query: GraphQLQueries.createUser,
                variables: variables,
                responseType: CreateUserResponse.self,
                authToken: nil
            )
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
    
    // MARK: - Login
    func login(login: String, password: String) async -> Bool {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        let variables: [String: Any] = ["login": login, "password": password]
        
        do {
            let response: LoginResponse = try await graphQL.perform(
                query: GraphQLQueries.login,
                variables: variables,
                responseType: LoginResponse.self,
                authToken: nil
            )
            let loginResult = response.auth.login
            let accessToken = loginResult.accessToken
            let refreshToken = loginResult.refreshToken
            let userData = loginResult.user
            
            await MainActor.run {
                TokenManager.shared.accessToken = accessToken
                TokenManager.shared.refreshToken = refreshToken
                
                let user = User(
                    userId: userData.userId,
                    nickName: userData.nickName,
                    firstName: nil, lastName: nil, middleName: nil,
                    email: userData.email,
                    phone: nil,
                    avatarUrl: userData.avatarUrl,
                    bio: nil,
                    lastSeen: nil,
                    isOnline: userData.isOnline,
                    status: "active",
                    emailVerified: false,
                    phoneVerified: false,
                    isAdmin: false,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                AppState.shared.currentUser = user
                AppState.shared.login()
                self.isLoading = false
                
                WebSocketService.shared.connect(userId: user.id)
                ContactService.shared.loadContacts()
                ContactService.shared.loadPendingRequests()
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
        guard let refreshToken = TokenManager.shared.refreshToken else {
            print("No refresh token to restore session")
            return false
        }

        let variables: [String: Any] = ["refreshToken": refreshToken]

        do {
            let response: RefreshResponse = try await graphQL.perform(
                query: GraphQLQueries.refreshToken,
                variables: variables,
                responseType: RefreshResponse.self,
                authToken: nil
            )

            let refreshResult = response.auth.refreshToken
            let newAccessToken = refreshResult.accessToken
            let newRefreshToken = refreshResult.refreshToken
            let userData = refreshResult.user

            print("✅ Session restored, new access token: \(newAccessToken.prefix(20))...")

            await MainActor.run {
                TokenManager.shared.accessToken = newAccessToken
                TokenManager.shared.refreshToken = newRefreshToken

                let user = User(
                    userId: userData.userId,
                    nickName: userData.nickName,
                    firstName: nil,
                    lastName: nil,
                    middleName: nil,
                    email: userData.email,
                    phone: nil,
                    avatarUrl: userData.avatarUrl,
                    bio: nil,
                    lastSeen: nil,
                    isOnline: userData.isOnline,
                    status: "active",
                    emailVerified: false,
                    phoneVerified: false,
                    isAdmin: false,
                    createdAt: Date(),
                    updatedAt: Date()
                )

                AppState.shared.currentUser = user
                AppState.shared.login()
                WebSocketService.shared.connect(userId: user.id)

                ContactService.shared.loadContacts()
                ContactService.shared.loadPendingRequests()
            }
            return true
        } catch {
            print("Failed to restore session: \(error)")
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
}
