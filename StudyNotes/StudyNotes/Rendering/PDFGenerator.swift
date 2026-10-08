//
//  PDFGenerator.swift
//  StudyNotes
//

import UIKit

/// Turns plain text into a paginated PDF document.
struct PDFGenerator {
    /// A4 is 210 × 297 mm. PDF measures in points (1/72 inch), which gives 595.2 × 841.8.
    static let a4PageSize = CGSize(width: 595.2, height: 841.8)

    var pageSize = PDFGenerator.a4PageSize
    var margin: CGFloat = 50
    var font = UIFont.systemFont(ofSize: 12)

    /// Renders `text` into PDF data, adding pages until all of the text fits.
    func makeData(from text: String) -> Data {
        // Fixed black text: the default label color would turn white in dark mode.
        let storage = NSTextStorage(
            string: text,
            attributes: [.font: font, .foregroundColor: UIColor.black]
        )
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        let textAreaSize = CGSize(
            width: pageSize.width - 2 * margin,
            height: pageSize.height - 2 * margin
        )

        // One text container per page. The layout manager fills them in order,
        // so we keep adding containers until the last one holds the final glyph.
        var containers: [NSTextContainer] = []
        var laidOutGlyphs = 0
        repeat {
            let container = NSTextContainer(size: textAreaSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)

            let range = layoutManager.glyphRange(for: container)
            // Nothing fits in a page (e.g. margins larger than the page): stop instead of looping forever.
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

    /// Writes the PDF for `text` into `directory` and returns the file's URL.
    func writePDF(
        from text: String,
        named fileName: String = "StudyNotes.pdf",
        in directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        try makeData(from: text).write(to: url, options: .atomic)
        return url
    }
}
