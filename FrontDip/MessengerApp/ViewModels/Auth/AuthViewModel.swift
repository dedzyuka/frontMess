// ./FrontDip/MessengerApp/ViewModels/Auth/AuthViewModel.swift
import Foundation
import CryptoKit
import Combine

class AuthViewModel: ObservableObject {
    @Published var nickname = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    
    private let apiService = APIService.shared
    private let cryptoService = CryptoService.shared
    private let keychainService = KeychainService.shared
    
    var deviceId: String {
        return cryptoService.generateDeviceId()
    }
    
    var canRegister: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - User Registration
    
    func register() async {
        guard canRegister else {
            await MainActor.run {
                errorMessage = "Введите никнейм"
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            print("=== НАЧИНАЕМ РЕГИСТРАЦИЮ ===")
            print("Device ID: \(deviceId)")
            print("Nickname: \(nickname)")
            
            // 1. Генерируем пару ключей
            let (privateKeyData, publicKeyData) = cryptoService.generateKeyPair()
            print("✅ Ключи сгенерированы")
            
            // 2. Конвертируем публичный ключ в PEM
            let publicKeyPEM = cryptoService.publicKeyToPEM(publicKey: publicKeyData)
            print("✅ PEM ключ создан")
            
            // 3. Регистрируем пользователя
            print("📤 Отправляем запрос на сервер...")
            let user = try await apiService.registerUser(
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                publicKey: publicKeyPEM,
                deviceId: deviceId
            )
            
            print("✅ Пользователь создан: \(user.id)")
            print("✅ Nickname: \(user.nickname)")
            
            // 4. Сохраняем приватный ключ
            let privateSaved = keychainService.savePrivateKey(privateKeyData, userId: user.id)
            print("🔐 Приватный ключ сохранен: \(privateSaved)")
            
            let publicSaved = keychainService.savePublicKey(publicKeyData, userId: user.id)
            print("🔐 Публичный ключ сохранен: \(publicSaved)")
            
            // 5. Сохраняем user_id для автовхода
            let userSaved = keychainService.save(key: "user_id", value: user.id.uuidString)
            print("💾 User ID сохранен в Keychain: \(userSaved)")
            
            // 6. Отладочная печать всех ключей
            keychainService.printAllStoredKeys()
            
            await MainActor.run {
                currentUser = user
                AppState.shared.currentUser = user
                AppState.shared.login()
                isLoading = false
                
                print("🎉 РЕГИСТРАЦИЯ УСПЕШНА!")
                
                // 7. Подключаем WebSocket
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print("🔗 Подключаем WebSocket после регистрации")
                    WebSocketService.shared.connect(userId: user.id)
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                isLoading = false
                print("❌ Ошибка регистрации: \(error)")
            }
        }
    }
    
    // MARK: - Session Management
    
    func restoreSession() async {
        print("🔄 Восстановление сессии...")
        
        guard let userIdString = keychainService.load(key: "user_id"),
              let userId = UUID(uuidString: userIdString) else {
            print("❌ Нет сохраненного пользователя")
            return
        }
        
        // Проверяем Device ID
        guard let deviceId = keychainService.loadDeviceId() else {
            print("❌ Device ID не найден")
            return
        }
        
        print("🔑 Найден сохраненный user_id: \(userId)")
        print("📱 Device ID: \(deviceId.prefix(8))...")
        
        do {
            let user = try await apiService.getUser(userId: userId)
            
            await MainActor.run {
                currentUser = user
                AppState.shared.currentUser = user
                AppState.shared.login()
                
                print("✅ Сессия восстановлена: \(user.nickname)")
                
                // Подключаем WebSocket
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print("🔗 Подключаем WebSocket для пользователя: \(user.nickname)")
                    WebSocketService.shared.connect(userId: user.id)
                }
                
                // Синхронизируем контакты и запросы
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    print("🔄 Синхронизация контактов...")
                    ContactService.shared.syncContacts()
                    ContactService.shared.syncPendingRequests()
                }
                
                NotificationCenter.default.post(name: .userLoggedIn, object: nil)
            }
            
        } catch {
            print("❌ Ошибка восстановления: \(error)")
        }
    }

    private func restoreAndCreateChatKeys(userId: UUID) {
        print("🔄 Восстановление и создание ключей чатов...")
        
        // Загружаем чаты пользователя
        Task {
            guard let deviceId = KeychainService.shared.loadDeviceId() else {
                print("❌ Device ID не найден")
                return
            }
            
            do {
                let chats = try await APIService.shared.getUserChats(
                    userId: userId,
                    deviceId: deviceId
                )
                
                for chat in chats {
                    // Проверяем, есть ли уже ключ для этого чата
                    if keychainService.loadChatKey(chatId: chat.id) == nil {
                        print("🔑 Создаем ключ для чата: \(chat.name)")
                        
                        // Генерируем новый ключ для чата
                        let chatKey = cryptoService.generateSymmetricKey()
                        
                        guard let publicKeyData = keychainService.loadPublicKey(userId: userId) else {
                            print("❌ Публичный ключ не найден для чата \(chat.name)")
                            continue
                        }
                        
                        let publicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData)
                        let encryptedChatKey = try cryptoService.encryptSymmetricKey(chatKey, with: publicKey)
                        
                        // Сохраняем в Keychain
                        _ = keychainService.saveChatKey(encryptedChatKey, chatId: chat.id)
                        
                        // Сохраняем в памяти
                        let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                        ChatKeyManager.shared.saveChatKey(chatKeyData, for: chat.id)
                        
                        print("✅ Ключ создан для чата: \(chat.name)")
                    } else {
                        print("✅ Ключ уже существует для чата: \(chat.name)")
                    }
                }
            } catch {
                print("❌ Ошибка загрузки чатов для создания ключей: \(error)")
            }
        }
    }
    
    private func restoreChatKeys(userId: UUID) {
        print("🔄 Восстановление ключей чатов...")
        
        // Получаем все chat_key_* из Keychain
        let allKeys = keychainService.getAllKeys()
        let chatKeyPrefix = "chat_key_"
        
        for key in allKeys where key.hasPrefix(chatKeyPrefix) {
            let chatIdString = key.replacingOccurrences(of: chatKeyPrefix, with: "")
            guard let chatId = UUID(uuidString: chatIdString),
                  let encryptedKey = keychainService.loadChatKey(chatId: chatId),
                  let privateKeyData = keychainService.loadPrivateKey(userId: userId) else {
                continue
            }
            
            do {
                let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
                let chatKey = try cryptoService.decryptSymmetricKey(encryptedKey, with: privateKey)
                let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                
                ChatKeyManager.shared.saveChatKey(chatKeyData, for: chatId)
                print("🔑 Восстановлен ключ для чата: \(chatId)")
            } catch {
                print("❌ Ошибка восстановления ключа чата: \(error)")
            }
        }
    }
    
    // MARK: - Auto Login
    
    func autoLogin() {
        print("🔄 Пытаемся выполнить автоматический вход...")
        
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Logout & Cleanup
    
    func logout() {
        print("🚪 Выход из системы...")
        
        // 1. Отключаем WebSocket
        WebSocketService.shared.disconnect()
        
        // 2. Сохраняем ключи чатов во временное хранилище
        if let userId = currentUser?.id {
            saveChatKeysForRecovery(userId: userId)
        }
        
        // 3. Очищаем состояние
        currentUser = nil
        nickname = ""
        AppState.shared.logout()
        
        print("✅ Выход выполнен")
    }
    
    private func saveChatKeysForRecovery(userId: UUID) {
        let allKeys = keychainService.getAllKeys()
        let chatKeyPrefix = "chat_key_"
        var chatKeys: [String] = []
        
        for key in allKeys where key.hasPrefix(chatKeyPrefix) {
            chatKeys.append(key)
        }
        
        UserDefaults.standard.set(chatKeys, forKey: "recovery_chat_keys_\(userId.uuidString)")
        print("💾 Сохранены ключи \(chatKeys.count) чатов для восстановления")
    }
    
    func wipeAllData() {
        print("💣 Полная очистка данных...")
        
        // 1. Отключаем WebSocket
        WebSocketService.shared.disconnect()
        
        // 2. Очищаем Keychain
        keychainService.wipeAllData()
        
        // 3. Очищаем локальную БД
        LocalDatabase.shared.clearAllData()
        
        // 4. Очищаем память
        ChatKeyManager.shared.clearAllKeys()
        
        // 5. Очищаем состояние
        currentUser = nil
        nickname = ""
        AppState.shared.logout()
        
        // 6. Сбрасываем Device ID
        cryptoService.resetDeviceId()
        
        print("✅ Все данные очищены")
    }
    
    // MARK: - Utility Methods
    
    func hasSavedUser() -> Bool {
        let hasUser = keychainService.load(key: "user_id") != nil
        let hasDeviceId = keychainService.loadDeviceId() != nil
        return hasUser && hasDeviceId
    }
}
