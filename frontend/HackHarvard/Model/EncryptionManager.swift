import Foundation
import CryptoKit

/// A utility class for handling AES256 encryption and decryption operations
class EncryptionManager {

    /// Encrypts data using AES-GCM with a 256-bit key
    /// - Parameter data: The data to encrypt
    /// - Returns: A tuple containing the encrypted data, encryption key, and initialization vector
    /// - Throws: CryptoKitError if encryption fails
    static func encryptData(_ data: Data) throws -> (encryptedData: Data, key: Data, iv: Data) {
        // Generate a random 256-bit encryption key
        let key = SymmetricKey(size: .bits256)

        // Generate a random 12-byte nonce (IV) for AES-GCM
        let nonce = AES.GCM.Nonce()

        // Encrypt the data using AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        // Combine ciphertext and authentication tag
        let encryptedData = sealedBox.ciphertext + sealedBox.tag

        // Extract key and nonce as Data
        let keyData = key.withUnsafeBytes { Data($0) }
        let ivData = Data(nonce)

        return (encryptedData, keyData, ivData)
    }

    /// Decrypts data using AES-GCM
    /// - Parameters:
    ///   - encryptedData: The encrypted data (ciphertext + tag)
    ///   - keyData: The encryption key as Data
    ///   - ivData: The initialization vector as Data
    /// - Returns: The decrypted data
    /// - Throws: CryptoKitError if decryption fails
    static func decryptData(_ encryptedData: Data, key keyData: Data, iv ivData: Data) throws -> Data {
        // Recreate the symmetric key
        let key = SymmetricKey(data: keyData)

        // Recreate the nonce
        let nonce = try AES.GCM.Nonce(data: ivData)

        // Split the encrypted data into ciphertext and tag
        // AES-GCM tag is always 16 bytes
        let tagSize = 16
        guard encryptedData.count >= tagSize else {
            throw EncryptionError.invalidDataSize
        }

        let ciphertext = encryptedData.dropLast(tagSize)
        let tag = encryptedData.suffix(tagSize)

        // Create sealed box for decryption
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)

        // Decrypt the data
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    /// Generates a secure random encryption key
    /// - Returns: A 256-bit encryption key as Data
    static func generateEncryptionKey() -> Data {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    /// Converts data to a base64 encoded string for transmission
    /// - Parameter data: The data to encode
    /// - Returns: Base64 encoded string
    static func encodeToBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }

    /// Converts a base64 encoded string back to data
    /// - Parameter base64String: The base64 encoded string
    /// - Returns: The decoded data
    /// - Throws: EncryptionError if the string is not valid base64
    static func decodeFromBase64(_ base64String: String) throws -> Data {
        guard let data = Data(base64Encoded: base64String) else {
            throw EncryptionError.invalidBase64String
        }
        return data
    }
}

/// Custom errors for encryption operations
enum EncryptionError: LocalizedError {
    case invalidDataSize
    case invalidBase64String
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidDataSize:
            return "The encrypted data size is invalid"
        case .invalidBase64String:
            return "The provided string is not valid base64"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}

/// Data structure for encrypted file information
struct EncryptedFileData: Codable {
    let fileName: String
    let encryptedContent: String // base64 encoded
    let encryptionKey: String    // base64 encoded
    let iv: String              // base64 encoded
    let fileSize: Int
    let timestamp: Date
    let checksum: String        // SHA256 hash of original file

    init(fileName: String, originalData: Data, encryptedData: Data, key: Data, iv: Data) {
        self.fileName = fileName
        self.encryptedContent = encryptedData.base64EncodedString()
        self.encryptionKey = key.base64EncodedString()
        self.iv = iv.base64EncodedString()
        self.fileSize = originalData.count
        self.timestamp = Date()

        // Calculate SHA256 checksum of original data
        let hash = SHA256.hash(data: originalData)
        self.checksum = hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Extension to validate file integrity
extension EncryptedFileData {

    /// Validates the integrity of decrypted data using the stored checksum
    /// - Parameter decryptedData: The decrypted file data
    /// - Returns: True if the checksum matches, false otherwise
    func validateIntegrity(of decryptedData: Data) -> Bool {
        let hash = SHA256.hash(data: decryptedData)
        let calculatedChecksum = hash.compactMap { String(format: "%02x", $0) }.joined()
        return calculatedChecksum == self.checksum
    }
}
