import Foundation
import CryptoKit
import Combine

class CreateChatViewModel: ObservableObject {
    @Published var chatName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inviteKey: String?
    @Published var showInviteSheet = false
    
    private let client = GraphQLClient.shared
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
        
        do {
            let input: [String: Any] = [
                "name": chatName.trimmingCharacters(in: .whitespacesAndNewlines),
                "member_ids": [currentUser.id.uuidString]
            ]
            let variables: [String: Any] = ["input": input]
            let response: CreateChatResponse = try await client.perform(
                query: GraphQLQueries.createChat,
                variables: variables,
                responseType: CreateChatResponse.self
            )
            
            let newChat = response.createChat
            
            // Генерация и сохранение ключа чата
            let chatKey = cryptoService.generateSymmetricKey()
            guard let publicKeyData = keychainService.loadPublicKey(userId: currentUser.id) else {
                throw NSError(domain: "ChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Публичный ключ не найден"])
            }
            let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
            let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
            _ = keychainService.saveChatKey(encryptedChatKey, chatId: newChat.chatId)
            let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
            ChatKeyManager.shared.saveChatKey(chatKeyData, for: newChat.chatId)
            
            await MainActor.run {
                inviteKey = newChat.chatId.uuidString
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

// Response model
struct CreateChatResponse: Decodable {
    let createChat: CreatedChat
}
struct CreatedChat: Decodable {
    let chatId: UUID
    let name: String?
    let membersCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case name
        case membersCount = "members_count"
        case createdAt = "created_at"
    }
}
