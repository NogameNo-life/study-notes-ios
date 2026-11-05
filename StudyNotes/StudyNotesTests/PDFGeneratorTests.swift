//
//  PDFGeneratorTests.swift
//  StudyNotesTests
//

import Foundation
import PDFKit
import Testing
@testable import StudyNotes

@MainActor
struct PDFGeneratorTests {

    // MARK: - Layout

    @Test func shortTextProducesOneA4PageContainingTheText() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([.text("Hello, StudyNotes!")])])

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)

        let page = try #require(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        #expect(abs(bounds.width - PDFGenerator.a4PageSize.width) < 0.5)
        #expect(abs(bounds.height - PDFGenerator.a4PageSize.height) < 0.5)
        #expect(page.string?.contains("Hello, StudyNotes!") == true)
    }

    @Test func emptyBlocksStillProducesOnePage() throws {
        let data = PDFGenerator().makeData(from: [])

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)
    }

    @Test func longTextFlowsOntoSeveralPagesWithoutLosingTheEnd() throws {
        let blocks: [NoteBlock] = (1...200).map { .paragraph([.text("Line \($0)")]) }
        let data = PDFGenerator().makeData(from: blocks)

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount > 1)
        #expect(document.string?.contains("Line 1") == true)
        #expect(document.string?.contains("Line 200") == true)
    }

    @Test func writePDFCreatesAReadableFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try PDFGenerator().writePDF(
            from: [.paragraph([.text("Saved note")])],
            named: "Note.pdf",
            in: directory
        )

        #expect(url.lastPathComponent == "Note.pdf")
        #expect(PDFDocument(url: url)?.pageCount == 1)
    }

    // MARK: - Block-type rendering

    @Test func cyrillicTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([.text("Привет, мир!")])])

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)
        #expect(document.string?.contains("Привет, мир!") == true)
    }

    @Test func headingTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.heading(level: 1, spans: [.text("Introduction")])])

        let page = try #require(PDFDocument(data: data)?.page(at: 0))
        #expect(page.string?.contains("Introduction") == true)
    }

    @Test func bulletMarkersAndTextAppearInPDF() throws {
        let data = PDFGenerator().makeData(from: [.bulletList([[.text("Apple")], [.text("Banana")]])])

        let text = try #require(PDFDocument(data: data)?.string)
        #expect(text.contains("•"))
        #expect(text.contains("Apple"))
        #expect(text.contains("Banana"))
    }

    @Test func numberedItemMarkersAndTextAppearInPDF() throws {
        let data = PDFGenerator().makeData(from: [.numberedList([[.text("First")], [.text("Second")]])])

        let text = try #require(PDFDocument(data: data)?.string)
        #expect(text.contains("1."))
        #expect(text.contains("First"))
        #expect(text.contains("2."))
        #expect(text.contains("Second"))
    }

    @Test func codeBlockTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.codeBlock("let x = 42")])
        #expect(PDFDocument(data: data)?.string?.contains("let x = 42") == true)
    }

    @Test func formulaDrawsRawLatexText() throws {
        let data = PDFGenerator().makeData(from: [.formula(latex: "E=mc^2")])

        let text = try #require(PDFDocument(data: data)?.string)
        #expect(text.contains("E=mc^2"))
        #expect(text.contains("$$"))
    }

    // MARK: - Inline span rendering

    @Test func boldSpanTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([.bold("Bold text")])])
        #expect(PDFDocument(data: data)?.string?.contains("Bold text") == true)
    }

    @Test func italicSpanTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([.italic("Italic text")])])
        #expect(PDFDocument(data: data)?.string?.contains("Italic text") == true)
    }

    @Test func boldItalicSpanTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([.boldItalic("BoldItalic")])])
        #expect(PDFDocument(data: data)?.string?.contains("BoldItalic") == true)
    }

    @Test func inlineCodeSpanTextAppearsInPDF() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([.text("val = "), .inlineCode("x")])])
        let text = try #require(PDFDocument(data: data)?.string)
        #expect(text.contains("val ="))
        #expect(text.contains("x"))
    }

    @Test func mixedSpansProduceAllTextInPDF() throws {
        let data = PDFGenerator().makeData(from: [.paragraph([
            .text("plain "),
            .bold("bold "),
            .italic("italic"),
        ])])
        let text = try #require(PDFDocument(data: data)?.string)
        #expect(text.contains("plain"))
        #expect(text.contains("bold"))
        #expect(text.contains("italic"))
    }

    // MARK: - Configurable formatting

    @Test func customBodyFontSizeProducesValidPDF() throws {
        var generator = PDFGenerator()
        generator.bodyFontSize = 16
        let data = generator.makeData(from: [.paragraph([.text("Large text")])])
        let doc = try #require(PDFDocument(data: data))
        #expect(doc.pageCount >= 1)
        #expect(doc.string?.contains("Large text") == true)
    }

    @Test func customMarginProducesValidPDF() throws {
        var generator = PDFGenerator()
        generator.margin = 72
        let data = generator.makeData(from: [.paragraph([.text("Wide margin")])])
        let doc = try #require(PDFDocument(data: data))
        #expect(doc.pageCount >= 1)
        #expect(doc.string?.contains("Wide margin") == true)
    }
}
