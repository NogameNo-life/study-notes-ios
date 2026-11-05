//
//  PDFGenerator.swift
//  StudyNotes
//

import UIKit

/// Turns a parsed note into a paginated A4 PDF document.
struct PDFGenerator {
    /// A4 is 210 × 297 mm. PDF measures in points (1/72 inch), which gives 595.2 × 841.8.
    static let a4PageSize = CGSize(width: 595.2, height: 841.8)

    var pageSize = PDFGenerator.a4PageSize
    var margin: CGFloat = 50
    /// Base font size for body text. Heading sizes scale relative to this value (×2, ×1.67, ×1.33).
    var bodyFontSize: CGFloat = 12

    func makeData(from blocks: [NoteBlock]) -> Data {
        let attributed = buildAttributedString(from: blocks)
        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        let textAreaSize = CGSize(
            width: pageSize.width - 2 * margin,
            height: pageSize.height - 2 * margin
        )

        var containers: [NSTextContainer] = []
        var laidOutGlyphs = 0
        repeat {
            let container = NSTextContainer(size: textAreaSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            let range = layoutManager.glyphRange(for: container)
            if range.length == 0 { break }
            laidOutGlyphs = NSMaxRange(range)
        } while laidOutGlyphs < layoutManager.numberOfGlyphs

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let textOrigin = CGPoint(x: margin, y: margin)
        return renderer.pdfData { context in
            for container in containers {
                context.beginPage()
                let range = layoutManager.glyphRange(for: container)
                layoutManager.drawBackground(forGlyphRange: range, at: textOrigin)
                layoutManager.drawGlyphs(forGlyphRange: range, at: textOrigin)
            }
        }
    }

    func writePDF(
        from blocks: [NoteBlock],
        named fileName: String = "StudyNotes.pdf",
        in directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        try makeData(from: blocks).write(to: url, options: .atomic)
        return url
    }

    // MARK: - Fixed colors (never dynamic — PDF must look identical in light and dark mode)

    private static let textColor = UIColor.black
    private static let codeBackground = UIColor(white: 0.94, alpha: 1)
    private static let blockSpacing: CGFloat = 12

    // MARK: - Block rendering

    private func buildAttributedString(from blocks: [NoteBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in blocks { result.append(attributedString(for: block)) }
        return result
    }

    private func attributedString(for block: NoteBlock) -> NSAttributedString {
        switch block {
        case .heading(let level, let spans):
            return makeInlineString(spans,
                                    fontSize: headingFontSize(level: level),
                                    baseBold: true,
                                    paragraphStyle: defaultStyle())

        case .paragraph(let spans):
            return makeInlineString(spans,
                                    fontSize: bodyFontSize,
                                    baseBold: false,
                                    paragraphStyle: defaultStyle())

        case .bulletList(let items):
            return makeListString(items: items, markerFor: { _ in "• " }, indent: 15)

        case .numberedList(let items):
            return makeListString(items: items, markerFor: { "\($0 + 1). " }, indent: 20)

        case .codeBlock(let code):
            return makeString(code,
                              font: .monospacedSystemFont(ofSize: max(bodyFontSize - 1, 8), weight: .regular),
                              background: Self.codeBackground)

        case .formula(let latex):
            return makeString("$$\(latex)$$", font: italicFont(ofSize: bodyFontSize))
        }
    }

    // MARK: - Inline span rendering

    private func makeInlineString(
        _ spans: [InlineSpan],
        fontSize: CGFloat,
        baseBold: Bool,
        paragraphStyle: NSMutableParagraphStyle
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for span in spans {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: spanFont(span, size: fontSize, baseBold: baseBold),
                .foregroundColor: Self.textColor,
                .paragraphStyle: paragraphStyle,
            ]
            if case .inlineCode = span { attrs[.backgroundColor] = Self.codeBackground }
            result.append(NSAttributedString(string: span.rawText, attributes: attrs))
        }
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: Self.textColor,
            .paragraphStyle: paragraphStyle,
        ]))
        return result
    }

    private func spanFont(_ span: InlineSpan, size: CGFloat, baseBold: Bool) -> UIFont {
        switch span {
        case .text:
            return baseBold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        case .bold:
            return .boldSystemFont(ofSize: size)
        case .italic:
            return italicFont(ofSize: size)
        case .boldItalic:
            return boldItalicFont(ofSize: size)
        case .inlineCode:
            return .monospacedSystemFont(ofSize: max(size - 1, 8), weight: baseBold ? .semibold : .regular)
        }
    }

    // MARK: - List rendering

    private func makeListString(
        items: [[InlineSpan]],
        markerFor: (Int) -> String,
        indent: CGFloat
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (i, item) in items.enumerated() {
            let isLast = i == items.count - 1
            let style = NSMutableParagraphStyle()
            style.headIndent = indent
            style.paragraphSpacing = isLast ? Self.blockSpacing : 4

            result.append(NSAttributedString(
                string: markerFor(i),
                attributes: [
                    .font: UIFont.systemFont(ofSize: bodyFontSize),
                    .foregroundColor: Self.textColor,
                    .paragraphStyle: style,
                ]
            ))
            for span in item {
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: spanFont(span, size: bodyFontSize, baseBold: false),
                    .foregroundColor: Self.textColor,
                    .paragraphStyle: style,
                ]
                if case .inlineCode = span { attrs[.backgroundColor] = Self.codeBackground }
                result.append(NSAttributedString(string: span.rawText, attributes: attrs))
            }
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: UIFont.systemFont(ofSize: bodyFontSize),
                .foregroundColor: Self.textColor,
                .paragraphStyle: style,
            ]))
        }
        return result
    }

    // MARK: - Plain string rendering (code blocks, formulas)

    private func makeString(_ text: String, font: UIFont, background: UIColor? = nil) -> NSAttributedString {
        let style = defaultStyle()
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Self.textColor,
            .paragraphStyle: style,
        ]
        if let bg = background { attrs[.backgroundColor] = bg }
        return NSAttributedString(string: text + "\n", attributes: attrs)
    }

    // MARK: - Helpers

    private func headingFontSize(level: Int) -> CGFloat {
        switch level {
        case 1: return bodyFontSize * 2
        case 2: return (bodyFontSize * 5 / 3).rounded()
        default: return (bodyFontSize * 4 / 3).rounded()
        }
    }

    private func defaultStyle() -> NSMutableParagraphStyle {
        let s = NSMutableParagraphStyle()
        s.paragraphSpacing = Self.blockSpacing
        return s
    }

    private func italicFont(ofSize size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size)
        if let d = base.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }

    private func boldItalicFont(ofSize size: CGFloat) -> UIFont {
        let base = UIFont.boldSystemFont(ofSize: size)
        if let d = base.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }
}
