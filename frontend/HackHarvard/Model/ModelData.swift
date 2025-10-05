import Combine
import Foundation
import SwiftUI

/// A class the app uses to store and manage model data.
@Observable
class ModelData {
    var searchString: String = ""
    var serverURL: URL = URL(string: "http://10.123.237.219:8000")!
    var backend: NetworkManager = NetworkManager()
    var bluetooth: BluetoothManager = .client(
        bluetoothManager: BluetoothClientManager()
    )

    var files: [AvailableFile]? = nil

    init() {
        if case .client(let bluetoothManager) = self.bluetooth {
            bluetoothManager.onConnection = { [weak self] in
                self?.fetchFiles()
            }
        }
        //
        //        Task { [weak self] in
        //            guard let self = self else { return }
        //            let networkManager = NetworkManager()
        //
        //            do {
        //                let fileData = try await networkManager.downloadFile(
        //                    from: "http://169.254.57.175:8080/download/ocean/output.txt"
        //                )
        //
        //                guard var base64String = String(data: fileData, encoding: .utf8)
        //                else {
        //                    throw EncryptionError.invalidBase64String
        //                }
        //
        //                base64String =
        //                    base64String
        //                    .trimmingCharacters(in: .whitespacesAndNewlines)
        //                    .replacingOccurrences(of: "%", with: "")
        //
        //                let encryptedData = try EncryptionManager.decodeFromBase64(
        //                    base64String
        //                )
        //                print(
        //                    "✅ Base64 decoded (\(encryptedData.count) bytes of encrypted data)"
        //                )
        //
        //                guard
        //                    let stored = KeychainManager.shared.loadEncryptionKeyAndIV()
        //                else {
        //                    throw EncryptionError.keyGenerationFailed
        //                }
        //
        //                print(
        //                    "🔑 Loaded key bytes: \(stored.key.count) | IV bytes: \(stored.iv.count)"
        //                )
        //
        //                let decryptedData = try EncryptionManager.decryptData(
        //                    encryptedData,
        //                    key: stored.key,
        //                    iv: stored.iv
        //                )
        //                print("✅ Decryption successful (\(decryptedData.count) bytes)")
        //
        //                let pdfURL = try Self.savePDFDataToDocuments(
        //                    decryptedData,
        //                    fileName: "output.pdf"
        //                )
        //                print("💾 Saved decrypted PDF to: \(pdfURL.path)")
        //
        //                await MainActor.run {
        //                    let newFile = AvailableFile(
        //                        id: UUID().uuidString,
        //                        name: "output.pdf",
        //                        isDownloaded: true,
        //                        pdfData: decryptedData
        //                    )
        //                    self.files.append(newFile)
        //                }
        //
        //            } catch {
        //                print(
        //                    "❌ Error decrypting or saving PDF: \(error.localizedDescription)"
        //                )
        //            }
        //        }
    }

    func fetchFiles() {
        let sessionID =
            switch self.bluetooth {
            case .client(let bluetoothManager):
                bluetoothManager.sessionID
            case .server(let bluetoothManager):
                bluetoothManager.sessionID
            }

        guard let sessionID = sessionID else { return }

        Task { [self] in
            let filenames = try await backend.listFiles(
                sessionID: sessionID,
                serverURL: serverURL
            )

            let newFiles = filenames.map { (id, metadata) in
                if let existing = self.files?.first(where: { $0.id == id }) {
                    // Preserve existing state and data
                    return AvailableFile(
                        id: id,
                        metadata: metadata,
                        state: existing.state,
                        pdfData: existing.pdfData
                    )
                } else {
                    // New file
                    return AvailableFile(id: id, metadata: metadata)
                }
            }

            // Publish the new list (must be on main actor)
            await MainActor.run {
                self.files = newFiles
            }
        }
    }

    func downloadFile(file: AvailableFile) async {
        let sessionID =
            switch self.bluetooth {
            case .client(let bluetoothManager):
                bluetoothManager.sessionID
            case .server(let bluetoothManager):
                bluetoothManager.sessionID
            }

        guard let sessionID = sessionID else { return }
        file.state = .downloading

        do {
            let data = try await self.backend.downloadFile(
                fileId: file.id,
                sessionID: sessionID,
                serverURL: serverURL
            )

            let decryptionKey =
                switch bluetooth {
                case .client(let bluetoothManager):
                    bluetoothManager.decryptionKey!
                case .server(let bluetoothManager):
                    bluetoothManager.encryptionKey
                }

            let pdfData = try EncryptionManager.decryptData(
                data,
                key: decryptionKey,
                iv: EncryptionManager.decodeFromBase64(file.metadata.iv),
            )

            if let current_file = self.files?.first(where: {
                file.id == $0.id
            }) {
                current_file.pdfData = pdfData
                current_file.state = .downloaded
            }
        } catch {
            if let current_file = self.files?.first(where: {
                file.id == $0.id
            }) {
                current_file.state = .inactive
            }
        }
    }

    func switchToServer() {
        Task { [weak self] in
            guard let self = self else { return }
            let sessionID = await self.backend.createSession(
                serverURL: self.serverURL
            )
            self.bluetooth = .server(
                bluetoothManager: BluetoothServerManager(

                    sessionID: sessionID,
                    encryptionKey: EncryptionManager.generateEncryptionKey()
                ),
            )
        }
    }

    // MARK: - Save Decrypted File
    static func savePDFDataToDocuments(_ data: Data, fileName: String) throws
        -> URL
    {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
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

class AvailableFile: Identifiable, ObservableObject {
    var id: String
    var metadata: FileMetadata
    var isSelected: Bool = false
    @Published var state: AvailableFileState = .inactive
    var pdfData: Data?

    init(
        id: String,
        metadata: FileMetadata,
        state: AvailableFileState = .inactive,
        pdfData: Data? = nil
    ) {
        self.id = id
        self.metadata = metadata
        self.state = state
        self.pdfData = pdfData
    }
}

enum AvailableFileState {
    case inactive
    case downloading
    case downloaded
}

enum BluetoothManager {
    case client(bluetoothManager: BluetoothClientManager)
    case server(
        bluetoothManager: BluetoothServerManager,

    )
}
