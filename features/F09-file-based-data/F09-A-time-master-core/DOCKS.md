# F09-A — TimeMasterCore

Shared Swift package that is the single writer and validator for the entire file-based database. Both the app (iOS/Mac) and the CLI tool (F09-C) route all reads and writes through this library.

## What We Build

1. **`TimeMasterCore` Swift Package** — no UI, no platform dependencies, pure Swift
2. **Models** — `ExerciseManifest`, `WorkoutManifest`, `ConfigManifest`, `HistoryEntry` (all Codable, validated)
3. **DatabaseManager** — singleton that owns all read/write operations
4. **SchemaManager** — generates and validates `schema.json` from Swift type metadata
5. **Atomic writes** — write to temp file, validate, then `rename()` — never corrupt
6. **Validation layer** — every write checks `schema.json` constraints, rejects violations
7. **Search** — walk directory tree, parse `manifest.json` files, return filtered results
8. **Migration tool** — converts existing UserDefaults JSON blobs into the new file structure

## Architecture

```
TimeMasterCore/
├── Sources/
│   ├── Models/
│   │   ├── ExerciseManifest.swift     ← Codable, validated
│   │   ├── WorkoutManifest.swift
│   │   ├── ConfigManifest.swift
│   │   ├── HistoryEntry.swift
│   │   └── SchemaDefinition.swift     ← schema.json structure
│   ├── DatabaseManager.swift          ← read/write/search/validate
│   ├── SchemaManager.swift            ← schema.json generation
│   ├── MigrationManager.swift         ← UserDefaults → file-system
│   └── FileSystemHelper.swift         ← atomic writes, directory ops
└── Tests/
    ├── DatabaseManagerTests.swift
    └── SchemaValidationTests.swift
```

## Operations

| Function | Description |
|---|---|
| `bootstrapIfNeeded()` | Creates root directory + schema.json on first launch |
| `createExercise(id, manifest, media?)` | Creates `Exercises Database/{id}/` folder + files |
| `updateExercise(id, manifest)` | Validates + writes updated manifest |
| `deleteExercise(id)` | Removes entire exercise folder |
| `searchExercises(query, type?)` | Walks tree, filters by name/type, returns results |
| `getExercise(id)` | Reads and validates a single manifest |
| `createWorkout(...)` | Creates `Workouts/{id}/manifest.json` |
| `listWorkouts()` | Returns all workout manifests |
| `validateManifest(path)` | Checks against schema, returns errors |
| `importMedia(from:)` | Copies file to `Media/`, returns UUID filename |
| `migrate(from:)` | Converts old UserDefaults data to new structure |

## AI Safety — Never-Lose-Data Architecture

The AI can modify the database, but it cannot permanently destroy anything.

### 1. `.trash/` Folder — Soft Delete Only
- `deleteExercise(id)` moves folder to `.trash/{timestamp}-{id}/` — never actually deletes
- `updateExercise(id, ...)` saves old manifest as `.trash/{timestamp}-{id}/previous-manifest.json`
- Trash files age out after 30 days (configurable), then auto-purged
- User can browse `.trash/` in Finder or restore from the app

### 2. Approval Gate (for AI Writes)
- AI emits a write tool call → app shows a preview card:
  ```
  "Create exercise: Wall Walk in Handstand folder"
  [Preview: name, duration, type, media...]
  [Approve] [Edit] [Reject]
  ```
- Read-only tool calls (search, list, get) execute immediately — no gate
- User can toggle "auto-approve" per session for power users

### 3. Auto-Backup Before AI Session
- When AI Coach session starts → zip the entire data directory → save to `Backups/auto-{timestamp}.zip`
- If anything goes wrong: Settings → Backups → restore the auto-backup
- Keeps last 10 auto-backups, rotates older ones

### 4. CLI Mode Safety
- `timemaster-tool` runs in `--readonly` by default unless `--write` flag passed
- `--write` flag shows warning: "This will modify your database. Snapshot saved to Backups/."

## Validation Rules
- Every `manifest.json` must have required fields per `schema.json`
- Exercise IDs must not collide with existing folders
- Media references must point to files that exist in `Media/`
- Workout sections must reference valid exercise IDs
- External folders (not matching any schema) are skipped — never error
- All destructive operations write to `.trash/` before executing

## Files
- `TimeMasterCore/` (new Swift Package)
- `TimeMasterCore/Sources/DatabaseManager.swift`
- `TimeMasterCore/Sources/Models/ExerciseManifest.swift`
- `TimeMasterCore/Sources/Models/WorkoutManifest.swift`
- `TimeMasterCore/Sources/Models/SchemaDefinition.swift`
- `TimeMasterCore/Sources/SchemaManager.swift`
- `TimeMasterCore/Sources/MigrationManager.swift`
- `TimeMasterCore/Sources/FileSystemHelper.swift`

## Dependencies
- F09 — must be defined first (schema.json, directory layout)

## Verification
- [ ] Bootstrap creates all directories on clean launch
- [ ] Search returns exercises by type, name
- [ ] Atomic write: crash during write → no corruption on restart
- [ ] Validation rejects manifest with missing required fields
- [ ] Migration converts existing UserDefaults data without data loss
- [ ] External folder at root does not cause errors
- [ ] Unlimited nesting: create 10 levels deep, all valid
