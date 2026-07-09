# Phase 1 of F05-A-v2 — Rewire Import to File-Based Architecture

## Context
TimeMaster V2.0 — Revolution REV-01. F01-A (migrate models to file manifests) is built and verified. The existing import system (BackupManager, ImportSheetView) writes to UserDefaults via DatabaseStore. F05-A-v2 rewires the import pipeline to write through `TimeMasterCore.DatabaseManager` into the file-based `Exercises Database/` folder structure.

## What You Need to Read First
- `features/F05-A-v2-import/DOCKS.md` — create this file first following the standard template
- `features/F05-database-import/F05-A-import-export-previews/DOCKS.md` — existing import spec (for context)
- `features/F01-A-migrate-models/DOCKS.md` — reference for how data is now stored
- `TimeMasterCore/Sources/DatabaseManager.swift` — `createExercise()`, `createWorkout()`, `importMedia()`, `appendHistoryEntry()`
- `TimeMaster/Utilities/BackupManager.swift` — current import logic (UserDefaults-based)
- `TimeMaster/Views/Database/ImportSheetView.swift` — current import UI
- `TimeMaster/ViewModels/DatabaseStore.swift` — current storage (now has `loadFromFileSystem()`)

## What Happened Last Session
F01-A was built and verified:
- `MigrationManager.migrateFromUserDefaults()` reads 11 UserDefaults keys, converts to file manifests
- `WorkoutStore` loads from DatabaseManager after migration (converts WorkoutManifest → Workout)
- `DatabaseStore` loads from file system after migration (walks Exercises Database/ directory tree)
- `TimeMasterApp.init()` calls `MigrationManager.migrateIfNeeded()` before stores are created
- Migration marker `.migration_complete` in Config/ prevents re-migration
- Backup JSON saved to Backups/ before migration
- 14 MigrationTests pass + 49 existing tests pass (63 total, 0 failures, macOS arm64)

## What to Build

### 1. Create F05-A-v2 DOCKS.md
Create `features/F05-A-v2-import/DOCKS.md` following the standard template. Define:
- What the import pipeline looks like post-migration: ZIP import → extract → write via DatabaseManager
- How existing BackupManager.importBackup() changes to use file-based writes
- What happens with media files: importMedia() into Media/ directory
- Verification: imported exercises appear in DatabaseManager.listExercises(), not just DatabaseStore

### 2. Rewire BackupManager
Modify `TimeMaster/Utilities/BackupManager.swift`:
- `importBackup()`: after extracting JSON from ZIP, write to file system via `DatabaseManager.shared`
  - Exercises → `db.createExercise(id:, manifest:, parentPath:)`
  - Workouts → `db.createWorkout(id:, manifest:)`
  - History → `db.appendHistoryEntry()`
  - Config → `db.saveConfig()`
- Media import: use `db.importMedia(from:)` to copy files to Media/ with UUID filenames
- After import, call `DatabaseStore.shared.reload()` and `WorkoutStore().reload()` to refresh

### 3. Update ImportSheetView
- After import completes, trigger reload on stores
- Show import summary (exercises, workouts, media counts from MigrationSummary-like struct)

### 4. Verify Import
- Unit tests for BackupManager file-based import
- Verify imported exercises appear in Exercises Database/ folder structure
- Verify imported media files have UUID filenames in Media/

## Files to Create/Modify
- **create:** `features/F05-A-v2-import/DOCKS.md`
- **modify:** `TimeMaster/Utilities/BackupManager.swift` — rewire import to DatabaseManager
- **modify:** `TimeMaster/Views/Database/ImportSheetView.swift` — update post-import refresh

## Verification
- [ ] F05-A-v2 DOCKS.md created and approved
- [ ] importBackup() writes to file system via DatabaseManager
- [ ] Imported exercises appear in Exercises Database/ with manifest.json + guide.md
- [ ] Imported workouts appear in Workouts/ with manifest.json
- [ ] Imported media files have UUID filenames in Media/
- [ ] Post-import, DatabaseStore and WorkoutStore reflect new data
- [ ] All 63 existing tests still pass
- [ ] New import tests pass

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F05-A-v2): rewire import to file-based architecture"
3. **UPDATE CYCLES.md:** After verifying, mark F05-A-v2 tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Read `features/F06-B-ai-database-creation/DOCKS.md` (create if needed) and create `prompts/F06-B-phase-1-ai-tool-calling.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
