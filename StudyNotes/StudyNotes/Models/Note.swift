//
//  Note.swift
//  StudyNotes
//

import Foundation

/// A single note stored in a folder.
///
/// Plain struct (value type): assigning a Note to a variable copies all its data —
/// the same behaviour as a C++ struct or a Java record. There is no shared mutable state.
/// The repository stores the canonical copy; views receive their own copies via @Published arrays.
nonisolated struct Note: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    /// Explicit display name set by the user. nil means derive the title from the first text line.
    var name: String? = nil
    /// Document class — controls which editor UI and export format are shown.
    var noteType: NoteType = .pdf
    var text: String
    var folderId: UUID
    let createdAt: Date
    var modifiedAt: Date

    /// Display title: explicit name when set; otherwise the first non-blank line of text
    /// with leading '#' markers stripped; falls back to "Untitled".
    var title: String {
        if let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        let raw = text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        // Drop any leading '#' characters (markdown heading markers), then trim spaces.
        let stripped = String(raw.drop(while: { $0 == "#" }))
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? "Untitled" : stripped
    }

    // Identity-based equality and hashing: two Notes are the same note if their ids match,
    // regardless of content. This matches the behaviour you would implement in Java with
    // equals()/hashCode() based on a primary key.
    static func == (lhs: Note, rhs: Note) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
