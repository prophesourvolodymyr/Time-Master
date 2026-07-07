# Phase 1 of F09-A — TimeMasterCore Shared Library

## Context
TimeMaster V2.0 — Revolution REV-01. We are converting the app's data layer from UserDefaults JSON blobs to a transparent, AI-readable file-system database. F09-A builds the shared Swift library that is the single writer and validator for the entire database. Both iOS app, Mac app, and CLI tool will route through this library.

## What You Need to Read First
- `genesis/REVOLUTION-rev-01-file-based-data.md` (the revolution doc — scope, migration, risks)
- `features/F09-file-based-data/DOCKS.md` (directory tree, key rules, architecture)
- `features/F09-file-based-data/F09-A-time-master-core/DOCKS.md` (full spec — this is your build doc)
- `features/F01-core-data-layer/DOCKS.md` (existing models that need file-based counterparts)
- `TimeMaster/Models/Workout.swift` (Workout, Section, WorkoutType — models to port)
- `TimeMaster/Models/ExerciseDatabase.swift` (Exercise, ExerciseFolder, MediaItem — models to port)
- `TimeMaster/ViewModels/WorkoutStore.swift` (current persistence — UserDefaults to replace)
- `TimeMaster/ViewModels/DatabaseStore.swift` (current DB persistence — UserDefaults to replace)

## What Happened Last Session
Cycle 5 completed: dynamic workout types (struct with icon+color), analytics rework (calendar page, vacation sheet, schedule card), section reorder fix, prepare time. Revolution REV-01 documented — F09-A through F09-D DOCKS.md files written, CYCLES.md restructured, features/DOCKS.md index updated. No code has been written for F09 yet.

## What to Build

### 1. Swift Package: TimeMasterCore
- Create `TimeMasterCore/` as a new Swift Package in the project
- Target: pure Swift, no UI dependencies, macOS + iOS compatible
- Package.swift with library target (not executable)

### 2. File-Based Models
- `ExerciseManifest.swift` — Codable struct mirroring Exercise model + file-system fields (id, name, type, duration, restAfter, sets, mediaFilenames, linkURLs, createdAt, updatedAt)
- `WorkoutManifest.swift` — Codable struct mirroring Workout model (id, name, type, sections array referencing exercise IDs, musicTrackFilenames, colorHex, createdAt)
- `HistoryEntry.swift` — append-only JSONL entry struct
- `ConfigManifest.swift` — settings, custom types, training schedule
- `SchemaDefinition.swift` — Codable struct that represents the entire schema.json contract (objects, their properties, tools, filesystem layout)

### 3. DatabaseManager
- Singleton class: owns all read/write/search operations
- `bootstrapIfNeeded()` — creates the full directory tree on first launch (`~/Documents/TimeMaster/` with all subdirectories)
- `createExercise(id:, manifest:)` — creates `Exercises Database/{id}/` folder, writes `manifest.json`
- `updateExercise(id:, manifest:)` — validates, writes updated manifest, saves old to `.trash/`
- `deleteExercise(id:)` — moves folder to `.trash/{timestamp}-{id}/` (never actually deletes)
- `getExercise(id:)` — reads and validates a single manifest
- `searchExercises(query:, type?)` — walks directory tree, filters by name/type, returns results
- `listFolders(parentID?)` — returns subdirectories of Exercises Database/
- `createFolder(name:, parentID?)` — creates a progression/category folder
- `createWorkout(...)` / `listWorkouts()` — workout CRUD in Workouts/ directory
- `getStats(type?, days?)` — analytics: workout count, streak, volume

### 4. FileSystemHelper
- `writeAtomically(to:, data:)` — write to temp file, validate, `rename()` to target — never corrupt
- `readManifest(from:)` — reads and decodes JSON, returns result or error
- `listDirectory(_:)` — returns entries, skipping non-schema folders
- `ensureDirectory(_:)` — creates if missing
- `moveToTrash(path:)` — moves to `.trash/{timestamp}-{name}/`
- `trashDirectory` / `dataRoot` — computed paths

### 5. SchemaManager
- `generateSchema()` — walks Swift type metadata, generates `schema.json` at root
- `validate(manifest:, type:)` — checks required fields, types, relationships
- Schema.json structure: `{ version, objects: { exercise, workout, historyEntry, config }, tools: [...], filesystem: {...} }`

### 6. AI Safety
- `.trash/` folder created at bootstrap
- `approveWrite(operation:)` — returns a preview struct that the UI can display (name, what will change, preview content)
- No actual write happens until approval is confirmed
- This is a model-only function — the UI gate is built later in F09-D

### 7. MigrationManager
- `migrateFrom(woroutStore:, databaseStore:)` — reads existing UserDefaults data, creates file-based structure
- Handles: workouts → Workouts/, exercises → Exercises Database/, history → History/entries.jsonl, settings → Config/
- Backs up UserDefaults to `Backups/migration-{date}.json` before migration
- Reports migration summary (counts of each type migrated)

## Files to Create/Modify
- create: `TimeMasterCore/Package.swift`
- create: `TimeMasterCore/Sources/Models/ExerciseManifest.swift`
- create: `TimeMasterCore/Sources/Models/WorkoutManifest.swift`
- create: `TimeMasterCore/Sources/Models/HistoryEntry.swift`
- create: `TimeMasterCore/Sources/Models/ConfigManifest.swift`
- create: `TimeMasterCore/Sources/Models/SchemaDefinition.swift`
- create: `TimeMasterCore/Sources/DatabaseManager.swift`
- create: `TimeMasterCore/Sources/SchemaManager.swift`
- create: `TimeMasterCore/Sources/MigrationManager.swift`
- create: `TimeMasterCore/Sources/FileSystemHelper.swift`
- create: `TimeMasterCore/Tests/DatabaseManagerTests.swift`
- create: `TimeMasterCore/Tests/SchemaValidationTests.swift`

## Verification
- [ ] Package compiles for both macOS and iOS
- [ ] `bootstrapIfNeeded()` creates full directory tree at correct path
- [ ] `createExercise` creates folder + valid manifest.json + guide.md
- [ ] `deleteExercise` moves to .trash/ with timestamp, not permanently deleted
- [ ] `searchExercises` returns filtered results from nested folders
- [ ] `writeAtomically` does not corrupt on crash
- [ ] `validate` rejects manifest with missing required fields
- [ ] `generateSchema` produces valid JSON matching SchemaDefinition
- [ ] `migrateFrom` converts all existing UserDefaults data without loss
- [ ] External folder (unknown schema) in root does not cause errors
- [ ] compiles without errors on macOS target

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F09-A): TimeMasterCore shared library with file-based database"
3. **UPDATE CYCLES.md:** After verifying, mark F09-A tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Create `prompts/F09-B-phase-1-knowledge-layer.md`. F09-B builds the Knowledge/ folder + AGENTS.md bootstrap + skills/ directory. Read `features/F09-file-based-data/F09-B-knowledge-layer/DOCKS.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
