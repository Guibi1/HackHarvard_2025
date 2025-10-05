import Foundation
import SwiftUI

struct FilesView: View {
    @ObservedObject var bluetoothManager: BluetoothClientManager
    @Environment(ModelData.self) var modelData
    @State private var selectedFile: AvailableFile?
    @State var downloadingFileId: String?

    var body: some View {
        if let files = modelData.files {
            List(files) { file in
                FileRow(file: file)
                    .onTapGesture {
                        if file.state == .downloaded {
                            selectedFile = file
                            downloadingFileId = nil
                        } else if file.state == .inactive {
                            Task {
                                downloadingFileId = file.id
                                await modelData.downloadFile(file: file)
                                if downloadingFileId == file.id {
                                    selectedFile = file
                                }
                            }
                        } else {
                            downloadingFileId = file.id
                        }
                    }
            }
            .navigationTitle("Files")
            .refreshable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    modelData.fetchFiles()
                }
            }
            .sheet(item: $selectedFile) { file in
                PDFPreviewView(file: file)
            }
        } else {
            Text("Loading…")
                .navigationTitle("Files").onAppear {
                    modelData.fetchFiles()
                }
        }
    }
}

struct FileRow: View {
    @ObservedObject var file: AvailableFile

    var body: some View {
        HStack {
            Text(file.metadata.fileName)
            Spacer()
            if file.state == .inactive {
                Image(systemName: "arrow.down.circle.dotted")
            } else if file.state == .downloading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    FilesView(bluetoothManager: BluetoothClientManager())
        .environment(ModelData())
}
