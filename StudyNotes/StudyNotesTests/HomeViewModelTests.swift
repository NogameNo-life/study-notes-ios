//
//  HomeViewModelTests.swift
//  StudyNotesTests
//

import Testing
import Foundation
@testable import StudyNotes

/// HomeViewModel is @MainActor, so the whole suite runs on the main actor.
/// The test target doesn't have implicit MainActor isolation (unlike the app target),
/// so we mark it explicitly here.
@MainActor
struct HomeViewModelTests {

    // MARK: - Recent notes

    @Test func moreThanFiveNotesOnlyShowsFiveRecent() {
        let repo = InMemoryNoteRepository()
        let inbox = repo.inboxFolder()
        let now = Date()
        for i in 1...7 {
            let note = Note(id: UUID(), text: "# Note \(i)", folderId: inbox.id,
                            createdAt: now, modifiedAt: now.addingTimeInterval(Double(i)))
            repo.saveNote(note)
        }
        let vm = HomeViewModel(repository: repo)
        // HomeViewModel.init is nonisolated and does not call refresh().
        // Tests must call refresh() explicitly (HomeView does this in .onAppear).
        vm.refresh()

        #expect(vm.recentNotes.count == 5)
    }

    @Test func recentNotesSortedByMostRecentFirst() {
        let repo = InMemoryNoteRepository()
        let inbox = repo.inboxFolder()
        let base = Date()
        let older = Note(id: UUID(), text: "# Older", folderId: inbox.id,
                         createdAt: base, modifiedAt: base)
        let newer = Note(id: UUID(), text: "# Newer", folderId: inbox.id,
                         createdAt: base, modifiedAt: base.addingTimeInterval(60))
        repo.saveNote(older)
        repo.saveNote(newer)
        let vm = HomeViewModel(repository: repo)
        vm.refresh()

        #expect(vm.recentNotes.first?.title == "Newer")
    }

    // MARK: - Saving notes

    @Test func emptyTextNewNoteIsNotSaved() {
        let repo = InMemoryNoteRepository()
        let vm = HomeViewModel(repository: repo)

        // commitEdit calls refresh() internally, so no explicit call needed here.
        vm.commitEdit(text: "   \n  ", destination: .newNote)

        #expect(repo.allNotes().isEmpty)
    }

    @Test func nonEmptyNewNoteIsSavedToInbox() {
        let repo = InMemoryNoteRepository()
        let vm = HomeViewModel(repository: repo)

        vm.commitEdit(text: "# Hello world", destination: .newNote)

        let notes = repo.allNotes()
        #expect(notes.count == 1)
        #expect(notes[0].folderId == InMemoryNoteRepository.inboxId)
    }

    @Test func editingExistingNoteUpdatesItsText() {
        let repo = InMemoryNoteRepository()
        let inbox = repo.inboxFolder()
        let original = Note(id: UUID(), text: "# Original", folderId: inbox.id,
                            createdAt: Date(), modifiedAt: Date())
        repo.saveNote(original)
        let vm = HomeViewModel(repository: repo)

        vm.commitEdit(text: "# Updated", destination: .existingNote(original))

        let saved = repo.allNotes().first
        #expect(saved?.text == "# Updated")
    }

    // MARK: - Folders

    @Test func createFolderWithCyrillicName() {
        let repo = InMemoryNoteRepository()
        let vm = HomeViewModel(repository: repo)
        // createFolder calls refresh() internally, so we just need an initial refresh
        // to verify the folder list correctly reflects the repo state beforehand.
        vm.refresh()

        let created = vm.createFolder(name: "Алгоритмы")

        #expect(created == true)
        // vm.folders is updated by createFolder → refresh()
        #expect(vm.folders.contains { $0.name == "Алгоритмы" })
    }

    @Test func duplicateFolderNameIsRejected() {
        let repo = InMemoryNoteRepository()
        let vm = HomeViewModel(repository: repo)
        vm.createFolder(name: "Physics")  // calls refresh() internally

        // Same name, different case — still a duplicate.
        let second = vm.createFolder(name: "PHYSICS")

        #expect(second == false)
        #expect(vm.folders.filter { $0.name.lowercased() == "physics" }.count == 1)
    }

    @Test func blankFolderNameIsRejected() {
        let repo = InMemoryNoteRepository()
        let vm = HomeViewModel(repository: repo)
        vm.refresh()  // populate vm.folders from the repo (Inbox only)
        let countBefore = vm.folders.count

        vm.createFolder(name: "   ")  // rejected — no refresh called

        #expect(vm.folders.count == countBefore)
    }

    // MARK: - Note counts

    @Test func noteCountsMatchFolderContents() {
        let repo = InMemoryNoteRepository.withSampleData()
        let vm = HomeViewModel(repository: repo)
        vm.refresh()

        let total = vm.noteCounts.values.reduce(0, +)
        #expect(total == repo.allNotes().count)
    }

    @Test func inboxHasZeroNotesInSampleData() {
        let repo = InMemoryNoteRepository.withSampleData()
        let vm = HomeViewModel(repository: repo)
        vm.refresh()

        let inboxCount = vm.noteCounts[InMemoryNoteRepository.inboxId, default: 0]
        #expect(inboxCount == 0)
    }
}
