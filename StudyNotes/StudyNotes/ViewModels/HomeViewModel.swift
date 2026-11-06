//
//  HomeViewModel.swift
//  StudyNotes
//

import Foundation
import Combine

/// The destination pushed onto the navigation stack from HomeView.
///
/// Hashable is required by NavigationStack's .navigationDestination(for:) API —
/// the stack uses the value as a dictionary key to find the right destination view.
/// In Java terms this is a sealed interface; in C++ it is a std::variant.
enum HomeDestination: Hashable {
    case newNote
    case existingNote(Note)  // Note is Hashable via its id
}

/// View model for HomeView.
///
/// ObservableObject is the iOS 16 equivalent of a ViewModel with LiveData (Android) or
/// a Java subject/observer. @Published properties notify SwiftUI automatically whenever
/// they change — you never call notifyObservers() by hand.
///
/// @MainActor ensures all mutations happen on the main thread, matching the implicit
/// MainActor isolation of the app target. The annotation is explicit here for clarity.
@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var recentNotes: [Note] = []
    @Published private(set) var folders: [Folder] = []
    /// Note count per folder id. Missing key means zero notes.
    @Published private(set) var noteCounts: [UUID: Int] = [:]

    /// `any NoteRepository` is a Swift existential — the concrete type is unknown at
    /// compile time, resolved at runtime. Equivalent to a Java interface reference.
    private let repository: any NoteRepository

    /// `nonisolated` lets this init be called from non-MainActor contexts — specifically,
    /// as a default parameter expression in HomeView.init and from test code.
    /// Without `nonisolated`, the implicit @MainActor on the class makes this init
    /// @MainActor-isolated, which causes a compile error when it appears as a default
    /// parameter in a struct initialiser (nonisolated by the protocol conformance).
    ///
    /// Construction and population are separated: call refresh() after init to load data.
    /// HomeView does this in .onAppear; tests do it explicitly.
    nonisolated init(repository: any NoteRepository = InMemoryNoteRepository()) {
        self.repository = repository
        // refresh() is @MainActor and cannot be called here.
        // HomeView calls it in .onAppear; tests call it directly.
    }

    // MARK: - Read

    func refresh() {
        let all = repository.allNotes()
        recentNotes = Array(
            all.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5)
        )
        folders = repository.allFolders()
        noteCounts = Dictionary(grouping: all, by: \.folderId)
            .mapValues(\.count)
    }

    // MARK: - Write

    /// Save the text that the editor produced back to the repository.
    ///
    /// - `.newNote`: creates a note in Inbox only when text is non-empty.
    ///   An empty note is never created.
    /// - `.existingNote`: updates the note if text is non-empty; silently ignores empty text
    ///   (a future step can add "delete if emptied" behaviour).
    func commitEdit(text: String, destination: HomeDestination) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch destination {
        case .newNote:
            guard !trimmed.isEmpty else { return }
            let inbox = repository.inboxFolder()
            let now = Date()
            let note = Note(id: UUID(), text: text, folderId: inbox.id,
                            createdAt: now, modifiedAt: now)
            repository.saveNote(note)

        case .existingNote(var note):
            guard !trimmed.isEmpty else { return }
            note.text = text
            note.modifiedAt = Date()
            repository.saveNote(note)
        }
        refresh()
    }

    /// Creates a new folder.
    /// Returns `true` on success, `false` when the name is blank or already exists
    /// (case-insensitive comparison).
    @discardableResult
    func createFolder(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let duplicate = folders.contains {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !duplicate else { return false }
        repository.addFolder(Folder(id: UUID(), name: trimmed, isInbox: false))
        refresh()
        return true
    }
}
