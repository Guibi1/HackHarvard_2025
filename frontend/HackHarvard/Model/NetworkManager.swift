import Combine
import Foundation
import Network

/// A network manager for handling secure file uploads with progress tracking
class NetworkManager: ObservableObject {

    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var networkStatus: NetworkStatus = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum NetworkStatus {
        case unknown
        case connected
        case disconnected
        case cellular
        case wifi
        case ethernet
    }

    init() {
        startNetworkMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    /// Starts monitoring network connectivity
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self?.networkStatus = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self?.networkStatus = .cellular
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self?.networkStatus = .ethernet
                    } else {
                        self?.networkStatus = .connected
                    }
                } else {
                    self?.networkStatus = .disconnected
                }
            }
        }
        monitor.start(queue: queue)
    }

    func createSession(serverURL: URL) async -> String {
        let url = URL(string: "/create-session", relativeTo: serverURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            // Optional: check HTTP status code
            if let httpResp = response as? HTTPURLResponse,
                !(200...299).contains(httpResp.statusCode)
            {
                let bodyString =
                    String(data: data, encoding: .utf8) ?? "<non-text body>"
                throw NSError(
                    domain: "HTTPError",
                    code: httpResp.statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Status \(httpResp.statusCode): \(bodyString)"
                    ]
                )
            }

            // Decode JSON
            let decoder = JSONDecoder()
            let apiResp = try decoder.decode(
                CreateSessionResponse.self,
                from: data
            )

            // Update UI on main thread
            return apiResp.session_id
        } catch {
            await MainActor.run {
                // self.error = error.localizedDescription
                // self.isLoading = false
            }
        }

        return "invalid-key"
    }

    /// Uploads encrypted file data to the server
    /// - Parameters:
    ///   - encryptedFileData: The encrypted file data to upload
    ///   - sessionID: The session ID for the upload
    ///   - serverURL: The server endpoint URL
    ///   - progressHandler: Optional progress callback
    /// - Returns: Upload response data
    /// - Throws: NetworkError on failure
    func uploadEncryptedFile(
        _ encryptedFileData: EncryptedFileData,
        sessionID: String,
        serverURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> UploadResponse {
        let url = URL(string: "/upload", relativeTo: serverURL)!

        guard networkStatus != .disconnected else {
            throw NetworkError.noNetworkConnection
        }

        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }

        defer {
            Task { @MainActor in
                isUploading = false
                uploadProgress = 0.0
            }
        }

        do {
            // Create multipart form data
            let boundary = UUID().uuidString
            let httpBody = createMultipartBody(
                encryptedFileData,
                boundary: boundary,
                sessionID: sessionID
            )

            // Create the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(
                "gzip, deflate",
                forHTTPHeaderField: "Accept-Encoding"
            )
            request.timeoutInterval = 300  // 5 minutes timeout

            await updateProgress(0.2, progressHandler)

            // Create upload task with progress tracking
            let (data, response) = try await URLSession.shared.upload(
                for: request,
                from: httpBody
            )

            await updateProgress(0.9, progressHandler)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage =
                    String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NetworkError.serverError(
                    httpResponse.statusCode,
                    errorMessage
                )
            }

            await updateProgress(1.0, progressHandler)

            // Parse response
            let uploadResponse = try JSONDecoder().decode(
                UploadResponse.self,
                from: data
            )
            return uploadResponse

        } catch {
            await MainActor.run {
                uploadProgress = 0.0
            }

            if error is NetworkError {
                throw error
            } else {
                throw NetworkError.uploadFailed(error.localizedDescription)
            }
        }
    }

    /// Updates upload progress on main actor
    @MainActor
    private func updateProgress(
        _ progress: Double,
        _ handler: ((Double) -> Void)?
    ) {
        uploadProgress = progress
        handler?(progress)
    }

    /// Creates multipart form data for file upload
    private func createMultipartBody(
        _ fileData: EncryptedFileData,
        boundary: String,
        sessionID: String
    ) -> Data {
        var body = Data()

        // Add file metadata
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"metadata\"\r\n".data(
                using: .utf8
            )!
        )
        body.append(
            "Content-Type: application/json\r\n\r\n".data(using: .utf8)!
        )

        let metadata = FileMetadata(
            fileName: fileData.fileName,
            fileSize: fileData.fileSize,
            timestamp: fileData.timestamp,
            checksum: fileData.checksum,
            iv: fileData.iv.base64EncodedString()
        )

        if let metadataJSON = try? JSONEncoder().encode(metadata),
            let metadataString = String(data: metadataJSON, encoding: .utf8)
        {
            body.append(metadataString.data(using: .utf8)!)
        }
        body.append("\r\n".data(using: .utf8)!)

        // Add encrypted content
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"\r\n".data(
                using: .utf8
            )!
        )
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append(fileData.encryptedData)
        body.append("\r\n".data(using: .utf8)!)

        // Add IV
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"session_id\"\r\n".data(
                using: .utf8
            )!
        )
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append(sessionID.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    /// Downloads a file from the server
    /// - Parameter url: The file URL to download
    /// - Returns: The downloaded data
    /// - Throws: NetworkError on failure
    func downloadFile(fileId: String, sessionID: String, serverURL: URL)
        async throws -> Data
    {
        let url = URL(
            string: "/download/\(sessionID)/\(fileId)",
            relativeTo: serverURL
        )!

        guard networkStatus != .disconnected else {
            throw NetworkError.noNetworkConnection
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard let httpResponse = response as? HTTPURLResponse,
            200...299 ~= httpResponse.statusCode
        else {
            throw NetworkError.downloadFailed
        }

        return data
    }

    func listFiles(sessionID: String, serverURL: URL) async throws -> [(
        String, FileMetadata
    )] {
        let url = URL(string: "/get-all/\(sessionID)", relativeTo: serverURL)!

        guard networkStatus != .disconnected else {
            throw NetworkError.noNetworkConnection
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard let httpResponse = response as? HTTPURLResponse,
            200...299 ~= httpResponse.statusCode
        else {
            throw NetworkError.downloadFailed
        }

        let string_data = String(data: data, encoding: .utf8)!

        var files: [(String, FileMetadata)] = []
        for line in string_data.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let id = parts[0].trimmingCharacters(in: .whitespaces)
            let metaString = parts[1].trimmingCharacters(in: .whitespaces)

            if let metaData = metaString.data(using: .utf8),
                let metadata = try? JSONDecoder().decode(
                    FileMetadata.self,
                    from: metaData
                )
            {
                files.append((id, metadata))
            }
        }

        return files
    }

    /// Checks server connectivity
    /// - Parameter serverURL: The server URL to test
    /// - Returns: True if server is reachable
    func checkServerConnectivity(serverURL: String) async -> Bool {
        guard let url = URL(string: serverURL) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return 200...299 ~= httpResponse.statusCode
            }
            return false
        } catch {
            return false
        }
    }
}

/// Network-related errors
enum NetworkError: LocalizedError {
    case invalidURL
    case noNetworkConnection
    case invalidResponse
    case serverError(Int, String)
    case uploadFailed(String)
    case downloadFailed
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .noNetworkConnection:
            return "No network connection available"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed:
            return "Download failed"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}

/// File metadata structure
struct CreateSessionResponse: Codable {
    let session_id: String
}

/// File metadata structure
struct FileMetadata: Codable {
    let fileName: String
    let fileSize: Int
    let timestamp: Date
    let checksum: String
    let iv: String
}

/// Upload response structure
struct UploadResponse: Codable {
    let success: Bool
    let message: String
    let fileId: String?
    let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case fileId = "file_id"
        case downloadUrl = "download_url"
    }
}

/// Upload progress information
struct UploadProgress {
    let bytesUploaded: Int64
    let totalBytes: Int64
    let percentage: Double

    init(uploaded: Int64, total: Int64) {
        self.bytesUploaded = uploaded
        self.totalBytes = total
        self.percentage = total > 0 ? Double(uploaded) / Double(total) : 0.0
    }
}
