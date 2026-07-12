# Phase 1 of F01-B — Unified Page Model (Documentation)

## Context
TimeMaster V2.0 — Revolution REV-01 is complete. F06-B (AI Database Creation via Tool Calling) has been built and verified. All V1 features and the file-based data architecture are done. We now move into Cycle 7 — V2: Notion-Style Rework, starting with F01-B: Unified Page Model.

## What You Need to Read First
- `genesis/IDEA.md` — the V2 vision (47 lines)
- `genesis/IDEAS.md` — expanded ideas
- `features/DOCKS.md` — feature index (see V2 Sub-Features section)
- `CYCLES.md` — current cycle tracking
- `features/F09-file-based-data/F09-A-timemastercore/DOCKS.md` — current data model (ExerciseManifest, WorkoutManifest)
- `TimeMasterCore/Sources/Models/ExerciseManifest.swift` — current exercise model
- `TimeMasterCore/Sources/DatabaseManager.swift` — current database operations
- `TimeMaster/ViewModels/DatabaseStore.swift` — current store (ExerciseFolder, Exercise models)

## What Happened Last Session (F06-B)
- Tool schemas enhanced: `create_exercise` now accepts `restAfter`, `mediaFilenames`, `linkURLs`. `build_workout` accepts `restBetweenSections`. New `get_stats` tool added.
- ToolRouter wired to use all new parameters.
- Database context injected into AI system prompt via `AISystemPromptBuilder.buildSessionContext()`.
- Approval gate for write operations using `CheckedContinuation` — user must tap Approve/Reject in chat.
- `ApprovalCardView` UI with Approve/Reject buttons, input bar disabled during pending approval.
- `DatabaseStore.reload()` called after AI tool calls complete.
- macOS arm64 build succeeds. Fixes for pre-existing compile errors in `ExerciseNamingService.swift` and `DatabaseView.swift`.
- Committed as `2673201 — feat(F06-B): AI database creation via tool calling`.

## What to Build

### Phase 1 — DOCKS.md for F01-B (THIS SESSION)
There is NO DOCKS.md for F01-B yet. This session is documentation-only.

1. **Read the V2 vision** from `genesis/IDEA.md` (key excerpt):
   - Every exercise becomes a "page" (notion-style) — click opens rich view, not edit form
   - Every folder is also a page — no distinction between folders and exercises
   - Cover images on pages (replacing folder icons)
   - Unlimited nesting: parent/child pages at any depth
   - Media inline: images, videos, embeds (YouTube, Instagram)
   - Link attachments with previews
   - External links on every page (including nested children)
   - Every page is structured: cover image, markdown body, media, links, nested sub-pages

2. **Create `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md`:**
   - Define the `ExercisePage` data model — what replaces `ExerciseFolder` + `Exercise` + `DatabaseNote`
   - Define properties: id, title, coverImageFilename, markdownBody, mediaFilenames, linkURLs, workoutType, childPages[], createdAt, updatedAt
   - Define the file-system storage: each page is a folder? Or pages stored as JSON?
   - Architecture diagram showing how page nesting works
   - States: default, loading, empty, editing, viewing media, viewing links
   - Relationship to existing models (migration path from ExerciseManifest + ExerciseFolder)
   - Dependencies: F09-A (TimeMasterCore), F01 (Core Data Layer)
   - Verification checklist

3. **Update `features/DOCKS.md` index** — change F01-B status from "pending" to "documenting"

## Files to Create/Modify
- **create:** `features/F01-unified-page-model/` directory
- **create:** `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md` — comprehensive spec
- **modify:** `features/DOCKS.md` — update F01-B status
- **modify:** `CYCLES.md` — add task for F01-B DOCKS.md creation

## Verification
- [ ] IDEA.md vision fully understood
- [ ] Current models (ExerciseManifest, ExerciseFolder, WorkoutManifest) reviewed
- [ ] DOCKS.md written with complete architecture, states, animations, files, dependencies
- [ ] Migration path from existing models documented
- [ ] features/DOCKS.md index updated
- [ ] CYCLES.md updated

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "docs(F01-B): unified page model DOCKS.md"
3. **UPDATE CYCLES.md:** Mark F01-B documentation task `[x]`.
4. **GENERATE THE NEXT PROMPT:** After DOCKS.md is written, create `prompts/F01-B-phase-2-build.md` for building the model.

## When You Finish
Report what was documented, what design decisions were made, and the path to the next prompt file.
