# Phase 1 of F09-D — AI Tool Calling

## Context
TimeMaster V2.0 — Revolution REV-01. F09-A (TimeMasterCore), F09-B (Knowledge Layer), and F09-C (CLI Tool) are built and verified. F09-D enables the in-app AI Coach to query and modify the exercise database, build workouts, and access analytics through a structured function-calling loop. The AI emits tool calls; the app executes them via `TimeMasterCore`; results flow back into the conversation.

## What You Need to Read First
- `features/F09-file-based-data/F09-D-ai-tool-calling/DOCKS.md` — full spec
- `TimeMasterCore/Sources/DatabaseManager.swift` — all public API surface (create/read/update/delete/search exercises, workouts, stats, config)
- `TimeMasterCore/Sources/Models/` — ExerciseManifest, WorkoutManifest, WorkoutType, HistoryEntry, ConfigManifest
- `TimeMasterCore/Sources/AISystemPromptBuilder.swift` — builds system prompt from Knowledge/*.md
- `TimeMaster/ViewModels/AIProvider.swift` (lines 1-60 for structure, then full file) — existing provider registry
- `TimeMaster/ViewModels/AIStore.swift` — existing conversation management
- `TimeMaster/Views/AICoach/AICoachView.swift` — existing chat UI

## What Happened Last Session
F09-C CLI Tool was built and verified. The package now includes:
- `timemaster-tool` executable target — 13 sub-commands routing through DatabaseManager
- 49 tests total (36 core + 13 CLI), 0 failures, macOS arm64
- `SchemaManager.validateAll()` walks all exercises + workouts, returns validation results
- CLI supports `TIMEMASTER_DATA_ROOT` env var for test isolation
- Auto-bootstrap on first invocation, JSON I/O, STDIN support (`-`), exit codes

F09-B provided:
- `AISystemPromptBuilder` — reads Knowledge/*.md, concatenates for system prompt

F09-A provided:
- `DatabaseManager` — full CRUD, search, stats, approval gate, history JSONL
- All models ready for tool execution

## What to Build

### 1. ToolRouter (`TimeMaster/ViewModels/ToolRouter.swift`)
Create a new ToolRouter that routes function calls to DatabaseManager:
```swift
final class ToolRouter {
    let db: DatabaseManager
    func execute(toolName: String, args: [String: Any]) async -> ToolResult
}
```
Tool definitions to implement (from F09-D DOCKS.md):

| Tool | Parameters | Returns | Description |
|---|---|---|---|
| `search_exercises` | query: string, type?: string | Exercise[] | Fuzzy search by name, type |
| `get_exercise` | id: string | Exercise (full + guide.md) | Return manifest + guide.md |
| `list_folders` | parentID?: string | Folder[] | List folders (progressions, categories) |
| `create_exercise` | name, type?, duration?, parentID? | Exercise | Create new exercise folder + manifest |
| `create_folder` | name, parentID? | Folder | Create a progression/category folder |
| `get_recent_workouts` | days?: number | Workout[] | Recent completed workouts |
| `build_workout` | name, type?, sections[] | Workout | Build a workout from exercise IDs |
| `get_analytics` | type?: string, days?: number | Stats | Workout count, streak, volume |
| `add_media_note` | exerciseID, note: string | void | Append a note to exercise's guide.md |

Each tool maps to an existing DatabaseManager method. ToolRouter takes the tool name + args, calls the right DB method, and returns structured results.

### 2. Session Context Builder
Extend `AISystemPromptBuilder` or create a new helper that builds session startup context (per F09-D DOCKS.md):
```json
{
  "knowledge": "<concatenated Knowledge/*.md>",
  "database": {
    "totalExercises": N,
    "byType": { "Strength": N, ... },
    "folders": [...]
  },
  "recentActivity": {
    "last7Days": N,
    "currentStreak": N,
    "lastWorkout": "..."
  },
  "schedule": { "trainingDays": [...], "durationMonths": N }
}
```
This is injected at session start without requiring tool calls.

### 3. Tool Schema Registration in AIProvider
Define tool schemas in the AI message system prompt. Each tool needs:
- `name` — exact tool name
- `description` — what it does
- `parameters` — JSON Schema for arguments
Add a `buildToolSchemas()` or `toolDefinitions` property that returns the OpenAI-compatible function definitions list.

### 4. Function-Calling Loop in AIStore / AIProvider
The AI sends a response with `tool_calls` → app executes via ToolRouter → result inserted as "tool" role message → AI continues. Key rules:
- Max 5 tool calls per user message
- Tool execution must be synchronous (pause streaming, execute, resume)
- Write operations go through approval gate
- On tool execution failure: error inserted as context, AI explains to user

### 5. Knowledge Injection on Session Start
When a new chat session starts:
- Read `Knowledge/*.md` via `AISystemPromptBuilder`
- Build session context (exercise counts, recent activity, schedule)
- Inject as first system message

## Files to Create/Modify
- create: `TimeMaster/ViewModels/ToolRouter.swift`
- modify: `TimeMaster/ViewModels/AIProvider.swift` — add tool schema definitions
- modify: `TimeMaster/ViewModels/AIStore.swift` — function-calling loop + context injection
- modify: `TimeMaster/Views/AICoach/AICoachView.swift` — UI updates for tool call states
- modify: `TimeMasterCore/Sources/AISystemPromptBuilder.swift` — session context builder (optional extension)

## Verification
- [ ] AI can search exercises and return relevant results
- [ ] AI can create a new exercise from user description
- [ ] Tool call failure shows error in chat, doesn't crash
- [ ] Max 5 tool calls enforced, AI responds after
- [ ] Session context includes correct exercise counts
- [ ] Knowledge files injected at session start
- [ ] Streaming pauses correctly during tool execution, resumes after
- [ ] All 49 existing tests still pass

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F09-D): AI tool calling — ToolRouter, function-calling loop, context injection"
3. **UPDATE CYCLES.md:** After verifying, mark F09-D tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Read `features/F09-file-based-data/F09-E-mac-app/DOCKS.md` and create `prompts/F09-E-phase-1-mac-app.md`.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
