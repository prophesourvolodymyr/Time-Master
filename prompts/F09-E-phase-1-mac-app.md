# Phase 1 of F09-E — Mac App (Native macOS Build)

## Context
TimeMaster V2.0 — Revolution REV-01. F09-A (TimeMasterCore), F09-B (Knowledge), F09-C (CLI Tool), and F09-D (AI Tool Calling) are built and verified. F09-E creates a native macOS target from the same SwiftUI codebase — not Catalyst, true macOS SwiftUI target. The purpose: expose the local file-system database to external AI agents (Claude Code, Cursor, Terminal) so they can read, create, and modify exercises, workouts, and analytics through `timemaster-tool`.

## What You Need to Read First
- `features/F09-file-based-data/F09-E-mac-app/DOCKS.md` — full spec
- `features/F09-file-based-data/DOCKS.md` — architecture overview
- `TimeMaster/App/TimeMasterApp.swift` — current iOS-only app entry point
- `TimeMaster/Views/MainTabView.swift` — tab bar (needs sidebar on Mac)
- `TimeMasterCore/Sources/FileSystemHelper.swift` — data root path logic (needs non-sandboxed macOS path)
- `TimeMasterCore/Package.swift` — Swift Package definition (platforms already include macOS)

## What Happened Last Session
F09-D AI Tool Calling was built and verified:
- `ToolRouter.swift` — routes 9 tool calls (search_exercises, get_exercise, list_folders, create_exercise, create_folder, get_recent_workouts, build_workout, get_analytics, add_media_note) through `TimeMasterCore.DatabaseManager`
- `SessionContext` struct added to `AISystemPromptBuilder` — builds startup context (knowledge + db summary + activity + schedule)
- `AIProvider.toolDefinitions` + `AIProvider.anthropicToolDefinitions` — OpenAI/Anthropic function schemas
- `AIStore.sendWithToolLoop()` — max 5 iterations, tool result injection, error handling
- `AICoachView.ToolCallIndicator` — animated pulsing indicator during tool execution
- TimeMasterCore added as local Swift Package dependency to iOS Xcode project
- All 49 tests pass, iOS build succeeds on iPhone 16 simulator (arm64)

## What to Build

### 1. macOS Target in Xcode Project
Add a macOS target to `TimeMaster.xcodeproj`:
- Deployment target: macOS 14+
- Bundle identifier: `com.timemaster.macos`
- Same source files, `#if os(macOS)` where needed
- App sandbox: NO (we want full file access for external AI)
- TimeMasterCore already supports macOS in its Package.swift

### 2. Data Path — Non-Sandboxed
Modify `FileSystemHelper.init()` to use `~/Documents/TimeMaster/` on macOS:
```swift
#if os(macOS)
let home = FileManager.default.homeDirectoryForCurrentUser
let root = home.appendingPathComponent("Documents/TimeMaster", isDirectory: true)
#else
let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let root = docs.appendingPathComponent("TimeMaster", isDirectory: true)
#endif
```

### 3. App Entry Point
Modify `TimeMasterApp.swift`:
```swift
#if os(macOS)
@main
struct TimeMasterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .commands { TimeMasterCommands() }
    }
}
#else
@main
struct TimeMasterApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
#endif
```

### 4. macOS Menu Bar
Create `TimeMaster/App/MacCommands.swift`:
- Standard macOS menus: File (new workout, close), Edit (cut/copy/paste), Window
- Keyboard shortcuts: Cmd+N (new workout), Cmd+W (close), Cmd+, (settings)

### 5. Platform-Adaptive UI
- `MainTabView.swift` — uses `TabView` on iOS, `NavigationSplitView` + sidebar on macOS
- `WorkoutDetailView/SectionEditorView.swift` — uses `PhotosPicker` on iOS, `NSOpenPanel`/file picker on macOS
- `AICoachView` — uses `fileImporter` on iOS, native file open dialog on macOS

### 6. Media Import on Mac
Create `TimeMaster/Utilities/MacFilePicker.swift`:
- NSOpenPanel wrapper for file selection
- Supports drag-and-drop from Finder
- Calls through to existing `PhotoManager` patterns

### 7. Widget Port
The existing F08 widget should compile for macOS Notification Center — verify it works.

## Files to Create/Modify
- **modify:** `TimeMaster.xcodeproj/project.pbxproj` — add macOS target
- **modify:** `TimeMaster/App/TimeMasterApp.swift` — `#if os(macOS)` for WindowGroup
- **create:** `TimeMaster/App/MacCommands.swift` — macOS menu bar commands
- **modify:** `TimeMaster/Views/MainTabView.swift` — adaptive sidebar on Mac
- **create:** `TimeMaster/Utilities/MacFilePicker.swift` — NSOpenPanel wrapper
- **modify:** `TimeMasterCore/Sources/FileSystemHelper.swift` — non-sandboxed path on macOS
- **modify:** `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift` — macOS file picker
- **modify:** `TimeMaster/Views/AICoach/AICoachView.swift` — macOS file dialog

## Verification
- [ ] macOS target compiles and launches native window
- [ ] Same SwiftUI views render correctly on macOS
- [ ] `bootstrapIfNeeded()` creates `~/Documents/TimeMaster/` (not sandbox path)
- [ ] Finder: user can browse Exercises Database/, open manifest.json
- [ ] All iOS features work on Mac (workout creation, timer, analytics, AI chat)
- [ ] Keyboard shortcuts work (Cmd+N, Cmd+W, Cmd+,)
- [ ] Media import via drag-and-drop and file picker
- [ ] Widget appears in macOS Notification Center
- [ ] All 49 TimeMasterCore tests pass

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F09-E): native macOS target — adaptive UI, non-sandboxed path, menu commands"
3. **UPDATE CYCLES.md:** After verifying, mark F09-E tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Read `features/F01-A-migrate-models/DOCKS.md` and create `prompts/F01-A-phase-1-migrate.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
