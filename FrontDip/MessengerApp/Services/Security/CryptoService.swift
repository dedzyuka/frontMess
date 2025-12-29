// ./FrontDip/MessengerApp/Services/Security/CryptoService.swift
import Foundation
import CryptoKit
import UIKit

class CryptoService {
    static let shared = CryptoService()
    
    private init() {}
    
    // MARK: - Device ID Management
    
    func generateDeviceId() -> String {
        // Сначала пробуем загрузить из Keychain (основное хранилище)
        if let savedId = KeychainService.shared.loadDeviceId() {
            print("📱 Device_ID загружен из Keychain: \(savedId.prefix(8))...")
            return savedId
        }
        
        // Если нет в Keychain, пробуем UserDefaults (для миграции)
        if let userDefaultsId = UserDefaults.standard.string(forKey: "persistent_device_id") {
            // Мигрируем в Keychain
            _ = KeychainService.shared.saveDeviceId(userDefaultsId)
            print("📱 Device_ID мигрирован в Keychain: \(userDefaultsId.prefix(8))...")
            return userDefaultsId
        }
        
        // Генерируем новый Device ID
        var deviceComponents: [String] = []
        
        #if os(iOS)
        let device = UIDevice.current
        deviceComponents.append("iOS")
        deviceComponents.append(device.systemName)
        deviceComponents.append(device.systemVersion)
        deviceComponents.append(device.model)
        if let identifier = device.identifierForVendor?.uuidString {
            deviceComponents.append(identifier)
        }
        #endif
        
        if let bundleId = Bundle.main.bundleIdentifier {
            deviceComponents.append(bundleId)
        }
        
        let randomPart = UUID().uuidString
        deviceComponents.append(randomPart)
        
        let combinedString = deviceComponents.joined(separator: "_")
        let data = Data(combinedString.utf8)
        let hash = SHA256.hash(data: data)
        let deviceId = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Сохраняем в Keychain (основное) и UserDefaults (backup)
        _ = KeychainService.shared.saveDeviceId(deviceId)
        UserDefaults.standard.set(deviceId, forKey: "persistent_device_id")
        
        print("✅ Новый Device_ID сгенерирован: \(deviceId.prefix(8))...")
        
        return deviceId
    }
    
    // MARK: - Key Pair Generation
    
    func generateKeyPair() -> (privateKey: Data, publicKey: Data) {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation
        
        return (privateKey.rawRepresentation, publicKey)
    }
    
    func publicKeyToPEM(publicKey: Data) -> String {
        let base64Key = publicKey.base64EncodedString()
        
        let pem = """
        -----BEGIN PUBLIC KEY-----
        \(base64Key)
        -----END PUBLIC KEY-----
        """
        
        return pem
    }
    
    // MARK: - Symmetric Encryption
    
    func generateSymmetricKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    func encryptMessage(_ text: String, with key: SymmetricKey) throws -> Data {
        let textData = Data(text.utf8)
        let sealedBox = try AES.GCM.seal(textData, using: key)
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        return combined
    }
    
    func decryptMessage(_ data: Data, with key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        
        return text
    }
    
    // MARK: - Key Wrapping
    
    func encryptSymmetricKey(_ symmetricKey: SymmetricKey,
                           with publicKey: P256.KeyAgreement.PublicKey) throws -> Data {
        let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: publicKey)
        
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("ChatKeyExchange".utf8),
            outputByteCount: 32
        )
        
        let symmetricKeyData = symmetricKey.withUnsafeBytes { Data($0) }
        let sealedBox = try AES.GCM.seal(symmetricKeyData, using: derivedKey)
        
        var result = Data()
        result.append(ephemeralPrivateKey.publicKey.rawRepresentation)
        result.append(sealedBox.combined!)
        
        return result
    }
    
    func decryptSymmetricKey(_ encryptedData: Data,
                           with privateKey: P256.KeyAgreement.PrivateKey) throws -> SymmetricKey {
        let ephemeralPublicKeyData = encryptedData.prefix(65)
        let encryptedSymmetricKey = encryptedData.dropFirst(65)
        
        let ephemeralPublicKey = try P256.KeyAgreement.PublicKey(
            rawRepresentation: ephemeralPublicKeyData
        )
        
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
        
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("ChatKeyExchange".utf8),
            outputByteCount: 32
        )
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedSymmetricKey)
        let symmetricKeyData = try AES.GCM.open(sealedBox, using: derivedKey)
        
        return symmetricKeyData.withUnsafeBytes { SymmetricKey(data: $0) }
    }
    
    // MARK: - Utilities
    
    func dataToSymmetricKey(_ data: Data) -> SymmetricKey {
        return data.withUnsafeBytes { SymmetricKey(data: $0) }
    }
    
    func symmetricKeyToData(_ key: SymmetricKey) -> Data {
        return key.withUnsafeBytes { Data($0) }
    }
    
    // MARK: - Device ID Helpers
    
    func getCurrentDeviceId() -> String? {
        return KeychainService.shared.loadDeviceId()
    }
    
    func resetDeviceId() {
        KeychainService.shared.delete(key: "device_id")
        UserDefaults.standard.removeObject(forKey: "persistent_device_id")
        print("✅ Device_ID сброшен")
    }
    
    // MARK: - Errors
    
    enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
        case invalidKey
        case keyDerivationFailed
    }
}
