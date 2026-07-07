# F09-E — Mac App (Native macOS Build)

The same TimeMaster iOS app, compiled as a native macOS application. Not Catalyst — true SwiftUI macOS target. The purpose: expose the local file-system database to external AI agents (Claude Code, Cursor, Terminal) so they can read, create, and modify exercises, workouts, and analytics.

## What We Build

1. **macOS target in Xcode project** — same SwiftUI codebase, new deployment target
2. **Platform-adaptive UI** — SwiftUI views render natively on Mac (menu bar, window management, keyboard shortcuts)
3. **Non-sandboxed file access** — `~/Documents/TimeMaster/` (human-readable path, Finder-browsable)
4. **CLI tool integration** — `timemaster-tool` (F09-C) installed alongside the app
5. **AGENTS.md auto-discovery** — external AI agents read the root AGENTS.md to bootstrap
6. **1:1 feature parity** — every iOS feature works identically on Mac
7. **Widgets ported** — same F08 widgets compile for macOS Notification Center — tap widget → opens workout detail in Mac app, same deep-link flow

## Architecture

```
macOS TimeMaster.app
├── Same SwiftUI views (WorkoutListView, DatabaseView, AnalyticsView, AICoachView, Settings)
├── Same TimeMasterCore (F09-A) shared library
├── Same models, stores migrated to file-based
└── Filesystem: ~/Documents/TimeMaster/

External AI (Claude Code / Cursor)
├── Reads AGENTS.md → understands directory structure
├── Calls timemaster-tool for all writes (F09-C)
├── Reads schema.json for data contract
└── Queries: search_exercises, build_workout, get_analytics, create_folder

User flow:
  Finder → ~/Documents/TimeMaster/ → browse Exercises Database/ → double-click manifest.json
  Claude Code → "create a push-day workout from my shoulder exercises" → calls CLI → done
  Widget → tap Notification Center widget → deep-links to WorkoutDetailView in the Mac app
```

## Platform Differences

| Aspect | iOS | macOS |
|---|---|---|
| **Data path** | Sandbox `Documents/` | `~/Documents/TimeMaster/` |
| **Sandbox** | Yes (app container) | No (full user space) |
| **Input** | Touch, swipe | Mouse, keyboard, trackpad |
| **Navigation** | NavigationStack + TabView | Sidebar + tab bar (native) |
| **Window** | Full-screen only | Resizable window, multiple windows |
| **External AI** | AI runs inside the app | AI runs outside, accesses filesystem via CLI |
| **Codebase** | Same Swift files | Same Swift files |
| **Media picker** | PhotosPicker, camera | NSOpenPanel, drag-and-drop from Finder |
| **Widgets** | Home Screen / Today View | Notification Center / Desktop |
| **Build target** | iOS 17+ | macOS 14+ |

## Key Design Decisions

- **No Catalyst** — native macOS SwiftUI target. Catalyst adds a translation layer that limits file access and native behavior.
- **Same code, conditional compilation** — `#if os(macOS)` for platform-specific code (file picker, window management, menu bar)
- **Same TimeMasterCore** — no platform branching in the data layer. `FileManager.default.urls(for: .documentDirectory)` resolves correctly on both.
- **CLI ships with the app** — `timemaster-tool` binary bundled in the .app package, symlinked to `/usr/local/bin/` on install
- **AGENTS.md is the handshake** — any AI agent reads this file first, no API keys, no network, purely local

## Files
- `TimeMaster.xcodeproj` — add macOS target
- `TimeMaster/App/TimeMasterApp.swift` — `#if os(macOS)` for window group vs WindowGroup
- `TimeMaster/App/MacMenuBar.swift` — (new) macOS menu bar commands
- `TimeMaster/Views/MainTabView.swift` — adaptive to sidebar on Mac
- `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift` — `#if os(macOS)` file picker vs PhotosPicker
- `TimeMaster/Utilities/MacFilePicker.swift` — (new) NSOpenPanel wrapper
- `TimeMasterCore/` — no platform changes needed
- `timemaster-tool/` (F09-C) — separate executable target, also built for macOS

## States

| State | Behavior |
|---|---|
| First launch | `TimeMasterCore.bootstrapIfNeeded()` creates `~/Documents/TimeMaster/` |
| Database exists | App reads existing file structure, syncs with app |
| External AI connected | AI reads AGENTS.md, calls CLI tools, app reflects changes on next launch |
| AI modifies database | Approval gate (F09-A) applies — CLI shows diff, user approves in Terminal or app |
| App + AI concurrent | Single-writer rule — app owns writes, AI queues through CLI, no corruption |
| User browses Finder | Sees Exercises Database/ folders, can open manifest.json, guide.md directly |
| Media import on Mac | Drag-and-drop from Finder into app, or CLI `import-media` |

## Verification
- [ ] macOS target compiles and launches native window
- [ ] Same SwiftUI views render correctly on macOS (list, grid, calendar, player)
- [ ] `bootstrapIfNeeded()` creates `~/Documents/TimeMaster/` (not sandbox path)
- [ ] Finder: user can browse Exercises Database/, open manifest.json
- [ ] `timemaster-tool` installed to `/usr/local/bin/`, callable from Terminal
- [ ] Claude Code / Cursor can read AGENTS.md and call CLI
- [ ] All iOS features work on Mac (workout creation, timer, analytics, AI chat)
- [ ] Media import via drag-and-drop and file picker
- [ ] Keyboard shortcuts: Cmd+N new workout, Cmd+W close window, Cmd+, settings
- [ ] Widget appears in macOS Notification Center, tap deep-links to workout detail

## Dependencies
- F09-A — TimeMasterCore (shared library, used by both platforms)
- F09-C — CLI Tool (bundled with Mac app for external AI access)
