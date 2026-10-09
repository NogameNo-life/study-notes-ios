//
//  SimpleMarkdownParser.swift
//  StudyNotes
//

import Foundation

/// Parses a small markdown subset: `#` headings (levels 1–3), paragraphs,
/// `- ` / `* ` bullet lists, `1. ` numbered lists and ``` code blocks.
nonisolated struct SimpleMarkdownParser: NoteParser {
    private static let fence = "```"

    /// What a single line means when it is outside a code block.
    private nonisolated enum Line {
        case blank
        case fence
        case heading(level: Int, text: String)
        case bullet(String)
        case numbered(String)
        case text(String)
    }

    func parse(_ text: String) -> [NoteBlock] {
        // Swift treats "\r\n" as one Character, so splitting on "\n" alone would miss it.
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
        // A final newline ends the last line; it does not start another, empty one.
        if lines.last == "" {
            lines.removeLast()
        }

        var blocks: [NoteBlock] = []
        // The paragraph or list still being collected.
        var current: NoteBlock?
        // Non-nil while inside a code block.
        var codeLines: [String]?

        func closeCurrent() {
            if let block = current {
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
                blocks.append(.heading(level: level, text: text))
            case .bullet(let item):
                if case .bulletList(let items) = current {
                    current = .bulletList(items + [item])
                } else {
                    closeCurrent()
                    current = .bulletList([item])
                }
            case .numbered(let item):
                if case .numberedList(let items) = current {
                    current = .numberedList(items + [item])
                } else {
                    closeCurrent()
                    current = .numberedList([item])
                }
            case .text(let text):
                if case .paragraph(let existing) = current {
                    current = .paragraph(existing + " " + text)
                } else {
                    closeCurrent()
                    current = .paragraph(text)
                }
            }
        }

        closeCurrent()
        // An unclosed code block runs to the end of the note.
        if let codeLines {
            blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
        }
        return blocks
    }

    private func classify(_ line: String) -> Line {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .blank
        }
        // Anything after the opening fence (a language name, for example) is ignored.
        if line.hasPrefix(Self.fence) {
            return .fence
        }
        if let heading = heading(in: line) {
            return .heading(level: heading.level, text: heading.text)
        }
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return .bullet(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
        }
        if let item = numberedItem(in: line) {
            return .numbered(item)
        }
        return .text(trimmed)
    }

    /// Matches 1–3 `#` characters followed by a space or the end of the line.
    private func heading(in line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard (1...3).contains(hashes.count) else { return nil }

        let rest = line.dropFirst(hashes.count)
        guard rest.isEmpty || rest.hasPrefix(" ") else { return nil }

        return (hashes.count, rest.trimmingCharacters(in: .whitespaces))
    }

    /// Matches one or more digits followed by ". ", and returns the item text.
    private func numberedItem(in line: String) -> String? {
        let digits = line.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty else { return nil }

        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }

        return rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
    }
}
