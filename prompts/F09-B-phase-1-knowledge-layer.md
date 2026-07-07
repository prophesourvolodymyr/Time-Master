# Phase 1 of F09-B — Knowledge Layer + AGENTS.md

## Context
TimeMaster V2.0 — Revolution REV-01. F09-A is built and verified. The Knowledge layer is the next piece: it materializes the AI-readable metadata layer inside the data directory. When the app boots or an AI session starts, `Knowledge/*.md` files are concatenated into the system prompt. The root `AGENTS.md` tells external AI agents how to use the data directory. The `skills/` folder contains reusable skill definitions.

## What You Need to Read First
- `features/F09-file-based-data/F09-B-knowledge-layer/DOCKS.md` (full spec — this is your build doc)
- `features/F09-file-based-data/DOCKS.md` (directory tree, key rules)
- `genesis/REVOLUTION-rev-01-file-based-data.md` (context)
- `TimeMasterCore/Sources/FileSystemHelper.swift` (paths for Knowledge/ and skills/)
- `TimeMasterCore/Sources/DatabaseManager.swift` (bootstrap integration point)

## What Happened Last Session
F09-A TimeMasterCore was built and verified as a standalone Swift Package. All 25 tests pass on macOS arm64. The package includes:
- `TimeMasterCore/Package.swift` — Swift Package targeting macOS 13+ and iOS 16+
- Models: WorkoutType, ExerciseManifest, WorkoutManifest, HistoryEntry, ConfigManifest, SchemaDefinition
- `FileSystemHelper.swift` — atomic writes, directory ops, `.trash/` soft-delete with timestamped folders
- `SchemaManager.swift` — generates `schema.json`, validates manifests against schema
- `DatabaseManager.swift` — singleton, full CRUD, search, stats, approval gate, history JSONL
- `MigrationManager.swift` — UserDefaults → file-system migration with backup
- 25 tests (17 DatabaseManager + 8 SchemaValidation), 0 failures

## What to Build

### 1. AISystemPromptBuilder
- Create `TimeMasterCore/Sources/AISystemPromptBuilder.swift`
- `buildSystemPrompt() -> String` — scans `Knowledge/` directory, concatenates all `*.md` files, returns combined string
- `listKnowledgeFiles() -> [URL]` — returns sorted list of .md files in Knowledge/
- Handles empty Knowledge/ gracefully (returns empty string, not error)
- Skips hidden files (starting with `.`)
- Files are concatenated in alphabetical order, separated by `\n\n---\n\n`

### 2. Bootstrap Integration
- Update `DatabaseManager.bootstrapIfNeeded()` to also create:
  - `AGENTS.md` at data root with complete bootstrap guide
  - `skills/create-exercise.md` — instructions for AI agents to create exercises
  - `skills/build-workout.md` — instructions for AI agents to build workouts
  - `skills/search-database.md` — instructions for AI agents to search the database
- AGENTS.md content must include:
  - What this directory is (TimeMaster data directory)
  - Full directory structure explanation
  - How to interact (use `timemaster-tool` CLI)
  - List of available commands
  - Reference to `schema.json` for the data contract
  - Which folders are safe to read/write
  - Workspace/ is free for AI use

### 3. Skill Files Content
Each skill file is a markdown document that an AI agent can load and follow.

**create-exercise.md:**
```markdown
# create-exercise
Create a new exercise in the TimeMaster database.

## Steps
1. Generate a UUID for the exercise ID
2. Determine the parent folder path (e.g., "Upper Body/Push")
3. Create the exercise manifest with required fields: id, name, duration, restAfter
4. Write the manifest.json via `timemaster-tool create-exercise`
5. Optionally create guide.md with instructions and details
```

**build-workout.md:**
```markdown
# build-workout
Assemble a workout plan from exercises in the database.

## Steps
1. Search for exercises using `timemaster-tool search-exercises`
2. Select exercises that match the user's goal and type
3. Determine section order, duration, sets, and rest periods
4. Create the workout manifest with sections referencing exercise IDs
5. Write via `timemaster-tool create-workout`
```

**search-database.md:**
```markdown
# search-database
Query the TimeMaster exercise database.

## Steps
1. Use `timemaster-tool search-exercises` with a query string
2. Filter results by workout type if needed
3. Use `timemaster-tool get-exercise` to read full details
4. Navigate folders with `timemaster-tool list-folders`
```

### 4. Default Knowledge Files
Bootstrap should create empty starter Knowledge files (user can edit):
- `Knowledge/fitness-philosophy.md` — placeholder for user's training philosophy
- `Knowledge/nutrition-rules.md` — placeholder for diet and nutrition rules
- `Knowledge/recovery-protocols.md` — placeholder for recovery and rest protocols

Each should be a valid .md file with a title and placeholder text like "Add your [topic] here."

## Files to Create/Modify
- create: `TimeMasterCore/Sources/AISystemPromptBuilder.swift`
- modify: `TimeMasterCore/Sources/DatabaseManager.swift` (bootstrap integration)
- create: `TimeMasterCore/Tests/AISystemPromptBuilderTests.swift`

## Verification
- [ ] Package compiles without errors
- [ ] `bootstrapIfNeeded()` creates `AGENTS.md` with valid content
- [ ] `bootstrapIfNeeded()` creates `skills/` with 3 .md files
- [ ] `bootstrapIfNeeded()` creates default `Knowledge/` .md files
- [ ] `buildSystemPrompt()` returns empty string when Knowledge/ is empty
- [ ] `buildSystemPrompt()` concatenates all .md files correctly
- [ ] AGENTS.md references CLI commands that match F09-C tool names
- [ ] AGENTS.md references schema.json and directory structure
- [ ] Skills files contain actionable, step-by-step instructions
- [ ] All existing 25 tests still pass

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F09-B): Knowledge layer with AGENTS.md, skills, and AI prompt builder"
3. **UPDATE CYCLES.md:** After verifying, mark F09-B tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Create `prompts/F09-C-phase-1-cli-tool.md`. F09-C builds the `timemaster-tool` CLI. Read `features/F09-file-based-data/F09-C-cli-tool/DOCKS.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
