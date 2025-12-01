import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let serviceIdentifier = "com.anonymous.messenger"
    
    private init() {}
    
    // Добавляем в существующий класс KeychainService
    func savePersistentDeviceId(_ deviceId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: "persistent_device_id",
            kSecValueData as String: Data(deviceId.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly // Сохраняется даже после перезагрузки
        ]
        
        // Удаляем старый если есть
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func loadPersistentDeviceId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: "persistent_device_id",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var data: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        
        if status == errSecSuccess, let data = data as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    // MARK: - Generic Methods
    
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Удаляем если уже существует
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    @discardableResult
    func saveData(key: String, value: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        
        return nil
    }
    
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - Specific Methods (добавляем по необходимости)
    
    
    
    // Для ключей пользователя
    @discardableResult
    func savePrivateKey(_ privateKey: Data, userId: UUID) -> Bool {
        saveData(key: "private_key_\(userId.uuidString)", value: privateKey)
    }
    
    func loadPrivateKey(userId: UUID) -> Data? {
        loadData(key: "private_key_\(userId.uuidString)")
    }
    
    @discardableResult
    func savePublicKey(_ publicKey: Data, userId: UUID) -> Bool {
        saveData(key: "public_key_\(userId.uuidString)", value: publicKey)
    }
    
    func loadPublicKey(userId: UUID) -> Data? {
        loadData(key: "public_key_\(userId.uuidString)")
    }
    
    // Для ключей чатов
    @discardableResult
    func saveChatKey(_ chatKey: Data, chatId: UUID) -> Bool {
        saveData(key: "chat_key_\(chatId.uuidString)", value: chatKey)
    }
    
    func loadChatKey(chatId: UUID) -> Data? {
        loadData(key: "chat_key_\(chatId.uuidString)")
    }
    
    @discardableResult
    func deleteChatKey(chatId: UUID) -> Bool {
        delete(key: "chat_key_\(chatId.uuidString)")
    }
    
    // Для очистки всех данных
    func wipeAllData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        
        SecItemDelete(query as CFDictionary)
        print("✅ Keychain очищен")
    }
    
    // Вспомогательные методы
    func getAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        guard status == errSecSuccess, let itemsArray = items as? [[String: Any]] else {
            return []
        }
        
        return itemsArray.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    
    func printAllStoredKeys() {
        let keys = getAllKeys()
        print("=== КЛЮЧИ В KEYCHAIN ===")
        if keys.isEmpty {
            print("(пусто)")
        } else {
            for key in keys.sorted() {
                print("🔑 \(key)")
            }
        }
        print("========================")
    }
    // Добавляем в существующий класс KeychainService

    // MARK: - Device ID Management (для обратной совместимости)

    @discardableResult
    func saveDeviceId(_ deviceId: String) -> Bool {
        // Для обратной совместимости сохраняем и в Keychain тоже
        // Но основной Device_ID теперь в UserDefaults
        return save(key: "device_id", value: deviceId)
    }

    func loadDeviceId() -> String? {
        // Проверяем сначала UserDefaults (новый способ)
        if let userDefaultsId = UserDefaults.standard.string(forKey: "persistent_device_id") {
            return userDefaultsId
        }
        // Затем Keychain (старый способ для миграции)
        return load(key: "device_id")
    }

    func migrateOldDeviceId() {
        // Миграция старых Device_ID из Keychain в UserDefaults
        if let oldDeviceId = load(key: "device_id") {
            if UserDefaults.standard.string(forKey: "persistent_device_id") == nil {
                UserDefaults.standard.set(oldDeviceId, forKey: "persistent_device_id")
                print("✅ Старый Device_ID мигрирован в UserDefaults")
            }
        }
    }
}
