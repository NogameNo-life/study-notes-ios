# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

StudyNotes is an iOS/iPadOS SwiftUI app that is currently the unmodified Xcode template (`StudyNotesApp` → `ContentView` showing "Hello, world!") plus one empty Swift Testing test. There is no app architecture yet; nothing here constrains how features should be structured.

## Layout

The Xcode project lives one level below the repo root, in `StudyNotes/`. All `xcodebuild` commands must be run from there (CI sets `working-directory: StudyNotes`).

- `StudyNotes/StudyNotes/` — app target sources and asset catalog
- `StudyNotes/StudyNotesTests/` — unit test target (hosted in the app via `TEST_HOST`)

Both target folders are file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`, project `objectVersion = 77`): files added to or removed from these directories on disk are picked up by the target automatically. Do not edit `project.pbxproj` to register new source files.

There are no Swift package dependencies, no linter, and no formatter configured.

## Commands

Run from `StudyNotes/`. There is a single shared scheme, `StudyNotes`, which builds the app and runs `StudyNotesTests`.

```sh
# Build
xcodebuild build -project StudyNotes.xcodeproj -scheme StudyNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# Run all tests (same invocation as CI, minus coverage/result bundle flags)
xcodebuild test -project StudyNotes.xcodeproj -scheme StudyNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# Run a single test suite or test
xcodebuild test -project StudyNotes.xcodeproj -scheme StudyNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:StudyNotesTests/StudyNotesTests
#   ...or a single test: -only-testing:StudyNotesTests/StudyNotesTests/example
```

If the `iPhone 16` simulator is not installed locally, pick one from `xcrun simctl list devices available`.

## Build settings that affect how code must be written

- **Deployment target is iOS 16.6** for both targets (deliberately lowered; the project-level value of 26.5 is overridden per target). APIs newer than 16.6 need `if #available` / `@available` guards — this rules out unguarded use of `@Observable`, SwiftData, `NavigationStack` additions from iOS 17+, etc.
- **App target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** with `SWIFT_APPROACHABLE_CONCURRENCY = YES`: un-annotated declarations in the app are implicitly `@MainActor`. Mark code `nonisolated` (or move it to an explicit actor) when it must run off the main actor. The test target does not set default MainActor isolation, so tests calling into app code generally need `@MainActor` or `await`.
- Swift language mode is 5 (`SWIFT_VERSION = 5.0`).
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. The test file does not yet `@testable import StudyNotes`; add it when testing app code.

## CI

`.github/workflows/ci.yml` runs `xcodebuild test` on `macos-15` against the `iPhone 16` simulator for pushes and PRs to `main`, with code coverage enabled, and uploads `StudyNotes/TestResults.xcresult` as an artifact. `TestResults.xcresult` is not in `.gitignore` — don't commit it if you reproduce the CI command locally with `-resultBundlePath`.

## Product goal

StudyNotes lets students type notes on a keyboard in a simple markdown-like syntax
and export them as a nicely formatted PDF in a few taps. Think "Overleaf, but simpler".
Planned later: images, tables, math formulas (LaTeX, likely SwiftMath), iCloud sync,
and AI features (note summaries, RAG over notes).

## Architecture (target)

Pipeline: text input → `NoteParser` → `[NoteBlock]` (AST) → renderer → screen / PDF.

- `NoteParser` is a protocol. Start with `SimpleMarkdownParser`. Math-aware parsers come later.
- `NoteBlock` is an enum. Keep a reserved `.formula(latex:)` case for the future.
- PDF export and on-screen rendering both consume `[NoteBlock]`.
  Never parse text and draw into a PDF context in one function.
- No backend for now. Everything runs on the device.
- Planned folders: `Models/`, `Parsing/`, `Rendering/`, `Views/`, `ViewModels/`.

## Code conventions

- Prefer `struct` and protocols over class inheritance.
- SwiftUI only, unless a UIKit API is required (for example `UIGraphicsPDFRenderer`).
- Respect the iOS 16.6 deployment target. Use `ObservableObject`, not `@Observable`,
  unless guarded with `#available`.
- Parsing logic must be pure and unit-testable. Add Swift Testing tests for every parser change.

## Working with the developer

- The developer is new to Swift and experienced in C++ and Java.
  When you use a Swift-specific concept (optionals, property wrappers, value semantics,
  actors), explain it in one or two sentences and compare it to C++/Java where useful.
- Explain *why* you chose an approach, not only what you changed.
- Prefer small, reviewable changes. Run the build and tests before saying a task is done.
- Do not add dependencies without asking first.
- Work on a feature branch, never commit directly to `main`.
