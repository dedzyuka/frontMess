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
    func register() async {
        guard canRegister else {
            await showError("Заполните никнейм, email и пароль")
            return
        }
        await setLoading(true)
        
        do {
            let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Генерация ключей (для будущего E2EE)
            let (privateKey, publicKeyData) = cryptoService.generateKeyPair()
            
            // Создание пользователя через GraphQL
            let variables: [String: Any] = [
                "nickName": cleanedNickname,
                "email": cleanedEmail,
                "password": password,
                "phone": cleanedPhone
            ]
            let _: CreateUserResponse = try await graphQL.perform(
                query: GraphQLQueries.createUser,
                variables: variables,
                responseType: CreateUserResponse.self
            )
            
            // Логин для получения токенов
            let loginVariables: [String: Any] = [
                "login": cleanedNickname,
                "password": password
            ]
            let loginResponse: LoginResponse = try await graphQL.perform(
                query: GraphQLQueries.login,
                variables: loginVariables,
                responseType: LoginResponse.self
            )
            
            // Сохраняем токены
            TokenManager.shared.accessToken = loginResponse.auth.tokens.access_token
            TokenManager.shared.refreshToken = loginResponse.auth.tokens.refresh_token
            
            let userData = loginResponse.auth.user
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
                is_online: false,
                status: "active",
                email_verified: false,
                phone_verified: false,
                is_admin: false,
                created_at: userData.created_at,
                updated_at: userData.updated_at
            )
            
            // Сохраняем ключи в Keychain
            keychainService.savePrivateKey(privateKey, userId: user.id)
            keychainService.savePublicKey(publicKeyData, userId: user.id)
            keychainService.save(key: "user_id", value: user.id.uuidString)
            
            await MainActor.run {
                self.currentUser = user
                AppState.shared.currentUser = user
                AppState.shared.login()
                self.isLoading = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    WebSocketService.shared.connect(userId: user.id)
                }
            }
        } catch {
            await showError("Ошибка регистрации: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Restore session
    func restoreSession() async {
        guard let refreshToken = TokenManager.shared.refreshToken else { return }
        
        do {
            let variables: [String: Any] = ["refreshToken": refreshToken]
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
                first_name: nil,
                last_name: nil,
                middle_name: nil,
                email: userData.email,
                phone: nil,
                avatar_url: nil,
                bio: nil,
                last_seen: nil,
                is_online: false,
                status: "active",
                email_verified: false,
                phone_verified: false,
                is_admin: false,
                created_at: userData.created_at,
                updated_at: userData.updated_at
            )
            
            await MainActor.run {
                self.currentUser = user
                AppState.shared.currentUser = user
                AppState.shared.login()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    WebSocketService.shared.connect(userId: user.id)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    ContactService.shared.syncContacts()
                    ContactService.shared.syncPendingRequests()
                }
            }
        } catch {
            print("Ошибка восстановления сессии: \(error)")
            TokenManager.shared.clear()
        }
    }
    
    func autoLogin() {
        Task { await restoreSession() }
    }
    
    func logout() {
        WebSocketService.shared.disconnect()
        TokenManager.shared.clear()
        currentUser = nil
        nickname = ""
        email = ""
        phone = ""
        password = ""
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
        return TokenManager.shared.refreshToken != nil && keychainService.loadDeviceId() != nil
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
