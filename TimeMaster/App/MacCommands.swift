#if os(macOS)
import SwiftUI
import AppKit
import TimeMasterCore

struct TimeMasterCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workout") {
                NotificationCenter.default.post(
                    name: .newWorkoutCommand,
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {}

        CommandMenu("Workout") {
            Button("Start Workout") {
                NotificationCenter.default.post(
                    name: .launchWorkout,
                    object: nil
                )
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            Divider()
            Button("Settings...") {
                NotificationCenter.default.post(
                    name: .openSettingsCommand,
                    object: nil
                )
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

        TextEditingCommands()
    }
}

struct TextEditingCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)
            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)
            Button("Paste") {
                NSApp.sendAction(#selector(NSText.paste), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: .command)
            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)
        }
    }
}

struct WindowCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .windowSize) {
            Button("Close Window") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

#endif
