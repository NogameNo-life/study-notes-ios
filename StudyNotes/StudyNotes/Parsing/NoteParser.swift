//
//  NoteParser.swift
//  StudyNotes
//

/// Turns the raw text of a note into blocks. Implementations must be pure:
/// the same text always gives the same blocks, with no UI or I/O involved.
nonisolated protocol NoteParser: Sendable {
    func parse(_ text: String) -> [NoteBlock]
}
