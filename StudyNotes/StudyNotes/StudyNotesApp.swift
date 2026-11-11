//
//  StudyNotesApp.swift
//  StudyNotes
//
//  Created by Yana Sitkovets on 9/28/26.
//

import SwiftUI

@main
struct StudyNotesApp: App {
    var body: some Scene {
        WindowGroup {
            // HomeView owns its own NavigationStack and serves as the app's root.
            // ContentView remains in the project as a standalone editor scaffold.
            HomeView()
        }
    }
}
