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
            .heading(level: 1, text: "One"),
            .heading(level: 2, text: "Two"),
            .heading(level: 3, text: "Three"),
        ])
    }

    @Test func headingWithoutTextHasEmptyText() {
        #expect(parser.parse("#") == [.heading(level: 1, text: "")])
        #expect(parser.parse("# ") == [.heading(level: 1, text: "")])
        #expect(parser.parse("##   ") == [.heading(level: 2, text: "")])
    }

    @Test func fourHashesAreAParagraph() {
        #expect(parser.parse("#### Too deep") == [.paragraph("#### Too deep")])
    }

    @Test func hashWithoutSpaceIsAParagraph() {
        #expect(parser.parse("#hashtag") == [.paragraph("#hashtag")])
    }

    // MARK: - Paragraphs

    @Test func consecutiveLinesFormOneParagraphJoinedWithSpaces() {
        #expect(parser.parse("first line\nsecond line") == [.paragraph("first line second line")])
    }

    @Test func blankLinesSeparateParagraphs() {
        let blocks = parser.parse("first\n\n\nsecond")

        #expect(blocks == [.paragraph("first"), .paragraph("second")])
    }

    // MARK: - Lists

    @Test func dashAndAsteriskBothMarkBulletItems() {
        #expect(parser.parse("- one\n- two") == [.bulletList(["one", "two"])])
        #expect(parser.parse("* one\n* two") == [.bulletList(["one", "two"])])
        #expect(parser.parse("- one\n* two") == [.bulletList(["one", "two"])])
    }

    @Test func numberedListDoesNotKeepTheTypedNumbers() {
        let blocks = parser.parse("1. one\n7. two\n10. three")

        #expect(blocks == [.numberedList(["one", "two", "three"])])
    }

    @Test func markerWithoutSpaceIsAParagraph() {
        #expect(parser.parse("-one") == [.paragraph("-one")])
        #expect(parser.parse("1.one") == [.paragraph("1.one")])
        #expect(parser.parse("**bold**") == [.paragraph("**bold**")])
    }

    @Test func blankLineInTheMiddleSplitsAList() {
        #expect(parser.parse("- one\n\n- two") == [.bulletList(["one"]), .bulletList(["two"])])
        #expect(parser.parse("1. one\n\n2. two") == [.numberedList(["one"]), .numberedList(["two"])])
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

        #expect(blocks == [.paragraph("intro"), .codeBlock("let x = 1\n# still code")])
    }

    @Test func textAfterTheClosingFenceIsParsedNormally() {
        let blocks = parser.parse("```\ncode\n```\n# After")

        #expect(blocks == [.codeBlock("code"), .heading(level: 1, text: "After")])
    }

    // MARK: - Blocks without a blank line between them

    @Test func headingStartsANewBlockWithoutABlankLine() {
        let blocks = parser.parse("some text\n# Title\nmore text")

        #expect(blocks == [
            .paragraph("some text"),
            .heading(level: 1, text: "Title"),
            .paragraph("more text"),
        ])
    }

    @Test func listItemStartsANewBlockWithoutABlankLine() {
        #expect(parser.parse("some text\n- one\n- two") == [
            .paragraph("some text"),
            .bulletList(["one", "two"]),
        ])
        #expect(parser.parse("some text\n1. one\n2. two") == [
            .paragraph("some text"),
            .numberedList(["one", "two"]),
        ])
    }

    @Test func switchingTheListKindStartsANewList() {
        let blocks = parser.parse("- one\n1. two\n* three")

        #expect(blocks == [
            .bulletList(["one"]),
            .numberedList(["two"]),
            .bulletList(["three"]),
        ])
    }

    @Test func openingFenceStartsANewBlockWithoutABlankLine() {
        #expect(parser.parse("some text\n```\ncode\n```") == [
            .paragraph("some text"),
            .codeBlock("code"),
        ])
        #expect(parser.parse("- one\n```\ncode\n```") == [
            .bulletList(["one"]),
            .codeBlock("code"),
        ])
    }

    @Test func plainTextAfterAListStartsAParagraph() {
        #expect(parser.parse("- one\nplain text") == [.bulletList(["one"]), .paragraph("plain text")])
    }

    // MARK: - Line endings

    @Test func windowsAndOldMacLineEndingsAreNormalized() {
        let expected: [NoteBlock] = [
            .heading(level: 1, text: "Title"),
            .paragraph("text"),
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
            .heading(level: 1, text: "Sorting"),
            .paragraph("Quicksort is fast on average."),
            .heading(level: 2, text: "Steps"),
            .numberedList(["Pick a pivot", "Partition"]),
            .bulletList(["in place", "not stable"]),
            .codeBlock("sort(a)"),
        ])
    }
}
