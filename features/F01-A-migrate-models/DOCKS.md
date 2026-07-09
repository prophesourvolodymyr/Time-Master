# F01-A — Migrate Models to File Manifests

One-time migration that converts existing iOS data from UserDefaults JSON blobs into the file-system database structure managed by TimeMasterCore. After migration, all data reads come from file manifests, not UserDefaults.

## What We Build

1. **`migrateFromUserDefaults()` in MigrationManager** — reads all UserDefaults keys, converts legacy iOS model types to TimeMasterCore manifests, writes to `Exercises Database/`, `Workouts/`, `History/`, `Config/` directories.
2. **Migration marker** — `.migration_complete` file in `Config/` directory prevents re-migration.
3. **WorkoutStore migration-aware loading** — checks marker; if complete, loads from DatabaseManager (file manifests); if not, falls back to UserDefaults.
4. **DatabaseStore migration-aware loading** — same pattern: reads from file system after migration.
5. **TimeMasterApp migration trigger** — calls `MigrationManager.migrateIfNeeded()` in `init()` before stores are created.

## Architecture

```
UserDefaults JSON blobs                File System (TimeMasterCore)
┌──────────────────────┐              ┌──────────────────────────┐
│ workouts (Workout[])  │──────────────│ Workouts/{id}/manifest.json │
│ workout_history       │──────────────│ History/entries.jsonl    │
│ exercise_database_v2  │──────────────│ Exercises Database/{folders}/{id}/  │
│ root_exercises_v1     │──────────────│   manifest.json + guide.md          │
│ custom_workout_types  │──────────────│ Config/manifest.json               │
│ workout_rest_days     │              │ Config/.migration_complete          │
│ workout_weekly_goal   │              │                            │
│ workout_type_schedules│              │                            │
│ training_days/start/  │              │                            │
│   duration_months     │              │                            │
└──────────────────────┘              └──────────────────────────┘

MigrationManager.migrateFromUserDefaults()
  1. bootstrapIfNeeded() — ensures directories exist
  2. Read each UserDefaults key as Data
  3. Decode using legacy iOS model types
  4. Map to TimeMasterCore model types
  5. Write via DatabaseManager (createWorkout, createExercise, etc.)
  6. Save config (custom types, rest days, goal, schedules)
  7. Write .migration_complete marker in Config/
  8. Return MigrationSummary
```

## Data Mapping

| iOS Legacy Model | UserDefaults Key | TimeMasterCore Model | Destination |
|---|---|---|---|
| `[Workout]` | `workouts` | `WorkoutManifest` | `Workouts/{id}/` |
| `[WorkoutHistoryEntry]` | `workout_history` | `HistoryEntry` | `History/entries.jsonl` |
| `[ExerciseFolder]` | `exercise_database_v2` | `ExerciseManifest` + folder tree | `Exercises Database/{folders}/` |
| `[Exercise]` | `exercise_database_root_exercises_v1` | `ExerciseManifest` | `Exercises Database/` |
| `[WorkoutType]` | `custom_workout_types` | `ConfigManifest.customWorkoutTypes` | `Config/manifest.json` |
| `Set<String>` | `workout_rest_days` | `ConfigManifest.restDays` | `Config/manifest.json` |
| `Int` | `workout_weekly_goal` | `ConfigManifest.weeklyGoal` | `Config/manifest.json` |
| `[TypeSchedule]` | `workout_type_schedules` | `ConfigManifest.typeSchedules` | `Config/manifest.json` |
| `Set<Int>` | `training_days` | `ConfigManifest.trainingDays` | `Config/manifest.json` |
| `Double` | `training_start_date` | `ConfigManifest.trainingStartDate` | `Config/manifest.json` |
| `Int` | `training_duration_months` | `ConfigManifest.trainingDurationMonths` | `Config/manifest.json` |

### ID Mapping
- Legacy UUID → TimeMasterCore String (`.uuidString` conversion)
- Legacy WorkoutType (UUID.id string) → TimeMasterCore WorkoutType (same id/name/iconName/colorHex)
- Legacy Section (mediaItems: [MediaItem]) → WorkoutSectionManifest (mediaFilenames: [String])

### Section Mapping
```
iOS Section                    →  WorkoutSectionManifest
  id: UUID                     →  exerciseID: ""
  name: String                 →  name: String
  duration: Int                →  duration: Int
  sets: Int                    →  sets: Int
  restBetweenSets: Int         →  restBetweenSets: Int
  prepareTime: Int             →  prepareTime: Int
  customRestAfter: Int?        →  customRestAfter: Int?
  isTimerEnabled: Bool         →  isTimerEnabled: Bool
  mediaItems: [MediaItem]      →  mediaFilenames: [String] (item.filename)
```

### History Entry Mapping
```
iOS WorkoutHistoryEntry        →  HistoryEntry
  id: UUID                     →  id: String
  workoutId: UUID              →  workoutId: String
  workoutName: String          →  workoutName: String
  completedAt: Date            →  completedAt: Date
  durationCompleted: Int       →  durationCompleted: Int
  workoutType: WorkoutType     →  workoutType: WorkoutType
  isPartial: Bool              →  isPartial: Bool
  elapsedSeconds: Int          →  elapsedSeconds: Int
```

### Exercise Folder Mapping
```
iOS ExerciseFolder (recursive) →  Exercises Database/ folder tree
  name: String                 →  folder name (path component)
  workoutType: WorkoutType?    →  assigned to child exercises
  subfolders: [ExerciseFolder] →  nested directories
  exercises: [Exercise]        →  ExerciseManifest in each folder
  notes: [DatabaseNote]        →  guide.md files (title + body)
```

## States

| State | Trigger | Behavior |
|---|---|---|
| No data, first launch | App install, no UserDefaults data | Bootstrap directories, seed defaults, no migration needed |
| Has UserDefaults data, no filesystem data | App update from V1 to V2 | Migration runs: reads UserDefaults, writes files, sets marker |
| Post-migration | marker exists in Config/ | All stores read from DatabaseManager (file system) |
| Duplicate migration | marker exists, UserDefaults still has old data | Skip migration — marker prevents re-run |
| Partial migration failure | Error during migration of specific item | Backup saved to Backups/, errors logged, migration continues for remaining items |
| Migration with empty data | UserDefaults keys exist but are empty/null | Migration runs but migrates 0 items, marker still set |

## Animation Rules

N/A — migration is a synchronous, background operation with no UI.

## Files

- `features/F01-A-migrate-models/DOCKS.md` — this spec
- `TimeMasterCore/Sources/MigrationManager.swift` — add `migrateFromUserDefaults()`, `isMigrationComplete`, marker logic
- `TimeMaster/ViewModels/WorkoutStore.swift` — add migration-aware loading path
- `TimeMaster/ViewModels/DatabaseStore.swift` — add migration-aware loading path
- `TimeMaster/App/TimeMasterApp.swift` — trigger migration in `init()`
- `TimeMasterCore/Tests/MigrationTests.swift` — unit tests

## Dependencies

- F09-A — TimeMasterCore (verified: 49 tests pass, macOS arm64, 2026-07-06)
- F09-E — Mac App (verified: builds, compiles, 2026-07-07)

## Verification

- [ ] DOCKS.md created and reviewed
- [ ] `migrateFromUserDefaults()` reads all 11 UserDefaults keys correctly
- [ ] Workouts migrate with all sections, media filenames, type, color, rest settings
- [ ] History entries migrate with workoutId, type, partial flag, elapsed seconds
- [ ] Exercise folders migrate with nested structure intact (subfolders → directories, exercises → manifests)
- [ ] Root exercises migrate to Exercises Database/
- [ ] Custom workout types saved in Config/manifest.json
- [ ] Rest days, weekly goal, training schedule saved in Config/manifest.json
- [ ] Type schedules saved in Config/manifest.json with daysOfWeek, startDate, durationMonths
- [ ] `.migration_complete` marker created in Config/ after successful migration
- [ ] Second launch skips migration (marker prevents re-run)
- [ ] Migration backup JSON saved to Backups/ with timestamp
- [ ] All 49 existing DatabaseManager tests still pass
- [ ] New MigrationTests pass
- [ ] Migration generates correct folder structure under Exercises Database/
- [ ] Duplicate detection: exercises/workouts with same ID don't overwrite
- [ ] Empty UserDefaults handled gracefully (migrates 0 items)
