import Foundation
import CryptoKit
import Combine

class AuthViewModel: ObservableObject {
    @Published var nickname = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    
    private let cryptoService = CryptoService.shared
    private let keychainService = KeychainService.shared
    private let graphQL = GraphQLClient.shared
    
    var deviceId: String { cryptoService.generateDeviceId() }
    var canRegister: Bool { !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    // MARK: - Registration
    func register() async {
        guard canRegister else {
            await showError("Введите никнейм")
            return
        }
        await setLoading(true)
        
        do {
            let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let tempPassword = UUID().uuidString
            
            let (privateKey, publicKeyData) = cryptoService.generateKeyPair()
            let publicKeyPEM = cryptoService.publicKeyToPEM(publicKey: publicKeyData)
            
            // Создание пользователя
            let createVariables: [String: Any] = [
                "nickname": cleanedNickname,
                "email": "\(UUID().uuidString)@temp.com",
                "password": tempPassword,
                "phone": ""
            ]
            let _: CreateUserResponse = try await graphQL.perform(
                query: GraphQLQueries.createUser,
                variables: createVariables,
                responseType: CreateUserResponse.self
            )
            
            // Логин для получения токенов
            let loginVariables: [String: Any] = [
                "login": cleanedNickname,
                "password": tempPassword
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
              let userIdUUID = userData.userId  // UUID
              let user = User(
                  id: userData.userId,
                  nickName: userData.nickName,
                  email: userData.email,
                  createdAt: userData.createdAt,
                  updatedAt: userData.updatedAt
              )
              
              keychainService.savePrivateKey(privateKey, userId: userIdUUID)
              keychainService.savePublicKey(publicKeyData, userId: userIdUUID)
              keychainService.save(key: "user_id", value: userIdUUID.uuidString)
              
              await MainActor.run {
                  self.currentUser = user
                  AppState.shared.currentUser = user
                  AppState.shared.login()
                  self.isLoading = false
                  
                  DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                      WebSocketService.shared.connect(userId: userIdUUID)
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
            let response: RefreshTokenResponse = try await graphQL.perform(
                query: GraphQLQueries.refreshToken,
                variables: variables,
                responseType: RefreshTokenResponse.self
            )
            
            TokenManager.shared.accessToken = response.auth.tokens.access_token
            TokenManager.shared.refreshToken = response.auth.tokens.refresh_token
            
            let userData = response.auth.user
            let user = User(
                id: userData.userId,
                nickName: userData.nickName,
                email: userData.email,
                createdAt: userData.createdAt,
                updatedAt: userData.updatedAt
            )
            
            await MainActor.run {
                self.currentUser = user
                AppState.shared.currentUser = user
                AppState.shared.login()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    WebSocketService.shared.connect(userId: userData.userId)
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

struct RefreshTokenResponse: Decodable {
    let auth: AuthLoginResult
}
