//
//  NoteBlock.swift
//  StudyNotes
//

/// One block-level element of a parsed note. A note is an ordered `[NoteBlock]`,
/// which both the on-screen renderer and the PDF renderer consume.
nonisolated enum NoteBlock: Equatable, Sendable {
    /// A heading of level 1–3. `text` is empty for a heading marker without a title.
    case heading(level: Int, text: String)
    /// Consecutive text lines, joined with a single space.
    case paragraph(String)
    case bulletList([String])
    /// The numbers typed by the user are not kept; the renderer numbers the items.
    case numberedList([String])
    /// The lines between two ``` fences, kept exactly as typed.
    case codeBlock(String)
    /// Reserved for math support. No parser produces this case yet.
    case formula(latex: String)
}
