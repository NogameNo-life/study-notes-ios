//
//  NoteEditorView.swift
//  StudyNotes
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

// These two Transferable wrappers are duplicated from ContentView.swift.
// When ContentView is eventually retired they will be the canonical copies.

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

/// The note editor pushed from HomeView.
///
/// This view has no NavigationStack of its own — it is always pushed by HomeView's stack.
/// When the user taps Back, .onDisappear fires and the final text is handed to onSave.
struct NoteEditorView: View {

    let destination: HomeDestination
    /// Called with the editor's final text when the view disappears.
    /// HomeViewModel decides whether to save or discard based on content and destination.
    let onSave: (String) -> Void

    @State private var text: String
    @State private var pdfFile: PDFFile?
    @State private var errorMessage: String?

    /// @FocusState is a property wrapper that lets SwiftUI control keyboard focus.
    /// Setting editorFocused = true in .onAppear below shows the keyboard immediately —
    /// equivalent to calling becomeFirstResponder() in UIKit.
    @FocusState private var editorFocused: Bool

    init(destination: HomeDestination, onSave: @escaping (String) -> Void) {
        self.destination = destination
        self.onSave = onSave
        // @State must be initialised with _property = State(wrappedValue:) when the
        // initial value comes from a parameter. Using State(wrappedValue:) directly in
        // init() is the standard Swift pattern — analogous to field initialisation in Java.
        switch destination {
        case .newNote:
            _text = State(wrappedValue: "")
        case .existingNote(let note):
            _text = State(wrappedValue: note.text)
        }
    }

    private var navigationTitle: String {
        switch destination {
        case .newNote:               return "New Note"
        case .existingNote(let note): return note.title
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            TextEditor(text: $text)
                .padding(8)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.4))
                }
                .focused($editorFocused)

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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: text) { _ in pdfFile = nil }
        .onAppear { editorFocused = true }
        // .onDisappear fires when the view is popped from the NavigationStack.
        // At this point @State text still holds the final edited value — save it.
        .onDisappear { onSave(text) }
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

    private func createPDF() {
        let blocks = SimpleMarkdownParser().parse(text)
        do {
            pdfFile = PDFFile(url: try PDFGenerator().writePDF(from: blocks))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
