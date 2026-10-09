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

    @Test func shortTextProducesOneA4PageContainingTheText() throws {
        let data = PDFGenerator().makeData(from: "Hello, StudyNotes!")

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)

        let page = try #require(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        #expect(abs(bounds.width - PDFGenerator.a4PageSize.width) < 0.5)
        #expect(abs(bounds.height - PDFGenerator.a4PageSize.height) < 0.5)
        #expect(page.string?.contains("Hello, StudyNotes!") == true)
    }

    @Test func emptyTextStillProducesOnePage() throws {
        let data = PDFGenerator().makeData(from: "")

        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)
    }

    @Test func longTextFlowsOntoSeveralPagesWithoutLosingTheEnd() throws {
        let lines = (1...200).map { "Line \($0)" }
        let data = PDFGenerator().makeData(from: lines.joined(separator: "\n"))

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

        let url = try PDFGenerator().writePDF(from: "Saved note", named: "Note.pdf", in: directory)

        #expect(url.lastPathComponent == "Note.pdf")
        #expect(PDFDocument(url: url)?.pageCount == 1)
    }
}
