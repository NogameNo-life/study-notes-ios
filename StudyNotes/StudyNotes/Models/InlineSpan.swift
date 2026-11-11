//
//  InlineSpan.swift
//  StudyNotes
//

/// One styled run of text within a block-level element.
/// A `NoteBlock` that carries user text holds `[InlineSpan]`, and each span
/// records both the content and its visual weight.
nonisolated enum InlineSpan: Equatable, Sendable {
    case text(String)
    case bold(String)
    case italic(String)
    case boldItalic(String)
    case inlineCode(String)
    /// A LaTeX math expression delimited by single `$...$`.
    /// Rendered inline with text at the surrounding font size.
    case inlineFormula(String)

    /// The raw text content of the span, without any formatting markers.
    var rawText: String {
        switch self {
        case .text(let s), .bold(let s), .italic(let s),
             .boldItalic(let s), .inlineCode(let s), .inlineFormula(let s): return s
        }
    }
}
