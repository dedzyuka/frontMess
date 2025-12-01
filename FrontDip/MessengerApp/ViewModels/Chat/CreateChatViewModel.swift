
import Foundation
import Combine
import CryptoKit

class CreateChatViewModel: ObservableObject {
    @Published var chatName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inviteKey: String?
    @Published var showInviteSheet = false
    
    private let apiService = APIService.shared
    private let cryptoService = CryptoService.shared
    private let keychainService = KeychainService.shared
    
    var canCreateChat: Bool {
        !chatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func createChat() async -> Bool {
        guard canCreateChat,
              let userId = AppState.shared.currentUser?.id,
              let deviceId = keychainService.loadDeviceId() else {
            await MainActor.run {
                errorMessage = "Невозможно создать чат"
            }
            return false
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 1. Создаем чат на сервере
            let chat = try await apiService.createChat(
                name: chatName.trimmingCharacters(in: .whitespacesAndNewlines),
                creatorId: userId,
                deviceId: deviceId
            )
            
            // 2. Генерируем симметричный ключ для чата
            let chatKey = cryptoService.generateSymmetricKey()
            
            // 3. Получаем наш публичный ключ
            guard let publicKeyData = keychainService.loadPublicKey(userId: userId) else {
                throw NSError(domain: "ChatError", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Публичный ключ не найден"])
            }
            
            let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
            
            // 4. Шифруем симметричный ключ нашим публичным ключом
            let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
            
            // 5. Сохраняем зашифрованный ключ в Keychain
            _ = keychainService.saveChatKey(encryptedChatKey, chatId: chat.id)
            
            // 6. Сохраняем симметричный ключ в памяти (для текущей сессии)
            let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
            ChatKeyManager.shared.saveChatKey(chatKeyData, for: chat.id)
            
            await MainActor.run {
                inviteKey = chat.id.uuidString
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

