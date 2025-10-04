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
        .sheet(item: $selectedFile) { file in
            PDFPreviewView(file: file)
        }
    }
}

#Preview {
    FilesView()
        .environment(ModelData())
}
