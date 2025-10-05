import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ServerView: View {
    @Environment(ModelData.self) var modelData
    @State private var isShowingDocumentPicker = false
    @State private var selectedPDFURL: URL?
    @State private var selectedPDFName: String = ""
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadStatus: UploadStatus = .idle
    @State private var errorMessage: String = ""
    @StateObject private var networkManager = NetworkManager()
    @State private var showLogs: Bool = false

    let bluetoothManager: BluetoothServerManager

    enum UploadStatus {
        case idle
        case encrypting
        case uploading
        case success
        case error
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    modelData.switchToBluetoothClient()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                    }
                    .frame(width: 48, height: 48)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .glassEffect(.regular.interactive())
                }
                Spacer()
                Button(action: {
                    modelData.fetchLogs()
                    showLogs.toggle()
                }) {
                    HStack {
                        Image(systemName: "document.badge.clock")
                    }
                    .frame(width: 48, height: 48)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .glassEffect(.regular.interactive())
                }
            }.padding(.horizontal)

            headerSection

            if selectedPDFURL != nil {
                selectedFileSection
            } else {
                selectFileSection
            }

            if uploadStatus != .idle {
                uploadProgressSection
            }

            if let files = modelData.files {
                if files.isEmpty == false {
                    Spacer()

                    Text("Files").font(.subheadline)
                    List(files) { file in
                        HStack(alignment: .center, spacing: 16) {
                            Image(systemName: "lock.document")
                            Text(file.metadata.fileName)
                        }
                        .contentShape(Rectangle())
                        .swipeActions {
                            Button(action: {
                                modelData.deleteFile(file: file)
                            }) {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 16) {
                Text("Room code: \(bluetoothManager.sessionID)").font(
                    .system(size: 18)
                )
                uploadButton
            }.padding(.horizontal)
        }
        .padding()
        .fileImporter(
            isPresented: $isShowingDocumentPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedPDFURL = url
                    selectedPDFName = url.lastPathComponent
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                uploadStatus = .error
            }
        }.sheet(isPresented: $showLogs) {
            VStack(spacing: 8) {
                Text("Logs").font(.title2)
                if modelData.logs != nil {
                    List(modelData.logs!, id: \.self) { log in
                        HStack(alignment: .center, spacing: 16) {
                            Image(
                                systemName:
                                    "clock.arrow.trianglehead.counterclockwise.rotate.90"
                            )
                            Text(log)
                        }
                        .contentShape(Rectangle())
                    }
                } else {
                    Text("Loading...")
                }
            }.padding()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("TempLock")
                .font(.title2)
                .fontWeight(.bold)

            Text("Select a PDF file to encrypt with AES256 and share securely")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    private var selectFileSection: some View {
        VStack(spacing: 15) {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundColor(.blue)
                .frame(height: 120)
                .overlay {
                    VStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Tap to select PDF")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .onTapGesture {
                    isShowingDocumentPicker = true
                }
        }.padding(.vertical)
    }

    private var selectedFileSection: some View {
        VStack(spacing: 15) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .frame(height: 100)
                .overlay {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.green)

                        VStack(alignment: .leading) {
                            Text(selectedPDFName)
                                .font(.headline)
                                .lineLimit(2)
                            Text("PDF Document")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Change") {
                            isShowingDocumentPicker = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploading)
                    }
                    .padding()
                }
        }
    }

    private var uploadProgressSection: some View {
        VStack(spacing: 10) {
            HStack {
                switch uploadStatus {
                case .encrypting:
                    Image(systemName: "lock.rotation")
                        .foregroundColor(.blue)
                    Text("Encrypting document...")
                case .uploading:
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Uploading...")
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Upload successful!")
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Upload failed")
                case .idle:
                    EmptyView()
                }
                Spacer()
            }

            if uploadStatus == .uploading {
                ProgressView(value: uploadProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
            }

            if uploadStatus == .error && !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var uploadButton: some View {
        Button(action: uploadFile) {
            HStack {
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                }
                Text(isUploading ? "Uploading..." : "Share")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .disabled(!canUpload)
            .glassEffect(.regular.interactive())
        }
        .disabled(!canUpload)
    }

    private var canUpload: Bool {
        selectedPDFURL != nil && !isUploading
    }

    private func uploadFile() {
        guard let pdfURL = selectedPDFURL else { return }

        isUploading = true
        uploadStatus = .encrypting
        uploadProgress = 0.0
        errorMessage = ""

        Task {
            do {
                // Read PDF data
                let pdfData: Data
                if pdfURL.startAccessingSecurityScopedResource() {
                    defer { pdfURL.stopAccessingSecurityScopedResource() }
                    pdfData = try Data(contentsOf: pdfURL)
                } else {
                    pdfData = try Data(contentsOf: pdfURL)
                }

                await MainActor.run {
                    uploadStatus = .uploading
                    uploadProgress = 0.1
                }

                // Generate encryption key and IV
                let (encryptedData, iv) =
                    try EncryptionManager.encryptData(
                        pdfData,
                        key: bluetoothManager.encryptionKey
                    )

                await MainActor.run {
                    uploadStatus = .uploading
                    uploadProgress = 0.3
                }

                // Upload to server
                let encryptedFileData = EncryptedFileData(
                    fileName: selectedPDFName,
                    originalData: pdfData,
                    encryptedData: encryptedData,
                    iv: iv
                )

                let result = try await networkManager.uploadEncryptedFile(
                    encryptedFileData,
                    sessionID: bluetoothManager.sessionID,
                    serverURL: modelData.serverURL
                ) { progress in
                    Task { @MainActor in
                        uploadProgress = 0.3 + (progress * 0.7)  // Start from 30%, progress to 100%
                    }
                }

                let newFile = AvailableFile(
                    id: result.fileId,
                    metadata: FileMetadata(
                        fileName: selectedPDFName,
                        fileSize: pdfData.count,
                        timestamp: Date(),
                        checksum: result.checksum,
                        iv: "fake"
                    ),
                )

                await MainActor.run {
                    uploadStatus = .success
                    uploadProgress = 1.0
                    isUploading = false
                    modelData.addAvailableFile(newFile)
                }

                // Reset after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    resetUploadState()
                }

            } catch {
                await MainActor.run {
                    uploadStatus = .error
                    errorMessage = error.localizedDescription
                    isUploading = false
                }
            }
        }
    }

    private func resetUploadState() {
        selectedPDFURL = nil
        selectedPDFName = ""
        uploadStatus = .idle
        uploadProgress = 0.0
        errorMessage = ""
    }
}

enum UploadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

#Preview {
    ServerView(
        bluetoothManager: BluetoothServerManager(
            sessionID: "testID",
            encryptionKey: EncryptionManager.generateEncryptionKey()
        )
    )
}
