import Foundation
import UIKit
import CryptoKit

class CryptoService {
    static let shared = CryptoService()
    
    private init() {}
    
        // MARK: - Device ID Generation
        
        func generateDeviceId() -> String {
            print("🔧 Генерация Device_ID...")
            
            // 1. Пробуем загрузить сохраненный Device_ID из UserDefaults
            if let savedId = UserDefaults.standard.string(forKey: "persistent_device_id") {
                print("📱 Device_ID загружен из UserDefaults: \(savedId.prefix(8))...")
                return savedId
            }
            
            // 2. Если нет - генерируем новый на основе параметров устройства
            var deviceComponents: [String] = []
            
            #if os(iOS)
            // Для iOS используем UIDevice
            let device = UIDevice.current
            deviceComponents.append("iOS")
            deviceComponents.append(device.systemName)
            deviceComponents.append(device.systemVersion)
            deviceComponents.append(device.model)
            if let identifier = device.identifierForVendor?.uuidString {
                deviceComponents.append(identifier)
            }
            #elseif os(macOS)
            // Для macOS
            deviceComponents.append("macOS")
            if let serialNumber = getMacSerialNumber() {
                deviceComponents.append(serialNumber)
            }
            #endif
            
            // 3. Добавляем Bundle Identifier
            if let bundleId = Bundle.main.bundleIdentifier {
                deviceComponents.append(bundleId)
            }
            
            // 4. Добавляем случайную часть для безопасности
            let randomPart = UUID().uuidString
            deviceComponents.append(randomPart)
            
            // 5. Объединяем и хэшируем
            let combinedString = deviceComponents.joined(separator: "_")
            let data = Data(combinedString.utf8)
            let hash = SHA256.hash(data: data)
            let deviceId = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            // 6. Сохраняем навсегда в UserDefaults
            UserDefaults.standard.set(deviceId, forKey: "persistent_device_id")
            print("✅ Новый Device_ID сгенерирован и сохранен: \(deviceId.prefix(8))...")
            
            return deviceId
        }
        
        #if os(macOS)
        private func getMacSerialNumber() -> String? {
            let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault,
                                                             IOServiceMatching("IOPlatformExpertDevice"))
            guard platformExpert > 0 else { return nil }
            
            defer { IOObjectRelease(platformExpert) }
            
            guard let serialNumber = IORegistryEntryCreateCFProperty(platformExpert,
                                                                    kIOPlatformSerialNumberKey as CFString,
                                                                    kCFAllocatorDefault, 0).takeRetainedValue() as? String
            else {
                return nil
            }
            
            return serialNumber
        }
        #endif
    
    // MARK: - Key Pair Generation (P-256)
    
    func generateKeyPair() -> (privateKey: Data, publicKey: Data) {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        return (privateKey.rawRepresentation, publicKey.rawRepresentation)
    }
    
    // MARK: - PEM Format Conversion
    
    func publicKeyToPEM(publicKey: Data) -> String {
        let base64Key = publicKey.base64EncodedString()
        
        // Формат PEM для EC публичного ключа
        let pem = """
        -----BEGIN PUBLIC KEY-----
        \(base64Key)
        -----END PUBLIC KEY-----
        """
        
        return pem
    }
    
    // MARK: - Symmetric Key Operations
    
    func generateSymmetricKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    func encryptMessage(_ text: String, with symmetricKey: SymmetricKey) throws -> Data {
        let textData = Data(text.utf8)
        let sealedBox = try AES.GCM.seal(textData, using: symmetricKey)
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        return combined
    }
    
    func decryptMessage(_ data: Data, with symmetricKey: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        
        return text
    }
    
    // MARK: - Key Wrapping (Encrypt symmetric key with asymmetric)
    
    func encryptSymmetricKey(_ symmetricKey: SymmetricKey,
                           with publicKey: P256.KeyAgreement.PublicKey) throws -> Data {
        // Генерируем эфемерную пару ключей для ECDH
        let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
        
        // Вычисляем общий секрет
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: publicKey)
        
        // Деривируем ключ для шифрования
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("ChatKeyExchange".utf8),
            outputByteCount: 32
        )
        
        // Конвертируем симметричный ключ в Data
        let symmetricKeyData = symmetricKey.withUnsafeBytes { Data($0) }
        
        // Шифруем симметричный ключ
        let sealedBox = try AES.GCM.seal(symmetricKeyData, using: derivedKey)
        
        // Комбинируем: эфемерный публичный ключ + зашифрованный симметричный ключ
        var result = Data()
        result.append(ephemeralPrivateKey.publicKey.rawRepresentation)
        result.append(sealedBox.combined!)
        
        return result
    }
    
    func decryptSymmetricKey(_ encryptedData: Data,
                           with privateKey: P256.KeyAgreement.PrivateKey) throws -> SymmetricKey {
        // Первые 65 байт - эфемерный публичный ключ (P-256 uncompressed)
        let ephemeralPublicKeyData = encryptedData.prefix(65)
        let encryptedSymmetricKey = encryptedData.dropFirst(65)
        
        let ephemeralPublicKey = try P256.KeyAgreement.PublicKey(
            rawRepresentation: ephemeralPublicKeyData
        )
        
        // Вычисляем общий секрет
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
        
        // Деривируем ключ для дешифрования
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("ChatKeyExchange".utf8),
            outputByteCount: 32
        )
        
        // Дешифруем симметричный ключ
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedSymmetricKey)
        let symmetricKeyData = try AES.GCM.open(sealedBox, using: derivedKey)
        
        // Восстанавливаем SymmetricKey
        return symmetricKeyData.withUnsafeBytes { SymmetricKey(data: $0) }
    }
    
    // MARK: - Data to Key Conversions
    
    func dataToSymmetricKey(_ data: Data) -> SymmetricKey {
        return data.withUnsafeBytes { SymmetricKey(data: $0) }
    }
    
    func symmetricKeyToData(_ key: SymmetricKey) -> Data {
        return key.withUnsafeBytes { Data($0) }
    }
    
    // MARK: - Errors
    
    enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
        case invalidKey
        case keyDerivationFailed
    }
    // MARK: - Device ID Management
        
    func resetDeviceId() {
        print("🔄 Сброс Device_ID...")
        
        // 1. Удаляем из UserDefaults
        UserDefaults.standard.removeObject(forKey: "persistent_device_id")
        
        // 2. Удаляем из Keychain
        let keychainService = KeychainService.shared
        keychainService.delete(key: "device_id")
        
        print("✅ Device_ID сброшен. При следующем запуске будет сгенерирован новый.")
    }

    func getCurrentDeviceId() -> String? {
        return UserDefaults.standard.string(forKey: "persistent_device_id")
    }

    func printDeviceInfo() {
        #if os(iOS)
        let device = UIDevice.current
        print("📱 Информация об устройстве:")
        print("   Система: \(device.systemName) \(device.systemVersion)")
        print("   Модель: \(device.model)")
        print("   Имя: \(device.name)")
        if let identifier = device.identifierForVendor {
            print("   Vendor ID: \(identifier.uuidString)")
        }
        #endif
        
        if let deviceId = getCurrentDeviceId() {
            print("   Device_ID: \(deviceId.prefix(16))...")
        }
    }
}
