# Decision log

Entries are added at the end of each task. Date format: YYYY-MM-DD.

---

## 2026-11-06 — Start page (step 3)

### App opens to Home, not to the editor

**Decision:** `StudyNotesApp` root is `HomeView`, not `ContentView`.

**Reason:** The app needs a note list to be useful. Opening directly to a blank editor
made sense as a scaffold but would confuse users who have more than one note.

**Alternatives considered:** Keep `ContentView` as root and add navigation from it —
rejected because the editor is not the right hub view.

---

### "New note" button in the top-right toolbar as a compose icon

**Decision:** `ToolbarItemGroup(.navigationBarTrailing)` with SF Symbol
`square.and.pencil`, accessibility label "New note", shortcut `Cmd+N`.

**Reason:** The compose icon is the iOS convention (Notes, Mail). Top-right keeps
the title area clean. `Cmd+N` works with hardware keyboards and Mac Catalyst.

**Alternatives considered:**
- Floating action button (FAB): iOS convention favours toolbar buttons, not FABs.
- Bottom tab bar button: no tabs exist yet; deferred.

---

### Inbox folder always exists and cannot be deleted

**Decision:** `InMemoryNoteRepository.init()` creates Inbox with the fixed UUID
`00000000-0000-0000-0000-000000000001`. The `isInbox` flag prevents deletion in
the view model.

**Reason:** New notes with no chosen folder must go somewhere. A fixed UUID means
code can always find Inbox without searching by name.

**Alternative considered:** Auto-create Inbox on first save — rejected because it
adds branching logic everywhere and leaves the empty-state view without a folder row.

---

### Folders are flat (no nesting)

**Decision:** `Folder` has no `parentId`. Nesting is deferred to a later step.

**Reason:** Flat folders cover the common case and avoid extra UI/data complexity
that is not needed for the start-page step.

---

### In-memory repository for step 3

**Decision:** `InMemoryNoteRepository` behind the `NoteRepository` protocol.
All views and view models use `any NoteRepository`, never the concrete type.

**Reason:** Real storage (Core Data / SwiftData) is a separate design decision
belonging to step 6. The protocol boundary means the swap is a one-line change
in `StudyNotesApp.swift`.

**Alternatives considered:**
- Core Data now: too early, would block the UI step and require an iOS 17 target decision.
- UserDefaults: not suitable for structured note data.
