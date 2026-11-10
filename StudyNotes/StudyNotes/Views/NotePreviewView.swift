//
//  NotePreviewView.swift
//  StudyNotes
//

import SwiftUI
import UIKit
import SwiftMath

/// Renders a list of parsed blocks as a scrollable SwiftUI view.
/// Used in the editor's Preview mode. The same view will become the live-preview
/// sidebar in step 5 (NavigationSplitView).
struct NotePreviewView: View {
    let blocks: [NoteBlock]

    var body: some View {
        if blocks.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(for: block)
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Switch to Edit to write something.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Block rendering

    @ViewBuilder
    private func blockView(for block: NoteBlock) -> some View {
        switch block {
        case .heading(let level, let spans):
            Text(inlineString(spans, font: headingFont(level: level)))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let spans):
            Text(inlineString(spans, font: .body))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").frame(minWidth: 12, alignment: .leading)
                        Text(inlineString(item, font: .body))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").frame(minWidth: 20, alignment: .leading)
                        Text(inlineString(item, font: .body))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .codeBlock(let code):
            Text(code)
                .font(.body.monospaced())
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)

        case .formula(let latex):
            FormulaView(latex: latex)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Inline text via AttributedString

    /// Builds an AttributedString from inline spans with correct font per run.
    ///
    /// Why AttributedString instead of Text + concatenation:
    /// Text("x").bold() + Text("y") works, but applying .font() to the
    /// concatenated Text overrides the per-span bold/italic. With AttributedString,
    /// each run's font is set directly — no outer modifier can interfere.
    ///
    /// Font.bold() / .italic() are Font instance methods available from iOS 16.
    private func inlineString(_ spans: [InlineSpan], font: Font) -> AttributedString {
        var result = AttributedString()
        for span in spans {
            var part = AttributedString(span.rawText)
            switch span {
            case .text:
                part.font = font
            case .bold:
                part.font = font.bold()
            case .italic:
                part.font = font.italic()
            case .boldItalic:
                part.font = font.bold().italic()
            case .inlineCode:
                part.font = Font.body.monospaced()
                part.backgroundColor = Color(UIColor.systemGray5)
            }
            result.append(part)
        }
        return result
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1:  return .title.bold()
        case 2:  return .title2.bold()
        default: return .title3.bold()
        }
    }
}

// MARK: - Formula view

/// Renders one LaTeX formula via SwiftMath and shows the resulting UIImage.
/// FormulaView is private — only NotePreviewView uses it.
///
/// The textColor is chosen from the environment's color scheme so the formula
/// is readable in both light and dark mode (the PDF renderer uses fixed black,
/// but the on-screen renderer must adapt).
private struct FormulaView: View {
    let latex: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let textColor: UIColor = colorScheme == .dark ? .white : .black
        let mathImage = MTMathImage(latex: latex,
                                    fontSize: 20,
                                    textColor: textColor,
                                    labelMode: .display,
                                    textAlignment: .center)
        let (_, image) = mathImage.asImage()
        if let image {
            Image(uiImage: image)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Text("$$\(latex)$$")
                .font(.body.italic())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Preview

#Preview {
    NotePreviewView(blocks: SimpleMarkdownParser().parse("""
    # Binary Trees

    A **binary tree** is a tree where each node has *at most* two children: `left` and `right`.

    ## Common operations

    1. Insert
    2. Delete
    3. Search

    Example node in Swift:

    ```
    struct Node {
        var value: Int
        var left, right: Node?
    }
    ```

    Height formula:

    $$h = \\log_2(n)$$
    """))
}
