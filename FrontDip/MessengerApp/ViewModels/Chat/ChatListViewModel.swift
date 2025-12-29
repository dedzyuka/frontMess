// ./FrontDip/MessengerApp/ViewModels/Chat/ChatListViewModel.swift
import Foundation
import Combine
import CryptoKit

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
        @Published var isLoading = false
        @Published var errorMessage: String?
        @Published var showingCreateChat = false
        
    
    var currentUser: User? {
            return AppState.shared.currentUser
        }
    
    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared
    
    var deviceId: String? {
            return KeychainService.shared.loadDeviceId()
        }
    
    func loadChats() async {
        // Сначала показываем локальные чаты
        let localChats = LocalDatabase.shared.getChats()
        
        guard let userId = AppState.shared.currentUser?.id,
                      let deviceId = deviceId else {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
        }
        
        do {
            print("📡 Загружаем чаты с сервера...")
            let serverChats = try await apiService.getUserChats(
                userId: userId,
                deviceId: deviceId
            )
            
            print("✅ Получено \(serverChats.count) чатов с сервера")
            
            // Сохраняем каждый чат в локальную базу
            for chat in serverChats {
                _ = LocalDatabase.shared.saveOrUpdateChat(chat)
            }
            
            // Восстанавливаем ключи
            await restoreChatKeys(for: serverChats, userId: userId)
            
            await MainActor.run {
                chats = serverChats
                isLoading = false
                print("✅ Всего чатов: \(chats.count)")
            }
            
        } catch {
            print("❌ Ошибка загрузки чатов: \(error)")
            
            await MainActor.run {
                isLoading = false
                if localChats.isEmpty {
                    errorMessage = "Нет доступных чатов"
                }
            }
        }
    }
    
    // В ChatListViewModel.swift
    private func restoreChatKeys(for chats: [Chat], userId: UUID) async {
        for chat in chats {
            // Проверяем, есть ли ключ чата в Keychain
            if let encryptedChatKeyData = keychainService.loadChatKey(chatId: chat.id) {
                do {
                    print("🔄 Восстановление ключа для чата \(chat.name)...")
                    
                    // Получаем наш приватный ключ (Data)
                    guard let privateKeyData = keychainService.loadPrivateKey(userId: userId) else {
                        print("❌ Нет приватного ключа для чата \(chat.name)")
                        continue
                    }
                    
                    // 🔥 ИСПРАВЛЕНИЕ: Преобразуем Data в PrivateKey
                    let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
                    let cryptoService = CryptoService.shared
                    
                    // Расшифровываем ключ чата
                    let chatKey = try cryptoService.decryptSymmetricKey(
                        encryptedChatKeyData,
                        with: privateKey
                    )
                    let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                    
                    // Сохраняем в менеджер ключей
                    ChatKeyManager.shared.saveChatKey(chatKeyData, for: chat.id)
                    
                    print("✅ Ключ восстановлен для чата: \(chat.name)")
                    
                } catch let keyError as CryptoKit.CryptoKitError {
                    print("❌ Ошибка CryptoKit: \(keyError)")
                } catch {
                    print("❌ Ошибка восстановления ключа для чата \(chat.name): \(error)")
                }
            } else {
                print("⚠️ Ключ не найден для чата: \(chat.name)")
                
                // 🔥 ДОБАВЛЯЕМ: Автоматически создаем ключ, если его нет
                await createChatKeyIfNeeded(chat: chat, userId: userId)
            }
        }
    }

    private func createChatKeyIfNeeded(chat: Chat, userId: UUID) async {
        print("🔑 Создаем новый ключ для чата: \(chat.name)")
        
        do {
            let cryptoService = CryptoService.shared
            let keychainService = KeychainService.shared
            
            // 1. Генерируем симметричный ключ для чата
            let chatKey = cryptoService.generateSymmetricKey()
            
            // 2. Получаем наш публичный ключ
            guard let publicKeyData = keychainService.loadPublicKey(userId: userId) else {
                print("❌ Публичный ключ не найден для создания ключа чата")
                return
            }
            
            let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
            
            // 3. Шифруем симметричный ключ нашим публичным ключом
            let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
            
            // 4. Сохраняем зашифрованный ключ в Keychain
            _ = keychainService.saveChatKey(encryptedChatKey, chatId: chat.id)
            
            // 5. Сохраняем симметричный ключ в памяти
            let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
            ChatKeyManager.shared.saveChatKey(chatKeyData, for: chat.id)
            
            print("✅ Ключ создан и сохранен для чата: \(chat.name)")
            
        } catch {
            print("❌ Ошибка создания ключа чата: \(error)")
        }
    }
}
