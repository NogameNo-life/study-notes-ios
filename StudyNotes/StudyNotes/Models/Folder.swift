//
//  Folder.swift
//  StudyNotes
//

import Foundation

/// A note folder. Folders are flat (no nesting) at this stage.
///
/// `isInbox` marks the special system folder that always exists and cannot be deleted.
/// All other folders are user-created.
nonisolated struct Folder: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// True only for the Inbox folder. The UI uses this to prevent deletion.
    let isInbox: Bool
}
