import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let file: AvailableFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let pdfData = file.pdfData {
                    PDFKitRepresentable(data: pdfData)
                        .navigationTitle(file.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    dismiss()
                                }
                            }
                        }
                } else {
                    ContentUnavailableView(
                        "PDF Not Available",
                        systemImage: "doc.text",
                        description: Text("The PDF data is not available for preview.")
                    )
                }
            }
        }
    }
}

struct PDFKitRepresentable: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        // Configure PDF view
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemBackground

        // Load PDF document from data
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update the PDF document if data changes
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

#Preview {
    PDFPreviewView(file: AvailableFile(
        id: "preview",
        name: "Sample.pdf",
        isDownloaded: true,
        pdfData: createSamplePDFData()
    ))
}

// Helper function to create sample PDF data for preview
private func createSamplePDFData() -> Data {
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
