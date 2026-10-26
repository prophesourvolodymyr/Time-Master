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
        CommandGroup(after: .toolbar) {
            ZoomMenuItems()
            Divider()
            MenuBarToggleItem()
        }
        SwiftUI.TextEditingCommands()
    }
}

private struct ZoomMenuItems: View {
    @ObservedObject private var zoom = MacInterfaceZoom.shared

    var body: some View {
        Group {
            Button("Actual Size") { zoom.reset() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(zoom.isActualSize)
            Button("Zoom In") { zoom.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!zoom.canZoomIn)
            Button("Zoom Out") { zoom.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!zoom.canZoomOut)
        }
    }
}

private struct MenuBarToggleItem: View {
    @ObservedObject private var preferences = MenuBarPreferences.shared

    var body: some View {
        Toggle("Show Tmax in Menu Bar", isOn: $preferences.isEnabled)
    }
}
#endif
