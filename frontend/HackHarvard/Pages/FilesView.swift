import SwiftUI
import Foundation

struct FilesView: View {
    @Environment(ModelData.self) var modelData
    @State private var selectedFile: AvailableFile?

    var body: some View {
        List(modelData.files) { file in
            HStack {
                Text(file.name)

                Spacer()

                if !file.isDownloaded {
                    Image(systemName: "icloud.and.arrow.down")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedFile = file
            }
        }
        .navigationTitle("Files")
        .refreshable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Task { [self] in
                    let networkManager = NetworkManager()
                    
                    do {
                        let fileData = try await networkManager.downloadFile(
                            from: "http://172.20.10.6:8080/download/ocean/output.txt"
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
                        
                    } catch {
                        print("❌ Error decrypting or saving PDF: \(error.localizedDescription)")
                    }
                }
            }
        }
        .sheet(item: $selectedFile) { file in
            PDFPreviewView(file: file)
        }
    }
}

#Preview {
    FilesView()
        .environment(ModelData())
}
