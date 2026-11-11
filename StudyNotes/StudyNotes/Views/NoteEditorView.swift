//
//  NoteEditorView.swift
//  StudyNotes
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Transferable wrappers

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

// MARK: - Editor mode (Markdown notes only)

private enum EditorMode: String, CaseIterable {
    case edit    = "Edit"
    case preview = "Preview"
}

// MARK: - View

/// The note editor pushed from HomeView.
///
/// Layout changes based on note type:
/// - PDF note (.pdf):      title field → editor.  Toolbar: [↑ share] [▶ play].
///   ▶ generates the PDF, saves it to the app's Documents folder, and shows a preview sheet.
/// - Markdown note (.markdown): title field → Edit/Preview picker → editor or preview.
///   Toolbar: [↑ share .md menu].
///
/// The view has no NavigationStack of its own — it is always pushed by HomeView's stack.
struct NoteEditorView: View {

    let destination: HomeDestination
    let onSave: (String, String) -> Void

    @State private var text: String
    @State private var noteName: String
    private let noteType: NoteType

    @State private var mode: EditorMode = .edit
    /// URL of the last generated PDF. Set on generation, cleared when text changes.
    @State private var pdfURL: URL?
    @State private var showPDFPreview = false
    @State private var errorMessage: String?
    @State private var formattingProfile: FormattingProfile = .standard
    @State private var showProfilePicker = false

    private enum FocusField { case title, content }
    @FocusState private var focusedField: FocusField?

    init(destination: HomeDestination, onSave: @escaping (String, String) -> Void) {
        self.destination = destination
        self.onSave = onSave
        switch destination {
        case .newNote(let type, let defaultName):
            _text     = State(wrappedValue: "")
            _noteName = State(wrappedValue: defaultName)
            noteType  = type
        case .existingNote(let note):
            _text     = State(wrappedValue: note.text)
            _noteName = State(wrappedValue: note.name ?? "")
            noteType  = note.noteType
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $noteName)
                .font(.title2.bold())
                .focused($focusedField, equals: .title)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .accessibilityLabel("Note title")

            Divider()

            // Segmented control is only meaningful for Markdown notes.
            // PDF notes show only the editor — the preview IS the PDF.
            if noteType == .markdown {
                Picker("Mode", selection: $mode) {
                    ForEach(EditorMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
            }

            contentView
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showPDFPreview) {
            if let url = pdfURL {
                PDFSheetView(url: url)
            }
        }
        .sheet(isPresented: $showProfilePicker) {
            profilePickerSheet
        }
        // Any edit invalidates the cached PDF — the user must regenerate.
        .onChange(of: text) { _ in pdfURL = nil }
        .onAppear {
            // New notes start focused on the title so the user can confirm or change it.
            // Existing notes go straight to content (title was already set).
            switch destination {
            case .newNote:      focusedField = .title
            case .existingNote: focusedField = .content
            }
        }
        .onDisappear { onSave(noteName, text) }
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            // "Aa" button opens the PDF formatting profile picker.
            // Both note types can generate a PDF, so the button appears for both.
            Button { showProfilePicker = true } label: {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("PDF format")

            if noteType == .pdf {
                // Share button appears only after a PDF has been generated.
                if let url = pdfURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                // Play button: generate PDF → save to Documents → show preview.
                Button(action: generateAndShowPDF) {
                    Image(systemName: "play.fill")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Generate PDF")
            } else {
                // Markdown note: share .md file or export to PDF.
                Menu {
                    ShareLink(
                        "Share Markdown",
                        item: MarkdownFile(text: text),
                        preview: SharePreview("Note.md")
                    )
                    Divider()
                    if let url = pdfURL {
                        ShareLink("Share PDF", item: url)
                    } else {
                        Button("Generate PDF", action: generateAndShowPDF)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    noteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    // MARK: - Profile picker sheet

    private var profilePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(FormattingProfile.allCases) { profile in
                    Button {
                        formattingProfile = profile
                        showProfilePicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .foregroundColor(.primary)
                                Text(profile.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if formattingProfile == profile {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PDF Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showProfilePicker = false }
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if noteType == .pdf || mode == .edit {
            TextEditor(text: $text)
                .padding(8)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.4))
                }
                .focused($focusedField, equals: .content)
                .padding()
        } else {
            NotePreviewView(blocks: SimpleMarkdownParser().parse(text))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - PDF generation

    /// Generates a PDF, saves it to the app's Documents folder, and opens the preview sheet.
    /// Used by the ▶ play button on PDF notes.
    ///
    /// Why Documents instead of tmp? Files in tmp can be purged by the OS at any time.
    /// Documents is the stable sandbox location — the same file is overwritten on each
    /// regeneration, keeping only the latest version.
    private func generateAndShowPDF() {
        generatePDF(showPreview: true)
    }

    private func generatePDF(showPreview: Bool) {
        let blocks = SimpleMarkdownParser().parse(text)
        let title = noteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = title.isEmpty ? "Note" : title
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var generator = PDFGenerator()
        generator.bodyFontSize = formattingProfile.bodyFontSize
        generator.margin = formattingProfile.margin
        do {
            pdfURL = try generator.writePDF(from: blocks, named: "\(fileName).pdf", in: docs)
            if showPreview { showPDFPreview = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Previews

#Preview("New PDF note") {
    NavigationStack {
        NoteEditorView(destination: .newNote(type: .pdf, defaultName: "PDF note")) { _, _ in }
    }
}

#Preview("New Markdown note") {
    NavigationStack {
        NoteEditorView(destination: .newNote(type: .markdown, defaultName: "Markdown note")) { _, _ in }
    }
}

#Preview("Existing Markdown note") {
    var note = Note(
        id: UUID(),
        text: "# Binary Trees\n\nA **binary tree** has *at most* two children per node.\n\n- Insert\n- Delete\n- Search\n\n$$h = \\log_2(n)$$",
        folderId: UUID(),
        createdAt: Date(),
        modifiedAt: Date()
    )
    note.name = "Binary Trees"
    note.noteType = .markdown
    return NavigationStack {
        NoteEditorView(destination: .existingNote(note)) { _, _ in }
    }
}
