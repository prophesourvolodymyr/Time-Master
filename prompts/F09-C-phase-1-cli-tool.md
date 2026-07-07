# Phase 1 of F09-C — CLI Tool (`timemaster-tool`)

## Context
TimeMaster V2.0 — Revolution REV-01. F09-A (TimeMasterCore) and F09-B (Knowledge Layer) are built and verified. The CLI tool is the next piece: a thin Swift executable that wraps TimeMasterCore for external AI agents (Claude Desktop, Cursor, Terminal). All commands route through DatabaseManager — validated, atomic writes.

## What You Need to Read First
- `features/F09-file-based-data/F09-C-cli-tool/DOCKS.md` (full spec — this is your build doc)
- `features/F09-file-based-data/DOCKS.md` (directory tree, key rules)
- `TimeMasterCore/Sources/DatabaseManager.swift` (all public API surface)
- `TimeMasterCore/Sources/Models.swift` (ExerciseManifest, WorkoutManifest, etc.)
- `TimeMasterCore/Package.swift` (add executable target here)

## What Happened Last Session
F09-B Knowledge Layer was built and verified. The package now includes:
- `AISystemPromptBuilder.swift` — scans Knowledge/, concatenates *.md files for system prompt
- `DatabaseManager.bootstrapIfNeeded()` — now also creates AGENTS.md, skills/ (3 files), and Knowledge/ (3 placeholder files)
- 36 tests (20 DatabaseManager + 8 SchemaValidation + 8 AISystemPromptBuilder), 0 failures, macOS arm64

F09-A provided:
- `DatabaseManager` — full CRUD, search, stats, approval gate, history JSONL
- `FileSystemHelper` — atomic writes, directory ops, .trash/ soft-delete
- `SchemaManager` — generates schema.json, validates manifests
- All models: ExerciseManifest, WorkoutManifest, HistoryEntry, ConfigManifest, WorkoutType, etc.

## What to Build

### 1. Add Executable Target to Package.swift
Add a new executable target `timemaster-tool` that depends on `TimeMasterCore`:
```swift
.executableTarget(
    name: "timemaster-tool",
    dependencies: ["TimeMasterCore"],
    path: "CLI"
),
```

### 2. CLI Entry Point (`CLI/main.swift`)
Parse sub-command from arguments, delegate to command handlers:
- `list-exercises [--type <type>] [--query <query>]`
- `get-exercise <id>`
- `create-exercise <json>`
- `update-exercise <id> <json>`
- `delete-exercise <id>`
- `search-exercises <query> [--type <type>]`
- `list-workouts`
- `build-workout <json>`
- `import-media <path>`
- `get-stats [--type <type>] [--days <days>]`
- `list-folders [<parent-path>]`
- `list-types`
- `validate`

### 3. Command Handlers
Each command calls the corresponding `DatabaseManager` method:
- `list-exercises` → `searchAllExercises()` or `searchExercises(query:type:)`
- `get-exercise <id>` → `getExercise(id:)` + read guide.md
- `create-exercise <json>` → decode JSON to ExerciseManifest → `createExercise(id:manifest:)`
- `update-exercise <id> <json>` → decode → `updateExercise(id:manifest:)`
- `delete-exercise <id>` → `deleteExercise(id:)`
- `search-exercises <query>` → `searchExercises(query:type:)`
- `list-workouts` → `listWorkouts()`
- `build-workout <json>` → decode to WorkoutManifest → `createWorkout(id:manifest:)`
- `import-media <path>` → `importMedia(from:)`
- `get-stats` → `getStats(type:days:)`
- `list-folders` → `listFolders(parentPath:)`
- `list-types` → `loadConfig()` → custom types + built-in types
- `validate` → `schemaManager.validateAll()`

### 4. Output Formatting
- Success → JSON to STDOUT, exit 0
- Error → message to STDERR, exit 1
- Unknown command → help text to STDERR, exit 1
- Auto-bootstrap directory if not yet bootstrapped

### 5. JSON I/O
- Commands that take `<json>`: read from STDIN if arg is `-`, otherwise parse arg as JSON
- Output: pretty-printed JSON via `JSONEncoder` with `.prettyPrinted` and `.sortedKeys`

## Files to Create/Modify
- modify: `TimeMasterCore/Package.swift` (add executable target)
- create: `TimeMasterCore/CLI/main.swift`
- create: `TimeMasterCore/Tests/CLIToolTests.swift`

## Verification
- [ ] Package compiles without errors
- [ ] `swift run timemaster-tool list-exercises` returns JSON (empty array on fresh bootstrap)
- [ ] `swift run timemaster-tool create-exercise '{"id":"test","name":"Push-up","duration":30}'` creates exercise
- [ ] `swift run timemaster-tool get-exercise test` returns full manifest
- [ ] `swift run timemaster-tool search-exercises push` finds created exercise
- [ ] `swift run timemaster-tool validate` runs without errors on clean db
- [ ] Invalid command → help text, exit 1
- [ ] Invalid JSON → error message, exit 1
- [ ] All 36 existing tests still pass
- [ ] All new CLI tool tests pass

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F09-C): CLI tool wrapping TimeMasterCore for external AI agents"
3. **UPDATE CYCLES.md:** After verifying, mark F09-C tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Create `prompts/F09-D-phase-1-ai-tool-calling.md`. F09-D builds AI tool calling. Read `features/F09-file-based-data/F09-D-ai-tool-calling/DOCKS.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
