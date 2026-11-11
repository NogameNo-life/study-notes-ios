# CLAUDE.md

This file guides Claude Code (claude.ai/code) when working in this repository.
Read it fully at the start of every session.

## Goals

StudyNotes is a universal iOS note app for writing beautiful notes fast, so the user does not
waste time formatting afterwards, or rewriting text into markdown, or struggling to type
formulas and code.

The first audience is programmers and engineers: code blocks with syntax highlighting, formulas,
tables, and diagrams. Other audiences (students, lawyers, biologists, and so on) come later
through new block types and formatting profiles. They never come through separate apps or
separate document types.

Product principles:
- Typing speed comes first. The user types once, in markdown, and never reformats later.
- Auto-formatting is optional. The user can configure it or turn it off. The default is minimal.
- Extensible core: markdown plus block types selected by fenced-block tags
  (for example ```python, ```chart, ```diagram). Each block type is a parser rule plus a renderer
  for screen and PDF. Adding a new block type must not require changes to unrelated code.
- Math formulas are fast to enter (LaTeX syntax first, shortcuts and snippets later) and rendered
  in the preview and in the PDF (SwiftMath is used).
- Live markdown preview next to the editor (side by side on large screens).
- Formatting profiles (presets such as "Lecture notes" or "Design doc") instead of separate
  document types.
- Notes are saved inside the app and organized with folders and tags. They can be exported
  to the device as PDF (main output) and `.md` files.
- Core value: find information in notes quickly, without scrolling through many pages.
- Devices: iPhone, iPad, iPhone Duo (foldable, iOS 27), and Mac. Layouts are adaptive and never
  assume a fixed screen size. The typed text is never lost when the layout changes.
  The Mac approach is undecided (Mac Catalyst is the leading candidate). Until it is decided,
  do not add AppKit code and do not break UIKit-based code.

Learning goal: the developer builds this app to learn Swift and app design.
Working code is not enough. Understanding it is the goal.

## Roadmap (order of work)

AI is the LAST feature. Do not start a later step before the earlier ones are merged,
and do not add work from a later step to an earlier task.

1. Formatting and generating. Done: PDF from `[NoteBlock]`, inline bold/italic/code,
   `$$...$$` formulas. Remaining: formatting settings in the UI and formatting profiles,
   inline `$...$` formulas.
2. Export: `.md` file export. Done.
3. **Current task: start page with fake data** (see "Navigation and design"). It uses an
   in-memory repository behind the `NoteRepository` protocol. No real storage yet.
4. Block types, code first: keep the fence language tag (`.codeBlock(language:text:)`), syntax
   highlighting, then tables, charts from data (Swift Charts, check PDF export first), and
   diagrams from text (an experiment: check feasibility before promising).
5. Live markdown preview and adaptive layout: one `NavigationSplitView` layout for iPhone, iPad,
   iPhone Duo, and Mac. The start page becomes the sidebar.
6. Saving: real storage with folders and tags, replacing the in-memory repository.
7. Search, in levels: (a) full-text search with highlights and jump-to-location,
   (b) keyword cards that show the matching passages with their source note,
   (c) an outline built from each note's headings. Search sits behind a `NoteSearcher` protocol.
   It must ignore case and handle Russian word forms.
8. AI (last): ask questions about the user's notes and get answers based on them
   (semantic search with embeddings, then answers from the found passages). See "AI rules".

The roadmap can change. Record changes in `docs/decisions.md`.

## Navigation and design

Decisions for the start page (record them in `docs/decisions.md`):
- The app opens to the start page (Home), not to the editor.
- Layout, top to bottom: title "Notes" with search and settings buttons, a "new note" button in the
  top-right toolbar, a "Recent" section, and a "Folders" section.
- "New note" button: a compose icon in the top-right toolbar, with the accessibility label
  "New note" and the shortcut Cmd+N. It opens the existing editor with an empty note and the
  keyboard ready. The note is stored in the Inbox folder only if the user types something.
  An empty note is never created.
- "New folder": a text button in the Folders section. It must look different from the "new note"
  button, so the two actions are not confused.
- Folders are flat (no nesting) for now. The **Inbox** folder always exists and cannot be deleted.
- Recent shows the last 5 edited notes across all folders.
- The empty state is designed on purpose: no notes and only Inbox. Show a short hint and the
  "New folder" button.
- Search and settings buttons are placeholders until their steps (no screens yet).
- `HomeView` is self-contained, so it can become the sidebar of a `NavigationSplitView` later.
- Inspiration is the structure of GitHub's apps (a list-based home on the phone, a sidebar with
  columns on a big screen). Never copy their logo, colors, icons, or visual style.

Wireframe (phone):

```
+--------------------------------+
| Notes                Q  (o) [+]|   Q = search, (o) = settings, [+] = new note
|                                |
| Recent                         |
|   Binary trees         Today   |
|   Docker cheatsheet    Mon     |
|   Lab 3: circuits      Sun     |
|                                |
| Folders           New folder   |
|   Algorithms            12  >  |
|   Electronics            7  >  |
|   Inbox                  3  >  |
+--------------------------------+
```

UI rules:
- System components first (`List`, `NavigationStack`, SF Symbols). Follow Apple's Human Interface
  Guidelines.
- Support Dynamic Type, dark mode, and VoiceOver labels.
- Build screens with fake data first and add Xcode Previews for the empty state and a state with
  data. Check iPhone, iPad, and landscape.
- Show a plan before building a screen. Change only the screen being designed.

## Project state

Verify this section against the code at the start of a task, and update it at the end of
every task. If it is wrong, say so.

State as of 2026-11-11 (check before relying on it):
- **App root is `HomeView`** (NavigationStack). `ContentView` remains as a standalone editor
  scaffold but is no longer the entry point.
- Pipeline works: `SimpleMarkdownParser` → `[NoteBlock]` → `PDFGenerator` → A4 PDF.
- Sharing: the PDF goes through `ShareLink` with `FileRepresentation(contentType: .pdf)` so Quick
  Look and "Save to Files" appear in the share sheet. The `.md` export uses
  `FileRepresentation(contentType: .plainText)` and writes a `StudyNotes.md` temp file.
- Supported block syntax: headings (levels 1-3), paragraphs, bullet lists (`-`, `*`), numbered
  lists, fenced code blocks. Text after the opening fence is currently ignored, so the language
  tag is not stored yet.
- Inline markup inside any block: `**bold**`, `*italic*`, `***bold-italic***`, `` `code` ``,
  and `$...$` inline formulas. Unmatched markers are kept as plain text. `InlineSpan` holds the
  styled runs, including `.inlineFormula(String)`.
- Formulas: `$$...$$` on its own line → `.formula(latex:)` block, rendered centered by SwiftMath
  in preview and PDF. `$...$` inline → `.inlineFormula(String)`, rendered with
  `MTMathImage(labelMode: .text)`. Preview uses `Text(Image(uiImage:))` concatenation;
  PDF uses `NSTextAttachment` with scaled bounds. `$$` prefix/lookbehind guards prevent
  collision with block formulas. Invalid LaTeX falls back to the raw `$...$` text.
- Code blocks use `.backgroundColor` (`NSTextBlock` is AppKit-only, not available on iOS).
- **`PDFGenerator.bodyFontSize` and `.margin`** are set via `FormattingProfile` from the editor.
  Heading sizes always scale from `bodyFontSize`.
- **`FormattingProfile`:** `nonisolated` enum with `.standard` (12 pt / 50 pt margin),
  `.lecture` (14 pt / 40 pt), `.compact` (10 pt / 35 pt). `NoteEditorView` holds
  `@State private var formattingProfile: FormattingProfile = .standard`. The "Aa" toolbar button
  (`textformat.size`) opens a half-sheet picker for all note types.
- 76 Swift Testing tests pass (5 new inline-formula parser tests, 1 updated formula test).

To verify: formula images are bitmaps, so check that they stay sharp when the PDF is zoomed.
SwiftMath support for chemistry notation (such as `\ce{}`) is unverified. Check before promising it.

- **Start page (step 3):** `HomeView` with `NavigationStack`. Shows last 5 edited notes
  ("Recent") and all folders with counts ("Folders"). Compose button (top-right toolbar,
  `square.and.pencil`, `Cmd+N`) and search/settings placeholder buttons. "New folder" text
  button in the Folders section header.
- **Models:** `Note` (id, name?, noteType, text, folderId, dates; `title` computed from name or
  first line), `Folder` (id, name, isInbox), `NoteType` (.pdf / .markdown),
  `FormattingProfile` (.standard / .lecture / .compact). All `nonisolated`, `Sendable`.
- **Storage layer:** `NoteRepository` protocol + `InMemoryNoteRepository` (class, holds data
  in dictionaries). `InMemoryNoteRepository.withSampleData()` has 7 notes in Cyrillic and
  English and 3 folders including a long Cyrillic folder name.
- **`HomeViewModel`:** `ObservableObject`, `@MainActor`. `nonisolated init` to allow use as
  a default parameter value; callers must call `refresh()` after construction (views via
  `.onAppear`, tests explicitly).
- **`NoteEditorView`:** editor pushed from `HomeView`'s NavigationStack; no own NavigationStack;
  saves via `.onDisappear { onSave(name, text) }`. Keyboard focus on appear via `@FocusState`.
  PDF notes: title field + text editor + ▶ play button (generates, saves, shows Quick Look).
  Markdown notes: title field + Edit/Preview picker + share menu (.md + Generate PDF option).
  Both types have the "Aa" formatting profile button.
- **`HomeDestination` enum:** `Hashable`, two cases: `.newNote(type:defaultName:)` and
  `.existingNote(Note)`.
- **`PDFSheetView`:** NavigationStack sheet wrapping `PDFKitView` (UIViewRepresentable for PDFKit).
  Has Done and ShareLink toolbar buttons.
- 76 Swift Testing tests pass.
- `docs/decisions.md` created with start-page decision entries.

Not built yet: notes list and storage, folders and tags, search, live preview,
adaptive layout, block types other than code and formula, formatting profiles, AI.

## Layout

The Xcode project lives one level below the repo root, in `StudyNotes/`. All `xcodebuild`
commands run from there (CI sets `working-directory: StudyNotes`).

- `StudyNotes/StudyNotes/` — app target sources and asset catalog
- `StudyNotes/StudyNotesTests/` — unit test target (hosted in the app via `TEST_HOST`)
- `docs/decisions.md` — decision log (create it if it does not exist)
- `scripts/` — CI helper scripts

Both target folders are file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`,
project `objectVersion = 77`): files added to or removed from these directories on disk are picked
up automatically. Do not edit `project.pbxproj` to register new source files.

Folders: `Models/`, `Parsing/`, and later `Rendering/`, `Views/`, `ViewModels/`, `Storage/`, `Search/`.
The only Swift package dependency is SwiftMath (approved by the developer). No linter and no
formatter are configured.

## Commands

Run from `StudyNotes/`. There is one shared scheme, `StudyNotes`, which builds the app and runs
`StudyNotesTests`.

```sh
# Build
xcodebuild build -project StudyNotes.xcodeproj -scheme StudyNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# Run all tests
xcodebuild test -project StudyNotes.xcodeproj -scheme StudyNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# Run a single suite or test
xcodebuild test -project StudyNotes.xcodeproj -scheme StudyNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:StudyNotesTests/SimpleMarkdownParserTests
```

If the `iPhone 16` simulator is not installed locally, pick one from
`xcrun simctl list devices available`.

## Build settings that affect how code must be written

- **Deployment target is iOS 16.6** for both targets (the project-level value is overridden
  per target). APIs newer than 16.6 need `if #available` / `@available` guards. This rules out
  unguarded `@Observable`, SwiftData, and iOS 17+ additions to navigation. `NavigationStack` and
  `NavigationSplitView` themselves exist in iOS 16, but check any option you are not sure about.
  The developer may raise the target to iOS 17 for SwiftData. That is a decision for the
  "Saving" step: propose it with trade-offs, and do not change the target on your own.
- **App target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** with
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`: un-annotated declarations in the app are implicitly
  `@MainActor`. Mark pure logic (parser, models, search) `nonisolated`. The test target does not
  default to MainActor, so tests that call main-actor code need `@MainActor` or `await`.
- Swift language mode is 5 (`SWIFT_VERSION = 5.0`).
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest.

## Architecture

Pipeline: text input → `NoteParser` → `[NoteBlock]` (AST) → renderer → screen / PDF.

- `NoteParser` is a protocol. `SimpleMarkdownParser` exists. Math-aware parsers come later.
- `NoteBlock` is an enum. Text-bearing cases carry `[InlineSpan]`. `.formula(latex:)` is rendered
  with SwiftMath.
- The PDF renderer and the on-screen renderer (live preview) both consume `[NoteBlock]`.
  Never parse text and draw into a PDF context in one function.
- A new block type (chart, diagram, and so on) is a new `NoteBlock` case or a tagged code block,
  plus a parser rule and a renderer for screen and PDF. Do not scatter special cases through
  unrelated code.
- Hide each replaceable part behind a protocol: `NoteParser`, `NoteRepository` (storage),
  `NoteSearcher` (search), `NoteAssistant` (AI, last). Views never talk to a concrete storage type.
- `Note` and `Folder` are plain structs (value types). View models are `ObservableObject`s that
  hold UI logic in testable code.
- No backend for now. Everything runs on the device.

## Code conventions

- Prefer `struct` and protocols over class inheritance.
- SwiftUI only, unless a UIKit API is required (for example `UIGraphicsPDFRenderer`).
- Use `ObservableObject` while the target is iOS 16.6.
- Parsing, search, and view-model logic must be pure and unit-testable. Add Swift Testing tests
  for every change in them, including Cyrillic input and edge cases.
- The PDF must look the same in light and dark mode: use fixed colors, never dynamic system
  colors (`.label`, `systemGray`, and so on), in the PDF renderer.
- State that holds the user's text lives above any view whose layout changes (rotation, split
  view, folding), so the text is never lost.
- Never put secrets (API keys, tokens, passwords) in code, `CLAUDE.md`, or any committed file.

## Working with the developer

The developer knows Java and C++ and is new to Swift.

- For any task bigger than a small fix, show a short plan and wait for approval.
- Do only what was asked. If another change seems needed (for example a layout change during a
  PDF task), ask first. Never do it silently.
- Never commit or push. The developer reviews the diff and commits. Work on a feature branch,
  never on `main`.
- Explain Swift concepts briefly when they appear (optionals, property wrappers, value semantics,
  actors, and so on) and compare them with C++/Java. Explain why, not only what.
- For significant design decisions, offer 2-3 options with trade-offs and a recommendation.
  After the decision, add a short entry to `docs/decisions.md` (decision, reason, alternatives).
- If you are not sure that an API exists or works on iOS 16.6, say so and check the
  documentation. Do not guess. Do not use new foldable (iOS 27) APIs from memory.
- Run the build and the tests before saying a task is done. Report the real result.
- Do not add dependencies without asking.
- Keep changes small and reviewable. Update "Project state" at the end of each task.

## English practice

The developer is learning English and writes prompts in English.

- Reply in English. If the developer writes in Russian, reply in Russian.
- If the prompt had real mistakes, add a short "English corrections" section at the end of the
  reply: the corrected sentence and one short reason per mistake. At most 5 items, the most
  important first. Do not correct style preferences. If there are no mistakes, skip the section.
- Corrections never delay or replace the work.

## CI

`.github/workflows/ci.yml` builds and tests on a macOS runner with coverage, then runs a
SonarQube Cloud scan. It needs `sonar-project.properties`,
`scripts/xccov-to-sonarqube-generic.sh`, and the `SONAR_TOKEN` secret. A CodeQL workflow
may also exist. Check the workflow files for the current Xcode version and simulator, and do not
assume them. Keep `*.xcresult` and generated Sonar files in `.gitignore`. The runner's Xcode must
support the SDK that the project uses, and CI must be able to resolve the SwiftMath package.
A build that passes locally can still fail in CI.

## AI rules (for the last roadmap step)

- AI sits behind the `NoteAssistant` protocol, so on-device and cloud implementations can be swapped.
- Answers come only from the user's own notes. Show the source passages next to each answer.
- Searching the text is plain code, not AI. Use AI only for meaning and for writing answers.
- A cloud model needs a small server that holds the API key. Never put a key in the app.
- Notes are personal. Tell the user when text leaves the device, and keep the App Store
  privacy details accurate.
- Check Apple's documentation for on-device model requirements before designing for them.
