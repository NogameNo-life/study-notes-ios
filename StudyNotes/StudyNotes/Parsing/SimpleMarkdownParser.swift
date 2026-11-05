//
//  SimpleMarkdownParser.swift
//  StudyNotes
//

import Foundation

/// Parses a small markdown subset: `#` headings (levels 1–3), paragraphs,
/// `- ` / `* ` bullet lists, `1. ` numbered lists, ``` code blocks,
/// and inline `**bold**`, `*italic*`, `***bold-italic***`, `` `code` ``.
nonisolated struct SimpleMarkdownParser: NoteParser {
    private static let fence = "```"

    private nonisolated enum Line {
        case blank
        case fence
        case heading(level: Int, text: String)
        case bullet(String)
        case numbered(String)
        case text(String)
    }

    func parse(_ text: String) -> [NoteBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }

        var blocks: [NoteBlock] = []
        var current: NoteBlock?
        // Paragraph lines are buffered as a String and converted to spans on flush,
        // so multi-line paragraphs get one inline-parse pass over the joined text.
        var paragraphBuffer: String?
        var codeLines: [String]?

        func closeCurrent() {
            if let buf = paragraphBuffer {
                blocks.append(.paragraph(parseInline(buf)))
                paragraphBuffer = nil
            } else if let block = current {
                blocks.append(block)
                current = nil
            }
        }

        for line in lines {
            if let openCodeLines = codeLines {
                if line.trimmingCharacters(in: .whitespaces) == Self.fence {
                    blocks.append(.codeBlock(openCodeLines.joined(separator: "\n")))
                    codeLines = nil
                } else {
                    codeLines?.append(line)
                }
                continue
            }

            switch classify(line) {
            case .blank:
                closeCurrent()

            case .fence:
                closeCurrent()
                codeLines = []

            case .heading(let level, let text):
                closeCurrent()
                blocks.append(.heading(level: level, spans: parseInline(text)))

            case .bullet(let item):
                if case .bulletList(let items) = current {
                    current = .bulletList(items + [parseInline(item)])
                } else {
                    closeCurrent()
                    current = .bulletList([parseInline(item)])
                }

            case .numbered(let item):
                if case .numberedList(let items) = current {
                    current = .numberedList(items + [parseInline(item)])
                } else {
                    closeCurrent()
                    current = .numberedList([parseInline(item)])
                }

            case .text(let text):
                if paragraphBuffer != nil {
                    paragraphBuffer! += " " + text
                } else {
                    closeCurrent()
                    paragraphBuffer = text
                }
            }
        }

        closeCurrent()
        if let codeLines {
            blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
        }
        return blocks
    }

    // MARK: - Inline parsing

    /// Splits `text` into styled spans by scanning for `***`, `**`, `*`, and `` ` `` markers.
    /// Unmatched or unclosed markers are treated as plain text.
    func parseInline(_ text: String) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        var i = text.startIndex
        var plainStart = i

        func flushPlain(upTo end: String.Index) {
            if plainStart < end {
                spans.append(.text(String(text[plainStart..<end])))
            }
        }

        while i < text.endIndex {
            // Check longest marker first to avoid `**` stealing the first two stars of `***`.
            if let (content, after) = matchInline(text, at: i, open: "***", close: "***") {
                flushPlain(upTo: i)
                spans.append(.boldItalic(content))
                i = after; plainStart = i
            } else if let (content, after) = matchInline(text, at: i, open: "**", close: "**") {
                flushPlain(upTo: i)
                spans.append(.bold(content))
                i = after; plainStart = i
            } else if let (content, after) = matchInline(text, at: i, open: "*", close: "*") {
                flushPlain(upTo: i)
                spans.append(.italic(content))
                i = after; plainStart = i
            } else if let (content, after) = matchInline(text, at: i, open: "`", close: "`") {
                flushPlain(upTo: i)
                spans.append(.inlineCode(content))
                i = after; plainStart = i
            } else {
                i = text.index(after: i)
            }
        }
        flushPlain(upTo: text.endIndex)
        return spans
    }

    /// Returns the content between `open` and the next `close` that follows it,
    /// plus the index after `close`. Returns nil when `open` is not at `index`,
    /// when no `close` follows, or when the content would be empty.
    private func matchInline(
        _ text: String,
        at index: String.Index,
        open: String,
        close: String
    ) -> (content: String, after: String.Index)? {
        guard text[index...].hasPrefix(open) else { return nil }
        let contentStart = text.index(index, offsetBy: open.count)
        guard contentStart < text.endIndex,
              let closeRange = text.range(of: close, range: contentStart..<text.endIndex),
              closeRange.lowerBound > contentStart
        else { return nil }
        return (String(text[contentStart..<closeRange.lowerBound]), closeRange.upperBound)
    }

    // MARK: - Block-level classification

    private func classify(_ line: String) -> Line {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .blank }
        if line.hasPrefix(Self.fence) { return .fence }
        if let heading = heading(in: line) {
            return .heading(level: heading.level, text: heading.text)
        }
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return .bullet(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
        }
        if let item = numberedItem(in: line) { return .numbered(item) }
        return .text(trimmed)
    }

    private func heading(in line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard (1...3).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.isEmpty || rest.hasPrefix(" ") else { return nil }
        return (hashes.count, rest.trimmingCharacters(in: .whitespaces))
    }

    private func numberedItem(in line: String) -> String? {
        let digits = line.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
    }
}
