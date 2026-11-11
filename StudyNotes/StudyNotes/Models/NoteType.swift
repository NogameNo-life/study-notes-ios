//
//  NoteType.swift
//  StudyNotes
//

/// The document class of a note — determines which editor UI is shown and
/// what the primary export format is.
///
/// .pdf   → plain editor + ▶ play button that generates and previews the PDF.
/// .markdown → editor + Edit/Preview segmented control; primary export is a .md file.
///
/// More types (chart, diagram, …) arrive in step 4.
nonisolated enum NoteType: String, Equatable, Hashable, Sendable {
    case pdf
    case markdown
}
