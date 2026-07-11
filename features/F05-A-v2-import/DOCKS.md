# F05-A-v2 — Import Writes to File-Based Architecture

Revolution REV-01 — rewires the existing import pipeline (BackupManager, ImportSheetView callers) from writing to UserDefaults via DatabaseStore to writing through `TimeMasterCore.DatabaseManager` into the `Exercises Database/` folder structure.

## What We Build

1. **Rewired `BackupManager.importBackup()`** — after extracting ZIP + decoding manifest, writes exercises/workouts/history to file system via DatabaseManager instead of merging into in-memory stores + UserDefaults.
2. **Media import with UUID filenames** — media files from the ZIP are imported via `db.importMedia()` which assigns UUID-based filenames and copies to `Media/`.
3. **Post-import store refresh** — WorkoutStore.reload() fixed to read from file system post-migration; DatabaseView and BackupView callers updated to display import summaries.
4. **Duplicate detection** — checks if exercise/workout directory already exists in file system before writing.

## Architecture

```
ZIP Backup (manifest.json + media/)           File System (TimeMasterCore)
┌──────────────────────────────────┐         ┌──────────────────────────────┐
│ manifest.json                    │         │ Exercises Database/          │
│   workouts: [Workout]            │────────→│   {folder}/{id}/             │
│   workoutHistory: [...]          │──────→  │     manifest.json + guide.md │
│   folders: [ExerciseFolder]      │────────→│   {id}/                       │
│   rootExercises: [Exercise]      │────────→│     manifest.json + guide.md │
│                                  │         │ Workouts/{id}/               │
│                                  │──────→  │   manifest.json              │
│                                  │         │ History/                     │
│                                  │──────→  │   entries.jsonl              │
│ media/ (original filenames)      │──────→  │ Media/ (UUID filenames)      │
└──────────────────────────────────┘         └──────────────────────────────┘

BackupManager.importBackup()
  1. Unzip to temp directory
  2. Decode BackupManifest (iOS legacy models)
  3. db.bootstrapIfNeeded() — ensure directories exist
  4. Import media files via db.importMedia() → build filename mapping
  5. Map iOS models → TimeMasterCore models
     - Workout → WorkoutManifest (sections: [WorkoutSectionManifest])
     - WorkoutHistoryEntry → HistoryEntry
     - ExerciseFolder (recursive) → folder tree + ExerciseManifest
     - Exercise → ExerciseManifest
  6. Write via DatabaseManager:
     - db.createExercise(id:, manifest:, parentPath:)
     - db.createWorkout(id:, manifest:)
     - db.appendHistoryEntry()
  7. Refresh stores:
     - DatabaseStore.shared.reload()
     - WorkoutStore().reload() (fixed to check isMigrated)
  8. Return ImportSummary
```

## Model Mapping

| iOS Legacy Model | TimeMasterCore Model | Notes |
|---|---|---|
| `Workout` | `WorkoutManifest` | Sections: `Section` → `WorkoutSectionManifest`, `mediaItems` → `mediaFilenames` |
| `WorkoutHistoryEntry` | `HistoryEntry` | ID: UUID → String |
| `ExerciseFolder` (recursive) | folder tree via `db.createFolder()` | Name sanitized, exercises flattened to `ExerciseManifest` |
| `Exercise` | `ExerciseManifest` | `description` → `details`, `mediaItems` → `mediaFilenames` (UUID-mapped) |
| `DatabaseNote` | N/A (future: stored alongside folder) | Notes not migrated to file system in this phase |

### Media Filename Mapping
- Imported media gets UUID filenames via `db.importMedia()`
- Build `[originalFilename: newUUIDFilename]` mapping
- Replace all `mediaItems.map(\.filename)` references with UUID filenames in manifests

### Folder Tree Mapping
```
ExerciseFolder(name: "Upper Body")
  subfolders: [
    ExerciseFolder(name: "Push")
      exercises: [Exercise(name: "Push-ups")]
  ]
  exercises: [Exercise(name: "Arm Circles")]
```
Becomes:
```
Exercises Database/
  Upper Body/
    Push/
      {uuid}/manifest.json  (Push-ups)
    {uuid}/manifest.json    (Arm Circles)
```

## States

| State | Trigger | Behavior |
|---|---|---|
| Import ZIP, post-migration | User selects backup ZIP file | Manifests written to file system via DatabaseManager; media imported with UUID filenames; stores refreshed from fs |
| Import ZIP, pre-migration | Migration not yet run | ZIP imported to both file system (via DatabaseManager) AND UserDefaults (legacy path) for backward compat |
| Duplicate exercise ID | Exercise already exists in file system | Skip — do not overwrite existing manifest |
| Duplicate workout ID | Workout folder already exists | Skip — do not overwrite existing manifest |
| Media import failure | Source media file corrupted or missing | Log warning, skip that file, continue import |
| Empty backup | ZIP contains manifest with 0 items | ImportSummary reports 0 items, no file writes |

## Files

- **create:** `features/F05-A-v2-import/DOCKS.md` — this spec
- **modify:** `TimeMaster/Utilities/BackupManager.swift` — rewire import to DatabaseManager
- **modify:** `TimeMaster/ViewModels/WorkoutStore.swift` — fix `reload()` to check `isMigrated`
- **modify:** `TimeMaster/Views/Database/DatabaseView.swift` — update import handler, show summary
- **modify:** `TimeMaster/Views/Settings/BackupView.swift` — update import handler, show summary

## Dependencies

- F09-A — TimeMasterCore (verified: 49 tests pass, macOS arm64, 2026-07-06)
- F01-A — Migrate models to file manifests (verified: 14 MigrationTests + 49 existing = 63 tests pass, 2026-07-09)

## Verification

- [ ] DOCKS.md created and reviewed
- [ ] `importBackup()` writes exercises to `Exercises Database/` with manifest.json + guide.md
- [ ] `importBackup()` writes workouts to `Workouts/{id}/manifest.json`
- [ ] `importBackup()` appends history entries to `History/entries.jsonl`
- [ ] Imported media files have UUID filenames in `Media/`
- [ ] Manifest exercise references use UUID filenames (not original filenames)
- [ ] Duplicate items (same ID) are skipped, not overwritten
- [ ] `WorkoutStore.reload()` reads from file system post-migration
- [ ] Post-import, `DatabaseStore.reload()` reflects imported exercises
- [ ] Post-import, `WorkoutStore().reload()` reflects imported workouts + history
- [ ] All 63 existing tests still pass
- [ ] ImportSummary returns correct counts (exercises, workouts, history, media)
