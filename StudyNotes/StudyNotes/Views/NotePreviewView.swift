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

    @Environment(\.colorScheme) private var colorScheme

    // Approximate point sizes at the default Dynamic Type size, used by SwiftMath
    // to render inline formula images at the right scale for each block kind.
    private let bodyFontSize: CGFloat = 17
    private func headingFontSize(level: Int) -> CGFloat {
        switch level {
        case 1:  return 28
        case 2:  return 22
        default: return 20
        }
    }

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
            inlineText(spans, font: headingFont(level: level), fontSize: headingFontSize(level: level))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let spans):
            inlineText(spans, font: .body, fontSize: bodyFontSize)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").frame(minWidth: 12, alignment: .leading)
                        inlineText(item, font: .body, fontSize: bodyFontSize)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").frame(minWidth: 20, alignment: .leading)
                        inlineText(item, font: .body, fontSize: bodyFontSize)
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

    // MARK: - Inline text

    /// Concatenates spans into a single `Text` by calling `+` on individually styled sub-texts.
    ///
    /// Why Text concatenation instead of a single AttributedString:
    /// `.inlineFormula` spans need to be rendered as `Text(Image(...))`, which requires
    /// a `Text` operand. `AttributedString` has no image-attachment support in SwiftUI.
    /// Each sub-Text gets its own `.font()` modifier *before* concatenation, so no outer
    /// modifier can override per-span styles.
    private func inlineText(_ spans: [InlineSpan], font: Font, fontSize: CGFloat) -> Text {
        spans.reduce(Text("")) { $0 + spanText($1, font: font, fontSize: fontSize) }
    }

    private func spanText(_ span: InlineSpan, font: Font, fontSize: CGFloat) -> Text {
        switch span {
        case .text(let s):
            return Text(s).font(font)
        case .bold(let s):
            return Text(s).font(font.bold())
        case .italic(let s):
            return Text(s).font(font.italic())
        case .boldItalic(let s):
            return Text(s).font(font.bold().italic())
        case .inlineCode(let s):
            // AttributedString.backgroundColor is supported in SwiftUI Text (iOS 15+)
            // and survives Text concatenation as long as no outer .font() is applied.
            var part = AttributedString(s)
            part.font = Font.body.monospaced()
            part.backgroundColor = Color(UIColor.systemGray5)
            return Text(part)
        case .inlineFormula(let latex):
            let textColor: UIColor = colorScheme == .dark ? .white : .black
            let mathImage = MTMathImage(latex: latex,
                                        fontSize: fontSize,
                                        textColor: textColor,
                                        labelMode: .text,
                                        textAlignment: .center)
            let (_, image) = mathImage.asImage()
            if let image {
                return Text(Image(uiImage: image))
            }
            return Text("$\(latex)$").font(font.italic()).foregroundColor(.secondary)
        }
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
