import SwiftUI

struct UploadView: View {
    var body: some View {
        Text("Upload!")
    }
}

#Preview {
    UploadView()
        .environment(ModelData())
}
