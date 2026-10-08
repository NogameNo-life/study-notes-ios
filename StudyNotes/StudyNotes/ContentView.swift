//
//  ContentView.swift
//  StudyNotes
//
//  Created by Yana Sitkovets on 9/28/26.
//

import SwiftUI

struct ContentView: View {
    @State private var text = ""
    @State private var pdfURL: URL?
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

                Button("Create PDF", action: createPDF)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.isEmpty)

                if let pdfURL {
                    ShareLink("Share PDF", item: pdfURL)
                }
            }
            .padding()
            .navigationTitle("StudyNotes")
            // The PDF on disk no longer matches the text, so hide the share link.
            .onChange(of: text) { _ in
                pdfURL = nil
            }
            .alert(
                "Could not create PDF",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func createPDF() {
        do {
            pdfURL = try PDFGenerator().writePDF(from: text)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
