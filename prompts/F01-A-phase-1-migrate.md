# Phase 1 of F01-A — Migrate Models to File Manifests

## Context
TimeMaster V2.0 — Revolution REV-01. F09-A (TimeMasterCore), F09-B (Knowledge), F09-C (CLI Tool), F09-D (AI Tool Calling), and F09-E (Mac App) are built and verified. F01-A migrates the existing iOS data (stored in UserDefaults JSON blobs) into the file-system database structure managed by TimeMasterCore.

## What You Need to Read First
- `features/F01-A-migrate-models/DOCKS.md` — full spec (create this file first)
- `features/F09-file-based-data/F09-A-timemastercore/DOCKS.md` — core library reference
- `TimeMasterCore/Sources/DatabaseManager.swift` — API for reading/writing
- `TimeMasterCore/Sources/MigrationManager.swift` — migration utilities
- `TimeMasterCore/Sources/SchemaManager.swift` — schema definitions
- `TimeMaster/ViewModels/WorkoutStore.swift` — current iOS data store (UserDefaults)
- `TimeMasterCore/Sources/Models/` — work with these model types

## What Happened Last Session
F09-E Mac App was built and verified:
- macOS target added to Xcode project (macOS 14+, com.timemaster.macos)
- `FileSystemHelper.init()` uses `~/Documents/TimeMaster/` on macOS, sandbox `Documents/` on iOS
- `TimeMasterApp.swift` has macOS entry point with `.windowStyle(.titleBar)`, `.commands`, `.frame(minWidth: 800, minHeight: 600)`
- `MainTabView.swift` uses `NavigationSplitView` on Mac, `TabView` on iOS
- `MacCommands.swift`: File/Edit/Window menu bar with Cmd+N/W/, shortcuts
- `MacFilePicker.swift`: NSOpenPanel wrapper for file selection
- 37 files patched with `#if os(macOS)`/`#if os(iOS)` guards (AudioManager, PhotoManager, all views, etc.)
- macOS target **compiles successfully**, all 49 TimeMasterCore tests pass
- Widget exists for macOS Notification Center
- Updated CYCLES.md cycle 6 — F09-E marked verified

## What to Build

### 1. Create F01-A DOCKS.md
Create `features/F01-A-migrate-models/DOCKS.md` following the standard template. Define:
- What data to migrate (WorkoutStore.workouts, WorkoutStore.history, DatabaseStore)
- Migration strategy: one-time conversion on first launch, UserDefaults → Exercises Database/ folders
- What happens when migration fails, duplicates, partial data
- How to verify migration success (counts match, content matches)

### 2. Implement Migration in MigrationManager
Modify `TimeMasterCore/Sources/MigrationManager.swift`:
- `migrateFromUserDefaults()` — reads old JSON blobs, converts to file manifests
- Creates exercises from Section templates into Exercises Database/
- Creates workout manifests from saved workouts
- Updates a migration marker to prevent re-migration
- Handles duplicate detection (skip if file already exists)
- Reports migration results (counts, errors)

### 3. Implement MigratedDataStore
Modify `TimeMaster/ViewModels/WorkoutStore.swift`:
- On first launch after migration: read data from filesystem via `DatabaseManager.shared`
- Keep backward compatibility: if migration hasn't run, fall back to UserDefaults
- Add migration trigger in `TimeMasterApp.swift` (call after bootstrap)

### 4. Verify Migration
- Unit tests for MigrationManager
- Manual test: launch iOS build, verify Exercises Database/ matches original UserDefaults data
- Verify no data loss, all media files preserved

## Files to Create/Modify
- **create:** `features/F01-A-migrate-models/DOCKS.md`
- **modify:** `TimeMasterCore/Sources/MigrationManager.swift` — add migration from UserDefaults
- **modify:** `TimeMaster/ViewModels/WorkoutStore.swift` — add filesystem read path
- **modify:** `TimeMaster/ViewModels/DatabaseStore.swift` — add migration awareness
- **modify:** `TimeMaster/App/TimeMasterApp.swift` — trigger migration after bootstrap
- **create:** `TimeMasterCore/Tests/MigrationTests.swift` — migration unit tests

## Verification
- [ ] F01-A DOCKS.md created and approved
- [ ] `migrateFromUserDefaults()` correctly converts all exercise types
- [ ] Workout history entries migrate without data loss
- [ ] Duplicate detection prevents double-migration
- [ ] Migration marker persists between app launches
- [ ] All 49 existing tests still pass
- [ ] New migration tests pass
- [ ] Migration generates correct folder structure under Exercises Database/

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F01-A): migrate models from UserDefaults to file manifests"
3. **UPDATE CYCLES.md:** After verifying, mark F01-A tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Read `features/F05-A-v2-import/DOCKS.md` and create `prompts/F05-A-v2-phase-1-import.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
