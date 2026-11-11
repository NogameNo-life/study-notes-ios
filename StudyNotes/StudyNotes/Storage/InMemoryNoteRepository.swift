//
//  InMemoryNoteRepository.swift
//  StudyNotes
//

import Foundation

/// In-memory implementation of NoteRepository.
/// Data is lost when the app terminates. This satisfies the protocol for the start-page step;
/// real persistence replaces it in step 6.
final class InMemoryNoteRepository: NoteRepository {

    /// Fixed UUID for Inbox so the app can always find it without searching.
    /// The UUID string is arbitrary but stable across runs.
    static let inboxId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var noteMap: [UUID: Note] = [:]
    private var folderMap: [UUID: Folder] = [:]
    // folderOrder preserves display order: Inbox first, then user-created folders.
    private var folderOrder: [UUID] = []

    init() {
        let inbox = Folder(id: Self.inboxId, name: "Inbox", isInbox: true)
        folderMap[inbox.id] = inbox
        folderOrder = [inbox.id]
    }

    // MARK: - NoteRepository

    func allNotes() -> [Note] {
        Array(noteMap.values)
    }

    func allFolders() -> [Folder] {
        folderOrder.compactMap { folderMap[$0] }
    }

    func saveNote(_ note: Note) {
        noteMap[note.id] = note
    }

    func addFolder(_ folder: Folder) {
        guard folderMap[folder.id] == nil else { return }
        folderMap[folder.id] = folder
        folderOrder.append(folder.id)
    }

    func inboxFolder() -> Folder {
        // Inbox is always present — created in init() and never removed.
        folderMap[Self.inboxId]!
    }
}

// MARK: - Sample data

extension InMemoryNoteRepository {

    /// Returns a repository pre-populated with sample notes and folders.
    /// Used for Xcode Previews and manual testing.
    static func withSampleData() -> InMemoryNoteRepository {
        let repo = InMemoryNoteRepository()
        let now = Date()

        let algorithms  = Folder(id: UUID(), name: "Algorithms",  isInbox: false)
        let electronics = Folder(id: UUID(), name: "Electronics", isInbox: false)
        // Long Cyrillic name — exercises text truncation in the UI.
        let mathAnalysis = Folder(id: UUID(),
                                  name: "Лекции по Математическому Анализу",
                                  isInbox: false)
        [algorithms, electronics, mathAnalysis].forEach { repo.addFolder($0) }

        // Each tuple: (markdown text, folder, days since last edit).
        // The first line of text becomes the note's title.
        let samples: [(String, UUID, Double)] = [
            ("# Бинарные деревья\n\nДерево — связный граф без циклов.", algorithms.id,  0),
            ("# Docker cheatsheet\n\n```\ndocker ps -a\ndocker run --rm\n```", algorithms.id, 1),
            ("# Lab 3: circuits\n\nKirchhoff's voltage law: sum of voltages = 0.", electronics.id, 2),
            ("# Quicksort\n\nAverage complexity: $$O(n \\log n)$$", algorithms.id, 3),
            ("# Ohm's Law\n\nV = IR", electronics.id, 4),
            ("# Hash tables\n\nO(1) average lookup.", algorithms.id, 5),
            ("# Интеграл Лебега\n\nОпределение меры Лебега.", mathAnalysis.id, 6),
        ]

        for (text, folderId, daysAgo) in samples {
            let modified = now.addingTimeInterval(-daysAgo * 86_400)
            let created  = modified.addingTimeInterval(-3_600)
            let note = Note(id: UUID(), noteType: .markdown, text: text, folderId: folderId,
                            createdAt: created, modifiedAt: modified)
            repo.saveNote(note)
        }

        return repo
    }
}
