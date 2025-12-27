// ./FrontDip/MessengerApp/ViewModels/Chat/ChatListViewModel.swift
import Foundation
import Combine
import CryptoKit

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateChat = false
    
    // Сделаем currentUser публичным для установки извне
    var currentUser: User? {
        didSet {
            print("ChatListViewModel: текущий пользователь обновлен: \(currentUser?.nickname ?? "nil")")
        }
    }
    
    private let apiService = APIService.shared
    private let keychainService = KeychainService.shared
    
    var deviceId: String? {
        keychainService.loadDeviceId()
    }
    
    func loadChats() async {
        // 1. Сначала показываем чаты из локальной базы
        let localChats = LocalDatabase.shared.getChats()
        LocalDatabase.shared.printDatabaseInfo()
        
        await MainActor.run {
            self.chats = localChats
            self.isLoading = true
        }
        
        guard let userId = currentUser?.id,
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
                // Обновляем список чатов
                chats = serverChats
                isLoading = false
                print("✅ Всего чатов: \(chats.count)")
            }
            
        } catch {
            print("❌ Ошибка загрузки чатов: \(error)")
            
            // Если сервер недоступен, показываем локальные чаты
            await MainActor.run {
                isLoading = false
                if localChats.isEmpty {
                    errorMessage = "Нет доступных чатов. Проверьте подключение к серверу."
                }
            }
        }
    }
    
    // Добавьте метод восстановления ключей
    private func restoreChatKeys(for chats: [Chat], userId: UUID) async {
        for chat in chats {
            // Проверяем, есть ли ключ чата в Keychain
            if let encryptedChatKeyData = keychainService.loadChatKey(chatId: chat.id) {
                do {
                    print("🔄 Восстановление ключа для чата \(chat.name)...")
                    print("🔐 Зашифрованный ключ размером: \(encryptedChatKeyData.count) байт")
                    
                    // Получаем наш приватный ключ
                    guard let privateKeyData = keychainService.loadPrivateKey(userId: userId) else {
                        print("❌ Нет приватного ключа для чата \(chat.name)")
                        continue
                    }
                    
                    print("🔑 Приватный ключ размером: \(privateKeyData.count) байт")
                    
                    // Проверяем размеры данных
                    if privateKeyData.count != 32 {
                        print("⚠️ Неправильный размер приватного ключа: \(privateKeyData.count)")
                        continue
                    }
                    
                    let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
                    let cryptoService = CryptoService.shared
                    
                    // Расшифровываем ключ чата
                    let chatKey = try cryptoService.decryptSymmetricKey(encryptedChatKeyData, with: privateKey)
                    let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                    
                    // Сохраняем в менеджер ключей
                    ChatKeyManager.shared.saveChatKey(chatKeyData, for: chat.id)
                    
                    print("✅ Ключ восстановлен для чата: \(chat.name)")
                    
                } catch {
                    print("❌ Ошибка восстановления ключа для чата \(chat.name): \(error)")
                    print("🔍 Пробуем удалить поврежденный ключ...")
                    _ = keychainService.deleteChatKey(chatId: chat.id)
                }
            } else {
                print("⚠️ Ключ не найден для чата: \(chat.name)")
            }
        }
    }
}
