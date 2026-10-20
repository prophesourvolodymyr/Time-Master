#if os(macOS)
import SwiftUI
import AppKit
import TimeMasterCore

struct TmaxCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workout") {
                NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {}
        CommandMenu("Workout") {
            Button("Start Workout") {
                NotificationCenter.default.post(name: .launchWorkout, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            Divider()
            Button("Settings…") {
                NotificationCenter.default.post(name: .openSettingsCommand, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandMenu("Database") {
            Button("Show Exercises Database in Finder") {
                let url = DatabaseManager.shared.exercisesDatabaseURL
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
        }
        CommandGroup(replacing: .appSettings) {}
        SwiftUI.TextEditingCommands()
    }
}
#endif
