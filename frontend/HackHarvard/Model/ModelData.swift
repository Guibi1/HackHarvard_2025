import Foundation
import SwiftUI

/// A class the app uses to store and manage model data.
@Observable
class ModelData {
    var searchString: String = ""

    var isConnection: Bool = false
    var files: [AvailableFile] = [
        AvailableFile(id: "1", name: "Nuclear warhead.pdf", isDownloaded: true, pdfData: ModelData.createSamplePDFData()),
        AvailableFile(id: "2", name: "Launch codes.pdf", isDownloaded: false),
    ]
    init() {
        Task { [weak self] in
            guard let self = self else { return }
            let networkManager = NetworkManager()
            
            do {
                let fileData = try await networkManager.downloadFile(
                    from: "http://169.254.57.175:8080/download/ocean/output.txt"
                )
                
                guard var base64String = String(data: fileData, encoding: .utf8) else {
                    throw EncryptionError.invalidBase64String
                }
                
                base64String = base64String
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "%", with: "")
                
                let encryptedData = try EncryptionManager.decodeFromBase64(base64String)
                print("✅ Base64 decoded (\(encryptedData.count) bytes of encrypted data)")
                
                guard let stored = KeychainManager.shared.loadEncryptionKeyAndIV() else {
                    throw EncryptionError.keyGenerationFailed
                }
                
                print("🔑 Loaded key bytes: \(stored.key.count) | IV bytes: \(stored.iv.count)")
                
                let decryptedData = try EncryptionManager.decryptData(
                    encryptedData,
                    key: stored.key,
                    iv: stored.iv
                )
                print("✅ Decryption successful (\(decryptedData.count) bytes)")
                
                let pdfURL = try Self.savePDFDataToDocuments(decryptedData, fileName: "output.pdf")
                print("💾 Saved decrypted PDF to: \(pdfURL.path)")
                
                await MainActor.run {
                    let newFile = AvailableFile(
                        id: UUID().uuidString,
                        name: "output.pdf",
                        isDownloaded: true,
                        pdfData: decryptedData
                    )
                    self.files.append(newFile)
                }
                
            } catch {
                print("❌ Error decrypting or saving PDF: \(error.localizedDescription)")
            }
        }
    }
    // MARK: - Save Decrypted File
    static func savePDFDataToDocuments(_ data: Data, fileName: String) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
    

    static func createSamplePDFData() -> Data {
        let pdfContent = """
        %PDF-1.4
        1 0 obj
        <<
        /Type /Catalog
        /Pages 2 0 R
        >>
        endobj

        2 0 obj
        <<
        /Type /Pages
        /Kids [3 0 R]
        /Count 1
        >>
        endobj

        3 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        /Contents 4 0 R
        >>
        endobj

        4 0 obj
        <<
        /Length 44
        >>
        stream
        BT
        /F1 12 Tf
        72 720 Td
        (Sample PDF Document) Tj
        ET
        endstream
        endobj

        xref
        0 5
        0000000000 65535 f
        0000000010 00000 n
        0000000079 00000 n
        0000000136 00000 n
        0000000229 00000 n
        trailer
        <<
        /Size 5
        /Root 1 0 R
        >>
        startxref
        324
        %%EOF
        """

        return pdfContent.data(using: .utf8) ?? Data()
    }
}

class AvailableFile: Identifiable {
    var id: String
    var name: String
    var isSelected: Bool = false
    var isDownloaded: Bool = false
    var pdfData: Data?

    init(id: String, name: String, isDownloaded: Bool = false, pdfData: Data? = nil) {
        self.id = id
        self.name = name
        self.isDownloaded = isDownloaded
        self.pdfData = pdfData
    }
}
