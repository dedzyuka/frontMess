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
        // Просто вызываем метод из CryptoService
        // Теперь он сам управляет сохранением в UserDefaults
        return cryptoService.generateDeviceId()
    }
    
    var canRegister: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func logout() {
        print("🚪 Выход из аккаунта...")
        
        // 1. НЕ удаляем user_id из Keychain - сохраняем для будущих входов
        // _ = keychainService.delete(key: "user_id") // УБИРАЕМ ЭТУ СТРОКУ
        
        // 2. Сохраняем список чатов в UserDefaults
        if let userId = currentUser?.id {
            let chatKeys = keychainService.getAllKeys()
                .filter { $0.hasPrefix("chat_key_") }
                .map { $0.replacingOccurrences(of: "chat_key_", with: "") }
            
            UserDefaults.standard.set(chatKeys, forKey: "user_chats_\(userId.uuidString)")
            print("💾 Сохранено \(chatKeys.count) чатов для пользователя \(userId)")
        }
        
        // 3. Очищаем только состояние
        currentUser = nil
        nickname = ""
        AppState.shared.logout()
        
        print("✅ Выполнен выход. Данные сохранены.")
    }
    func restoreChatsOnLogin(userId: UUID) {
        print("🔄 Восстановление чатов после входа...")
        
        // 1. Проверяем, есть ли временные данные
        let key = "temp_chat_data_\(userId.uuidString)"
        guard let chatData = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] else {
            print("❌ Нет сохраненных чатов для восстановления")
            return
        }
        
        // 2. Восстанавливаем каждый ключ чата
        for (chatKey, encryptedData) in chatData {
            _ = keychainService.saveData(key: chatKey, value: encryptedData)
            print("✅ Восстановлен ключ: \(chatKey)")
        }
        
        // 3. Очищаем временные данные
        UserDefaults.standard.removeObject(forKey: key)
        print("✅ Чаты успешно восстановлены")
    }

    func completeWipe() {
        print("💣 ПОЛНАЯ ОЧИСТКА ВСЕХ ДАННЫХ...")
        
        // Полностью очищаем Keychain
        keychainService.wipeAllData()
        
        // Очищаем локальную базу сообщений
        LocalDatabase.shared.clearAllData()
        
        // Очищаем все синглтоны
        ChatKeyManager.shared.clearAllKeys()
        
        // Сбрасываем состояние
        currentUser = nil
        nickname = ""
        
        // Обновляем состояние приложения
        AppState.shared.logout()
        
        print("✅ Все данные полностью очищены")
    }
    
    private func restoreUserChats(userId: UUID) async {
        print("🔄 Восстановление чатов пользователя...")
        
        // 1. Загружаем список ID чатов из UserDefaults
        let key = "user_chats_\(userId.uuidString)"
        guard let chatIds = UserDefaults.standard.array(forKey: key) as? [String] else {
            print("Нет сохраненных чатов")
            return
        }
        
        print("📋 Найдено \(chatIds.count) сохраненных чатов")
        
        // 2. Загружаем каждый чат с сервера
        for chatIdString in chatIds {
            guard let chatId = UUID(uuidString: chatIdString) else { continue }
            
            // Проверяем, есть ли ключ чата в Keychain
            if keychainService.loadChatKey(chatId: chatId) != nil {
                print("✅ Чат \(chatIdString.prefix(8)) уже имеет ключ")
                continue
            }
            
            // TODO: Загрузить информацию о чате с сервера и восстановить ключ
            print("⚠️ Чат \(chatIdString.prefix(8)) требует восстановления ключа")
        }
    }
    
    // Добавьте метод для восстановления пользователя
    func restoreUser() async {
        print("🔄 Восстановление пользователя...")
        
        // 1. Проверяем, есть ли сохраненный user_id
        guard let userIdString = keychainService.load(key: "user_id"),
              let userId = UUID(uuidString: userIdString) else {
            print("❌ Нет сохраненного пользователя")
            return
        }
        
        print("🔑 Найден сохраненный user_id: \(userId)")
        
        // 2. Проверяем, есть ли приватный ключ
        guard let privateKeyData = keychainService.loadPrivateKey(userId: userId) else {
            print("❌ Нет приватного ключа для восстановления")
            return
        }
        
        // 3. Загружаем пользователя с сервера
        do {
            let user = try await APIService.shared.getUser(userId: userId)
            print("✅ Пользователь загружен: \(user.nickname)")
            
            await MainActor.run {
                currentUser = user
                AppState.shared.currentUser = user
                AppState.shared.login()
                print("🎉 ПОЛЬЗОВАТЕЛЬ ВОССТАНОВЛЕН!")
                NotificationCenter.default.post(name: .userLoggedIn, object: nil)
            }
            
        } catch {
            print("❌ Ошибка восстановления: \(error)")
            // Если пользователь не найден, удаляем сохраненные данные
            if (error as NSError).domain == NSURLErrorDomain,
               (error as NSError).code == NSURLErrorBadServerResponse {
                print("⚠️ Пользователь не найден на сервере, очищаем данные")
                await MainActor.run {
                    completeWipe()
                }
            }
        }
    }
    // Регистрация пользователя
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
            print("✅ Created at: \(user.createdAt)")
            
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
                isLoading = false
                AppState.shared.login()
                AppState.shared.currentUser = user
                print("🎉 РЕГИСТРАЦИЯ УСПЕШНА!")
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                isLoading = false
                print("❌ Ошибка регистрации: \(error)")
            }
        }
    }
    
    // Автоматический вход если есть сохраненный пользователь
    func autoLogin() {
        print("🔄 Пытаемся выполнить автоматический вход...")
        
        guard let userIdString = keychainService.load(key: "user_id"),
              let userId = UUID(uuidString: userIdString) else {
            print("❌ Нет сохраненного пользователя")
            return
        }
        
        print("🔑 Найден сохраненный user_id: \(userId)")
        
        Task {
            do {
                let user = try await APIService.shared.getUser(userId: userId)
                
                await MainActor.run {
                    currentUser = user
                    AppState.shared.currentUser = user
                    AppState.shared.login()
                    
                    print("🎉 АВТОМАТИЧЕСКИЙ ВХОД ВЫПОЛНЕН!")
                    
                    // Подключаем WebSocket после успешного входа
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        print("🔗 Подключаем WebSocket для пользователя: \(user.nickname)")
                        WebSocketService.shared.connect(userId: user.id)
                    }
                    
                    NotificationCenter.default.post(name: .userLoggedIn, object: nil)
                }
                
            } catch {
                print("❌ Ошибка автоматического входа: \(error)")
            }
        }
    }
    func connectWebSocket() {
        guard let user = currentUser else { return }
        
        print("🔗 Подключаем WebSocket для пользователя: \(user.nickname)")
        WebSocketService.shared.connect(userId: user.id)
        
        // Проверить через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            print("WebSocket подключен: \(WebSocketService.shared.isConnected)")
        }
    }
    // Добавьте метод для восстановления ключей чатов
    private func restoreChatKeys(userId: UUID) async {
        print("🔄 Восстановление ключей чатов...")
        
        let allKeys = keychainService.getAllKeys()
        let chatKeyPrefix = "chat_key_"
        
        for key in allKeys {
            if key.hasPrefix(chatKeyPrefix) {
                let chatIdString = key.replacingOccurrences(of: chatKeyPrefix, with: "")
                guard let chatId = UUID(uuidString: chatIdString) else { continue }
                
                do {
                    // Загружаем зашифрованный ключ чата
                    guard let encryptedChatKey = keychainService.loadChatKey(chatId: chatId),
                          let privateKeyData = keychainService.loadPrivateKey(userId: userId) else {
                        continue
                    }
                    
                    let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
                    let cryptoService = CryptoService.shared
                    
                    // Расшифровываем ключ чата
                    let chatKey = try cryptoService.decryptSymmetricKey(encryptedChatKey, with: privateKey)
                    let chatKeyData = cryptoService.symmetricKeyToData(chatKey)
                    
                    // Сохраняем в менеджер ключей
                    ChatKeyManager.shared.saveChatKey(chatKeyData, for: chatId)
                    
                    print("🔑 Восстановлен ключ для чата: \(chatId)")
                    
                } catch {
                    print("❌ Ошибка восстановления ключа для чата \(chatId): \(error)")
                }
            }
        }
        
        print("✅ Восстановление ключей чатов завершено")
    }
    
    // Полная очистка всех данных
    func wipeAllData() {
        print("💣 ПОЛНАЯ ОЧИСТКА ВСЕХ ДАННЫХ...")
        keychainService.wipeAllData()
        LocalDatabase.shared.clearAllData()
        currentUser = nil
        nickname = ""
        AppState.shared.logout()
        print("✅ Все данные очищены")
    }
    
    // Проверяем, есть ли сохраненный пользователь
    func hasSavedUser() -> Bool {
        let hasUser = keychainService.load(key: "user_id") != nil
        print("🔍 Проверка сохраненного пользователя: \(hasUser ? "ДА" : "НЕТ")")
        return hasUser
    }
}
