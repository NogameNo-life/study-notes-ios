//
//  HomeView.swift
//  StudyNotes
//

import SwiftUI

/// The app's start page. Shows the five most recently edited notes and all folders.
///
/// HomeView is self-contained — it owns its NavigationStack now, but the stack will be
/// removed in step 5 when HomeView becomes the sidebar of a NavigationSplitView.
struct HomeView: View {

    /// @StateObject means HomeView *owns* the view model — it creates it on first render
    /// and keeps it alive for the view's lifetime. Use @ObservedObject when the view model
    /// is passed in from outside and owned by a parent (like Java where the parent holds
    /// the reference and the child only observes).
    @StateObject private var viewModel: HomeViewModel

    /// The navigation path: an array of destinations to push onto the stack.
    /// SwiftUI pops the last element automatically when the user taps "Back".
    /// Programmatic push: editPath.append(.newNote). Clear: editPath.removeAll().
    @State private var editPath: [HomeDestination] = []
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showDocTypeSheet = false

    /// Initialiser accepts an optional pre-built view model for Xcode Previews and tests.
    /// _viewModel = StateObject(wrappedValue:) is the standard pattern for injecting a
    /// @StateObject from outside — the underscore accesses the property wrapper itself.
    /// HomeViewModel.init is nonisolated, so it can safely appear as a default parameter
    /// here without triggering actor-isolation errors. The view model is populated via
    /// .onAppear below, not in its own init.
    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        /// NavigationStack manages the push/pop stack.
        /// path: $editPath gives us programmatic control: append to push, remove to pop.
        NavigationStack(path: $editPath) {
            List {
                recentSection
                foldersSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
            .toolbar { toolbarContent }
            // refresh() cannot be called in HomeViewModel.init (it is @MainActor).
            // .onAppear always runs on the main thread, so it is a safe call site.
            .onAppear { viewModel.refresh() }
            /// .navigationDestination(for:) replaces UINavigationController.show(_:) from UIKit.
            /// For every HomeDestination value pushed onto editPath, SwiftUI calls this closure
            /// to build the destination view — type-safe, no stringly-typed segue identifiers.
            .navigationDestination(for: HomeDestination.self) { destination in
                NoteEditorView(destination: destination) { name, text in
                    viewModel.commitEdit(name: name, text: text, destination: destination)
                }
            }
        }
        .sheet(isPresented: $showDocTypeSheet) {
            docTypeSheet
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Name", text: $newFolderName)
            Button("Create") {
                viewModel.createFolder(name: newFolderName)
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder.")
        }
    }

    // MARK: - Recent section

    @ViewBuilder
    private var recentSection: some View {
        Section("Recent") {
            if viewModel.recentNotes.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.recentNotes) { note in
                    Button {
                        editPath.append(.existingNote(note))
                    } label: {
                        HStack {
                            Text(note.title)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(relativeDate(note.modifiedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("\(note.title), modified \(relativeDate(note.modifiedAt))")
                }
            }
        }
    }

    // MARK: - Folders section

    @ViewBuilder
    private var foldersSection: some View {
        Section {
            ForEach(viewModel.folders) { folder in
                HStack {
                    Text(folder.name)
                    Spacer()
                    Text("\(viewModel.noteCounts[folder.id, default: 0])")
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.5)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(folder.name), \(viewModel.noteCounts[folder.id, default: 0]) notes"
                )
            }
        } header: {
            HStack {
                Text("Folders")
                Spacer()
                // "New folder" is a plain text button — intentionally different from the
                // compose icon in the toolbar so the two actions are not confused.
                Button("New folder") {
                    showNewFolderAlert = true
                }
                .font(.subheadline)
                // List uppercases section headers by default; .textCase(nil) opts out
                // so "New folder" keeps its mixed case.
                .textCase(nil)
            }
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("No notes yet")
                .font(.headline)
            Text("Tap + to write your first note.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                // Search — implemented in step 7.
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search")

            Button {
                // Settings — a later step.
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")

            /// Compose button: shows the "New Document" type picker.
            /// .keyboardShortcut works with hardware keyboards and Mac Catalyst (step 5).
            Button {
                showDocTypeSheet = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("New note")
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    // MARK: - New document sheet

    /// Half-sheet with a 3-column grid of document types.
    /// "Note" is available now. "Chart" and "Diagram" arrive in step 4.
    private var docTypeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("What would you like to create?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // 3-column grid — same layout as the Math Notes reference screenshot.
                // Note and Markdown open the same editor for now. They will diverge in
                // step 4/5 when formatting profiles are added: Note gets a document
                // profile (PDF-first), Markdown gets a plain profile (.md-first).
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    docTypeCard(title: "Note",     icon: "doc.text",                        color: .blue,   isAvailable: true) {
                        showDocTypeSheet = false
                        editPath.append(.newNote(type: .pdf, defaultName: "PDF note"))
                    }
                    docTypeCard(title: "Markdown", icon: "chevron.left.forwardslash.chevron.right", color: .purple, isAvailable: true) {
                        showDocTypeSheet = false
                        editPath.append(.newNote(type: .markdown, defaultName: "Markdown note"))
                    }
                    docTypeCard(title: "Chart",    icon: "chart.bar.fill",                  color: .green,  isAvailable: false, action: {})
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDocTypeSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// One card in the document-type grid.
    /// Unavailable types show a "Soon" badge and cannot be tapped.
    @ViewBuilder
    private func docTypeCard(
        title: String,
        icon: String,
        color: Color,
        isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isAvailable ? color.opacity(0.12) : Color.secondary.opacity(0.1))
                        .frame(height: 72)
                        .overlay {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(isAvailable ? color : .secondary)
                        }
                    if !isAvailable {
                        Text("Soon")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary)
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(isAvailable ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    // MARK: - Helpers

    /// Formats a date as "Today", "Yesterday", or a three-letter weekday name (Mon, Tue…).
    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }
}

// MARK: - Previews

/// @StateObject requires the view model to be injected via init() — the previews
/// below use that initialiser to supply different repository states.
#Preview("With data") {
    HomeView(viewModel: HomeViewModel(repository: InMemoryNoteRepository.withSampleData()))
}

#Preview("Empty state") {
    HomeView(viewModel: HomeViewModel(repository: InMemoryNoteRepository()))
}
