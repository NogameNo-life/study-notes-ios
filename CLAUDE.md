# CLAUDE.md

This file guides Claude Code (claude.ai/code) when working in this repository.
Read it fully at the start of every session.

## Goals

StudyNotes is an iOS app for writing beautiful notes fast, so a student does not waste time
formatting after lessons, or rewriting text into markdown, or struggling to type math formulas.

Product principles:
- Typing speed comes first. The user types once, in markdown, and never reformats later.
- Auto-formatting is optional. The user can configure it or turn it off. The default is minimal.
- Math formulas must be fast to enter (LaTeX syntax first, shortcuts and snippets later)
  and rendered in the preview and in the PDF (SwiftMath is a candidate, decide with the developer).
- Notes are saved inside the app and organized with folders and tags. They can be exported
  to the device as PDF (main output) and `.md` files.
- Core value: find information in notes quickly, without scrolling through many pages.
- Devices: iPhone, iPad, and iPhone Duo (foldable, iOS 27). Layouts must be adaptive.
  Never assume a fixed screen size, and never lose the typed text when the layout changes.

Learning goal: the developer builds this app to learn Swift and app design.
Working code is not enough. Understanding it is the goal.

## Roadmap (order of work)

AI is the LAST feature. Do not start a later step before the earlier ones are merged,
and do not add work from a later step to an earlier task.

1. Formatting and generating: render the PDF from `[NoteBlock]` (headings, lists, code),
   inline bold/italic, user-configurable formatting options, math formulas.
2. Export: `.md` file export (the typed text is already markdown).
3. Adaptive layout: iPhone, iPad, iPhone Duo (`NavigationSplitView` or equivalent).
4. Saving: storage with folders and tags behind a `NoteRepository` protocol.
5. Search, in levels: (a) full-text search with highlights and jump-to-location,
   (b) keyword cards that show the matching passages with their source note,
   (c) an outline built from each note's headings. Search sits behind a `NoteSearcher` protocol.
   It must ignore case and handle Russian word forms.
6. AI (last): ask questions about the user's notes and get answers based on them
   (semantic search with embeddings, then answers from the found passages). See "AI rules".

The roadmap can change. Record changes in `docs/decisions.md`.

## Project state

Verify this section against the code at the start of a task, and update it at the end of
every task. If it is wrong, say so.

State as of 2026-11-05 (check before relying on it):
- `TextEditor` for note input in `ContentView` (one screen, no notes list yet).
- Pipeline works: `SimpleMarkdownParser` → `[NoteBlock]` → `PDFGenerator` → A4 PDF.
- PDF is shared via `ShareLink` with `FileRepresentation(contentType: .pdf)` so Quick Look
  and "Save to Files" appear in the share sheet.
- Supported block syntax: headings (levels 1–3), paragraphs, bullet lists (`-`, `*`),
  numbered lists, fenced code blocks. `.formula(latex:)` draws raw LaTeX as a placeholder.
- Inline markup inside any block: `**bold**`, `*italic*`, `***bold-italic***`, `` `code` ``.
  Unmatched markers are kept as plain text.
- `InlineSpan` enum holds the styled runs; `NoteBlock` text-bearing cases carry `[InlineSpan]`.
- Code blocks use `.backgroundColor` (NSTextBlock is AppKit-only, not available on iOS).
- `PDFGenerator.bodyFontSize` and `.margin` are configurable; heading sizes scale from body size.
- 51 Swift Testing tests (parser and PDF generator) pass.

Not built yet: notes list and storage, folders and tags, `.md` export, formula rendering
  (SwiftMath or similar — decision needed), search, adaptive layout, AI.

## Layout

The Xcode project lives one level below the repo root, in `StudyNotes/`. All `xcodebuild`
commands run from there (CI sets `working-directory: StudyNotes`).

- `StudyNotes/StudyNotes/` — app target sources and asset catalog
- `StudyNotes/StudyNotesTests/` — unit test target (hosted in the app via `TEST_HOST`)
- `docs/decisions.md` — decision log
- `scripts/` — CI helper scripts

Both target folders are file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`,
project `objectVersion = 77`): files added to or removed from these directories on disk are picked
up automatically. Do not edit `project.pbxproj` to register new source files.

Folders: `Models/`, `Parsing/`, and later `Rendering/`, `Views/`, `ViewModels/`, `Storage/`, `Search/`.
There are no Swift package dependencies, no linter, and no formatter configured.

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
  unguarded `@Observable`, SwiftData, and iOS 17+ `NavigationStack`/`NavigationSplitView` additions.
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
- `NoteBlock` is an enum with a reserved `.formula(latex:)` case.
- The PDF renderer and the on-screen renderer both consume `[NoteBlock]`.
  Never parse text and draw into a PDF context in one function.
- Hide each replaceable part behind a protocol: `NoteParser`, `NoteRepository` (storage),
  `NoteSearcher` (search), `NoteAssistant` (AI, last).
- No backend for now. Everything runs on the device.

## Code conventions

- Prefer `struct` and protocols over class inheritance.
- SwiftUI only, unless a UIKit API is required (for example `UIGraphicsPDFRenderer`).
- Use `ObservableObject` while the target is iOS 16.6.
- Parsing, search, and other logic must be pure and unit-testable. Add Swift Testing tests for
  every change in them, including Cyrillic input and edge cases.
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
support the SDK that the project uses. A build that passes locally can still fail in CI.

## AI rules (for the last roadmap step)

- AI sits behind the `NoteAssistant` protocol, so on-device and cloud implementations can be swapped.
- Answers come only from the user's own notes. Show the source passages next to each answer.
- Searching the text is plain code, not AI. Use AI only for meaning and for writing answers.
- A cloud model needs a small server that holds the API key. Never put a key in the app.
- Notes are personal. Tell the user when text leaves the device, and keep the App Store
  privacy details accurate.
- Check Apple's documentation for on-device model requirements before designing for them.
