import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    func save(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience for Encryption Key/IV

    private let keyKey = "encryption_key"
    private let ivKey = "encryption_iv"

    func saveEncryptionKey(_ key: Data, iv: Data) {
        save(key, forKey: keyKey)
        save(iv, forKey: ivKey)
    }

    func loadEncryptionKeyAndIV() -> (key: Data, iv: Data)? {
        guard let key = load(forKey: keyKey),
              let iv = load(forKey: ivKey) else { return nil }
        return (key, iv)
    }
    
    func sendEncryptionDataOverBluetooth(key: Data, iv: Data) -> [Data] {
        // Combine the key and IV
        let combinedData = key + iv
        
        // Split into 20-byte BLE chunks
        let chunks = combinedData.chunked(into: 20)
        
        return chunks
    }
}
extension Data {
    func chunked(into size: Int) -> [Data] {
        var chunks: [Data] = []
        var index = 0
        while index < count {
            let length = Swift.min(size, count - index)
            let chunk = self.subdata(in: index..<index + length)
            chunks.append(chunk)
            index += length
        }
        return chunks
    }
}
