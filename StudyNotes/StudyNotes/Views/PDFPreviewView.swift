//
//  PDFPreviewView.swift
//  StudyNotes
//

import SwiftUI
import PDFKit

/// Full-screen sheet that shows a generated PDF file.
/// Presented by NoteEditorView when the user taps the ▶ play button on a PDF note.
struct PDFSheetView: View {
    let url: URL

    /// @Environment(\.dismiss) is the SwiftUI way to close a sheet programmatically.
    /// Equivalent to calling dismiss() on a presented view controller in UIKit.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                // Let the PDF view reach the bottom of the screen (below the safe area).
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(url.deletingPathExtension().lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

/// Wraps PDFKit.PDFView (a UIView subclass) for use in SwiftUI.
///
/// UIViewRepresentable is the bridge between UIKit views and SwiftUI — the same
/// role as AndroidView in Jetpack Compose.  makeUIView creates the view once;
/// updateUIView is called whenever SwiftUI re-renders with new state.
private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            view.document = document
        }
    }
}

// MARK: - Preview

#Preview {
    // Shows an empty sheet in Xcode canvas (no real PDF at this path).
    PDFSheetView(url: FileManager.default.temporaryDirectory.appendingPathComponent("preview.pdf"))
}
