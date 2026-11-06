//
//  NoteRepository.swift
//  StudyNotes
//

import Foundation

/// The contract between the view layer and storage.
///
/// Think of this as a Java interface. Views and view models only talk to this protocol,
/// never to a concrete type. This means swapping the in-memory implementation for
/// real storage (Core Data / SwiftData) in step 6 requires changing only one line
/// in StudyNotesApp.swift.
///
/// AnyObject constraint means only classes can conform — appropriate because the
/// repository holds shared mutable state that is passed by reference, not copied.
protocol NoteRepository: AnyObject {
    /// All notes across all folders, in no guaranteed order.
    func allNotes() -> [Note]

    /// All folders in display order (Inbox first, then user-created folders).
    func allFolders() -> [Folder]

    /// Create or update a note (matched by id). Acts like an SQL UPSERT.
    func saveNote(_ note: Note)

    /// Add a new folder. Implementations may ignore duplicates.
    func addFolder(_ folder: Folder)

    /// The Inbox folder. Always exists; never returns nil.
    func inboxFolder() -> Folder
}
