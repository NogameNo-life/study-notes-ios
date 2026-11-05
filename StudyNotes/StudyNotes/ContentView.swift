//
//  ContentView.swift
//  StudyNotes
//
//  Created by Yana Sitkovets on 9/28/26.
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

// Wraps the generated PDF file so ShareLink presents it as a file (not a URL string).
// FileRepresentation makes Quick Look ("Просмотр") and "Save to Files" appear in the
// share sheet, which a bare URL item does not reliably do.
private struct PDFFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .pdf) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}

// Wraps the typed markdown text as a .md file for sharing.
// The text is already markdown — no conversion needed.
private struct MarkdownFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("StudyNotes.md")
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        } importing: { received in
            Self(text: try String(contentsOf: received.file, encoding: .utf8))
        }
    }
}

struct ContentView: View {
    @State private var text = ""
    @State private var pdfFile: PDFFile?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $text)
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.4))
                    }

                HStack(spacing: 12) {
                    Button("Create PDF", action: createPDF)
                        .buttonStyle(.borderedProminent)

                    ShareLink(
                        "Share .md",
                        item: MarkdownFile(text: text),
                        preview: SharePreview("StudyNotes.md")
                    )
                    .buttonStyle(.bordered)
                }
                .disabled(text.isEmpty)

                if let pdfFile {
                    ShareLink("Share PDF", item: pdfFile, preview: SharePreview("StudyNotes.pdf"))
                }
            }
            .padding()
            .navigationTitle("StudyNotes")
            .onChange(of: text) { _ in
                pdfFile = nil
            }
            .alert(
                "Could not create PDF",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func createPDF() {
        let blocks = SimpleMarkdownParser().parse(text)
        do {
            pdfFile = PDFFile(url: try PDFGenerator().writePDF(from: blocks))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
