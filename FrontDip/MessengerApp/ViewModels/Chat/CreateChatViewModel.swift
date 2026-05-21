import Foundation
import CryptoKit

class CreateChatViewModel: ObservableObject {
    @Published var chatName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inviteKey: String?
    @Published var showInviteSheet = false
    
    private let graphQL = GraphQLClient.shared
    private let cryptoService = CryptoService.shared
    private let keychainService = KeychainService.shared
    
    var canCreateChat: Bool {
        !chatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func createChat() async -> Bool {
        guard canCreateChat,
              let currentUser = AppState.shared.currentUser else {
            await MainActor.run { errorMessage = "Невозможно создать чат" }
            return false
        }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        let trimmedName = chatName.trimmingCharacters(in: .whitespacesAndNewlines)
        let variables: [String: Any] = [
            "chatType": "group",
            "name": trimmedName,
            "memberIds": [currentUser.id.uuidString],
            "isPublic": false
        ]
        
        do {
            let response: CreateChatResponse = try await graphQL.perform(
                query: GraphQLQueries.createChat,
                variables: variables,
                responseType: CreateChatResponse.self,
                authToken: TokenManager.shared.accessToken
            )
            
            // ✅ Исправлено: response.chat.create
            let newChat = response.chat.create
            
            // Генерация и сохранение ключа чата (опционально)
            let chatKey = cryptoService.generateSymmetricKey()
            if let publicKeyData = keychainService.loadPublicKey(userId: currentUser.id) {
                let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
                let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
                _ = keychainService.saveChatKey(encryptedChatKey, chatId: newChat.chat_id)
                let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                ChatKeyManager.shared.saveChatKey(chatKeyData, for: newChat.chat_id)
            }
            
            await MainActor.run {
                inviteKey = newChat.chat_id.uuidString
                showInviteSheet = true
                isLoading = false
                chatName = ""
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Ошибка создания чата: \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
}
