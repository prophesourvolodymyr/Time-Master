# Phase 1 of F06-B — AI Database Creation via Tool Calling

## Context
TimeMaster V2.0 — Revolution REV-01. F01-A (migrate models to file manifests), F09-A (TimeMasterCore), F09-D (AI Tool Calling), and F05-A-v2 (import rewired to file-based) are all built and verified. The AI chat in AICoachView now needs the ability to create exercise records directly in the file-based database via DatabaseManager tool calls.

## What You Need to Read First
- `features/F06-ai-coach/F06-B-ai-database-creation/DOCKS.md` — this feature spec
- `features/F09-file-based-data/F09-D-ai-tool-calling/DOCKS.md` — tool calling architecture
- `TimeMaster/ViewModels/AIStore.swift` — current AI messaging, streaming, provider config (819 lines)
- `TimeMaster/Views/AICoach/AICoachView.swift` — chat UI
- `TimeMaster/ViewModels/DatabaseStore.swift` — current database store (reads from file system post-migration)
- `TimeMasterCore/Sources/DatabaseManager.swift` — `createExercise()`, `searchExercises()`, `createWorkout()`, etc.
- `TimeMasterCore/Sources/AISystemPromptBuilder.swift` — builds system prompt from Knowledge/ files

## What Happened Last Session
F05-A-v2 was built and verified:
- `BackupManager.importBackup()` rewired from UserDefaults to file-based writes via DatabaseManager
- ImportSummary struct returned with counts (exercises, workouts, history, media)
- Media imported with UUID filenames via `db.importMedia()`
- Duplicate detection (checks if directory exists before writing)
- `WorkoutStore.reload()` fixed to check `isMigrated` and load from file system
- Callers (DatabaseView, BackupView) updated to show import summary
- macOS arm64 build succeeds, all 63 core tests pass (2026-07-11)

## What to Build

### 1. Tool Schema Definitions
Add database creation tool schemas to the AI provider's tool-calling mechanism:
- `create_exercise`: params (name, details, duration, restAfter, workoutType?, parentPath?, mediaFilenames?)
- `create_workout`: params (name, type, sections[], restBetweenSections?)
- `search_exercises`: params (query, type?)
- `get_stats`: no params (returns streak, count, total duration)

### 2. Tool Router Integration
Wire tool call responses → DatabaseManager methods in AIStore. When the AI function-calling loop receives a `create_exercise` tool call:
- Extract parameters from the tool call JSON
- Call `DatabaseManager.shared.createExercise(id:, manifest:, parentPath:)`
- Return confirmation message to continue the conversation
- Show approval gate for write operations if needed

### 3. Chat UI for Tool Calls
- When tool call is in progress, show a small indicator in the chat
- When tool call completes, append an assistant message describing what was created
- Approval cards for writes (tap "Approve" to proceed)

### 4. System Prompt Enhancement
- Inject exercise database context into the AI system prompt (list of existing exercises, folders)
- Use `AISystemPromptBuilder` to read Knowledge/ files + current database state

## Files to Create/Modify
- **modify:** `TimeMaster/ViewModels/AIStore.swift` — add tool calling, tool router, database context
- **modify:** `TimeMaster/Views/AICoach/AICoachView.swift` — render tool call indicators + approval cards

## Verification
- [ ] F06-B DOCKS.md reviewed and understood
- [ ] AI can create an exercise in Exercises Database/ via `create_exercise` tool
- [ ] AI can search exercises via `search_exercises` tool
- [ ] AI can create a workout plan via `create_workout` tool
- [ ] Tool call indicator appears in chat UI during operation
- [ ] Approval card shown for write operations (create/update/delete)
- [ ] Created exercises appear in DatabaseView immediately after creation
- [ ] System prompt includes existing database context (exercise list)
- [ ] All 63 existing tests still pass
- [ ] macOS arm64 build succeeds

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F06-B): AI database creation via tool calling"
3. **UPDATE CYCLES.md:** After verifying, mark F06-B tasks `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** Read the next pending feature's DOCKS.md and create the prompt file.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
