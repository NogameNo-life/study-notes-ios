//
//  SimpleMarkdownParserTests.swift
//  StudyNotesTests
//

import Testing
@testable import StudyNotes

struct SimpleMarkdownParserTests {
    private let parser = SimpleMarkdownParser()

    // MARK: - Empty input

    @Test func emptyTextProducesNoBlocks() {
        #expect(parser.parse("") == [])
    }

    @Test func whitespaceOnlyTextProducesNoBlocks() {
        #expect(parser.parse("  \n\n\t\n") == [])
    }

    // MARK: - Headings

    @Test func headingsOfLevelsOneToThree() {
        let blocks = parser.parse("# One\n## Two\n### Three")

        #expect(blocks == [
            .heading(level: 1, spans: [.text("One")]),
            .heading(level: 2, spans: [.text("Two")]),
            .heading(level: 3, spans: [.text("Three")]),
        ])
    }

    @Test func headingWithoutTextHasEmptySpans() {
        #expect(parser.parse("#") == [.heading(level: 1, spans: [])])
        #expect(parser.parse("# ") == [.heading(level: 1, spans: [])])
        #expect(parser.parse("##   ") == [.heading(level: 2, spans: [])])
    }

    @Test func fourHashesAreAParagraph() {
        #expect(parser.parse("#### Too deep") == [.paragraph([.text("#### Too deep")])])
    }

    @Test func hashWithoutSpaceIsAParagraph() {
        #expect(parser.parse("#hashtag") == [.paragraph([.text("#hashtag")])])
    }

    // MARK: - Paragraphs

    @Test func consecutiveLinesFormOneParagraphJoinedWithSpaces() {
        #expect(parser.parse("first line\nsecond line") == [.paragraph([.text("first line second line")])])
    }

    @Test func blankLinesSeparateParagraphs() {
        let blocks = parser.parse("first\n\n\nsecond")

        #expect(blocks == [.paragraph([.text("first")]), .paragraph([.text("second")])])
    }

    // MARK: - Lists

    @Test func dashAndAsteriskBothMarkBulletItems() {
        #expect(parser.parse("- one\n- two") == [.bulletList([[.text("one")], [.text("two")]])])
        #expect(parser.parse("* one\n* two") == [.bulletList([[.text("one")], [.text("two")]])])
        #expect(parser.parse("- one\n* two") == [.bulletList([[.text("one")], [.text("two")]])])
    }

    @Test func numberedListDoesNotKeepTheTypedNumbers() {
        let blocks = parser.parse("1. one\n7. two\n10. three")

        #expect(blocks == [.numberedList([[.text("one")], [.text("two")], [.text("three")]])])
    }

    @Test func markerWithoutSpaceIsAParagraph() {
        #expect(parser.parse("-one") == [.paragraph([.text("-one")])])
        #expect(parser.parse("1.one") == [.paragraph([.text("1.one")])])
    }

    @Test func blankLineInTheMiddleSplitsAList() {
        #expect(parser.parse("- one\n\n- two") == [
            .bulletList([[.text("one")]]),
            .bulletList([[.text("two")]]),
        ])
        #expect(parser.parse("1. one\n\n2. two") == [
            .numberedList([[.text("one")]]),
            .numberedList([[.text("two")]]),
        ])
    }

    // MARK: - Code blocks

    @Test func codeBlockKeepsItsLinesExactlyAsTyped() {
        let blocks = parser.parse("```\n# not a heading\n\n  - not a list\n```")

        #expect(blocks == [.codeBlock("# not a heading\n\n  - not a list")])
    }

    @Test func textAfterTheOpeningFenceIsIgnored() {
        #expect(parser.parse("```swift\nlet x = 1\n```") == [.codeBlock("let x = 1")])
    }

    @Test func emptyCodeBlock() {
        #expect(parser.parse("```\n```") == [.codeBlock("")])
    }

    @Test func unclosedCodeBlockRunsToTheEndOfTheText() {
        let blocks = parser.parse("intro\n```\nlet x = 1\n# still code\n")

        #expect(blocks == [.paragraph([.text("intro")]), .codeBlock("let x = 1\n# still code")])
    }

    @Test func textAfterTheClosingFenceIsParsedNormally() {
        let blocks = parser.parse("```\ncode\n```\n# After")

        #expect(blocks == [.codeBlock("code"), .heading(level: 1, spans: [.text("After")])])
    }

    // MARK: - Blocks without a blank line between them

    @Test func headingStartsANewBlockWithoutABlankLine() {
        let blocks = parser.parse("some text\n# Title\nmore text")

        #expect(blocks == [
            .paragraph([.text("some text")]),
            .heading(level: 1, spans: [.text("Title")]),
            .paragraph([.text("more text")]),
        ])
    }

    @Test func listItemStartsANewBlockWithoutABlankLine() {
        #expect(parser.parse("some text\n- one\n- two") == [
            .paragraph([.text("some text")]),
            .bulletList([[.text("one")], [.text("two")]]),
        ])
        #expect(parser.parse("some text\n1. one\n2. two") == [
            .paragraph([.text("some text")]),
            .numberedList([[.text("one")], [.text("two")]]),
        ])
    }

    @Test func switchingTheListKindStartsANewList() {
        let blocks = parser.parse("- one\n1. two\n* three")

        #expect(blocks == [
            .bulletList([[.text("one")]]),
            .numberedList([[.text("two")]]),
            .bulletList([[.text("three")]]),
        ])
    }

    @Test func openingFenceStartsANewBlockWithoutABlankLine() {
        #expect(parser.parse("some text\n```\ncode\n```") == [
            .paragraph([.text("some text")]),
            .codeBlock("code"),
        ])
        #expect(parser.parse("- one\n```\ncode\n```") == [
            .bulletList([[.text("one")]]),
            .codeBlock("code"),
        ])
    }

    @Test func plainTextAfterAListStartsAParagraph() {
        #expect(parser.parse("- one\nplain text") == [
            .bulletList([[.text("one")]]),
            .paragraph([.text("plain text")]),
        ])
    }

    // MARK: - Line endings

    @Test func windowsAndOldMacLineEndingsAreNormalized() {
        let expected: [NoteBlock] = [
            .heading(level: 1, spans: [.text("Title")]),
            .paragraph([.text("text")]),
            .codeBlock("a\nb"),
        ]

        #expect(parser.parse("# Title\r\n\r\ntext\r\n```\r\na\r\nb\r\n```\r\n") == expected)
        #expect(parser.parse("# Title\r\rtext\r```\ra\rb\r```\r") == expected)
    }

    // MARK: - Whole note

    @Test func mixedNote() {
        let text = """
        # Sorting

        Quicksort is fast
        on average.

        ## Steps
        1. Pick a pivot
        2. Partition

        - in place
        * not stable

        ```
        sort(a)
        ```
        """

        #expect(parser.parse(text) == [
            .heading(level: 1, spans: [.text("Sorting")]),
            .paragraph([.text("Quicksort is fast on average.")]),
            .heading(level: 2, spans: [.text("Steps")]),
            .numberedList([[.text("Pick a pivot")], [.text("Partition")]]),
            .bulletList([[.text("in place")], [.text("not stable")]]),
            .codeBlock("sort(a)"),
        ])
    }

    // MARK: - Inline formatting

    @Test func boldMarkerProducesBoldSpan() {
        #expect(parser.parse("**bold**") == [.paragraph([.bold("bold")])])
    }

    @Test func italicMarkerProducesItalicSpan() {
        #expect(parser.parse("*italic*") == [.paragraph([.italic("italic")])])
    }

    @Test func tripleStarProducesBoldItalicSpan() {
        #expect(parser.parse("***bi***") == [.paragraph([.boldItalic("bi")])])
    }

    @Test func backtickProducesInlineCodeSpan() {
        #expect(parser.parse("`code`") == [.paragraph([.inlineCode("code")])])
    }

    @Test func mixedInlineSpansInOneParagraph() {
        #expect(parser.parse("hello **world** and *you*") == [.paragraph([
            .text("hello "),
            .bold("world"),
            .text(" and "),
            .italic("you"),
        ])])
    }

    @Test func unclosedInlineMarkerIsPlainText() {
        #expect(parser.parse("**no close") == [.paragraph([.text("**no close")])])
    }

    @Test func boldInHeadingSpans() {
        #expect(parser.parse("# **Title**") == [.heading(level: 1, spans: [.bold("Title")])])
    }

    @Test func italicInListItem() {
        #expect(parser.parse("- *item*") == [.bulletList([[.italic("item")]])])
    }

    @Test func inlineCodeSpanInParagraph() {
        #expect(parser.parse("call `foo()`") == [.paragraph([.text("call "), .inlineCode("foo()")])])
    }

    // MARK: - Formula blocks

    @Test func doubleDollarSignLineProducesFormulaBlock() {
        #expect(parser.parse("$$E = mc^2$$") == [.formula(latex: "E = mc^2")])
    }

    @Test func formulaLatexContentIsTrimmed() {
        #expect(parser.parse("$$  E = mc^2  $$") == [.formula(latex: "E = mc^2")])
    }

    @Test func emptyDoubleDollarIsAParagraph() {
        // `$$$$` has no content between the delimiters — treated as plain text.
        #expect(parser.parse("$$$$") == [.paragraph([.text("$$$$")])])
    }

    @Test func singleDollarIsNotAFormula() {
        // Inline `$...$` is not supported at the block level.
        #expect(parser.parse("$E = mc^2$") == [.paragraph([.text("$E = mc^2$")])])
    }

    @Test func formulaSeparatedFromSurroundingBlocksByBlankLines() {
        let blocks = parser.parse("# Physics\n\n$$E = mc^2$$\n\nSee above.")
        #expect(blocks == [
            .heading(level: 1, spans: [.text("Physics")]),
            .formula(latex: "E = mc^2"),
            .paragraph([.text("See above.")]),
        ])
    }

    @Test func formulaNextToOtherBlocksWithoutBlankLine() {
        let blocks = parser.parse("intro\n$$x^2$$\n# After")
        #expect(blocks == [
            .paragraph([.text("intro")]),
            .formula(latex: "x^2"),
            .heading(level: 1, spans: [.text("After")]),
        ])
    }

    @Test func cyrillicFormulaLabel() {
        // A formula can contain arbitrary LaTeX — the parser does not validate its content.
        #expect(parser.parse("$$\\text{Привет}$$") == [.formula(latex: "\\text{Привет}")])
    }
}
