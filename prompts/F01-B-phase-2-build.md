# Phase 2 of F01-B — ExercisePageManifest + DatabaseManager Rewrite

## Context
We are building the V2 Notion-style Unified Page Model. Phase 1 was documentation-only — we wrote a comprehensive DOCKS.md. Phase 2 now implements the data model and file-system layer in TimeMasterCore. No UI changes yet.

## What You Need to Read First
- `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md` — the full spec (this is YOUR blueprint)
- `TimeMasterCore/Sources/Models/ExerciseManifest.swift` — the old manifest to extend from
- `TimeMasterCore/Sources/DatabaseManager.swift` — current CRUD operations to extend
- `TimeMasterCore/Sources/MigrationManager.swift` — current migration logic
- `TimeMasterCore/Sources/Models/SchemaDefinition.swift` — schema generation
- `TimeMasterCore/Sources/Models/WorkoutType.swift` — shared type
- `TimeMasterCore/Sources/FileSystemHelper.swift` — atomic writes, directory ops
- `TimeMaster/ViewModels/DatabaseStore.swift` — current store (for understanding migration target)

## What Happened Last Session (Phase 1)
- Wrote comprehensive F01-B DOCKS.md covering: ExercisePageManifest model, ExercisePage runtime model, DatabaseManager page CRUD, PageTreeBuilder, states (9 states), animations (9 rules), media/file storage design, migration path from ExerciseManifest/ExerciseFolder/DatabaseNote → ExercisePageManifest, verification checklist (31 items).
- Decorated features/DOCKS.md: F01-B status changed from "pending" to "documenting"
- Updated CYCLES.md: added DOCKS.md completion checkbox

## What to Build

### Task 1 — ExercisePageManifest Model
Create `TimeMasterCore/Sources/Models/ExercisePageManifest.swift`:
- Codable struct with all fields per DOCKS.md
- `LinkMetadata` and `LinkPlatform` nested types
- Init with sensible defaults
- CodingKeys for snake_case JSON persistence
- `kind` computed property returning "page"

### Task 2 — ExercisePage Runtime Model
Create `TimeMaster/Models/ExercisePage.swift`:
- Wraps ExercisePageManifest + resolved URLs
- Computed properties: isContainer, isLeaf, isRoot, hasWorkoutConfig, hasCover, hasLinks, hasMedia, hasMarkdown, totalChildCount
- children: [ExercisePage] for tree structure
- coverImageURL, mediaURLs resolved from filenames

### Task 3 — DatabaseManager Page CRUD
Modify `TimeMasterCore/Sources/DatabaseManager.swift`:
- Add `createPage(manifest: ExercisePageManifest, parentID: String?) throws`
- Add `updatePage(id: String, manifest: ExercisePageManifest, newParentID: String?) throws`
- Add `deletePage(id: String) throws` — moves folder to .trash/
- Add `getPage(id: String) throws -> ExercisePageManifest`
- Add `searchPages(query: String, type: WorkoutType?) throws -> [(ExercisePageManifest, path: String)]`
- Add `walkPageTree(in directory: URL) throws -> [(ExercisePageManifest, path: String)]`
- Add `movePage(id: String, newParentID: String?, newOrder: Int) throws`
- Add `getPagePath(id: String) throws -> String` — breadcrumb path string
- Add `listRootPages() throws -> [(name: String, path: String, manifest: ExercisePageManifest)]`
- Ensure guide.md is created/updated with markdownBody on createPage/updatePage
- Deprecate old exercise methods with `@available(*, deprecated, message: "Use page-based API")`

### Task 4 — PageTreeBuilder Utility
Create `TimeMaster/ViewModels/PageTreeBuilder.swift`:
- `build(from flatList: [ExercisePage]) -> [ExercisePage]` — constructs nested tree from flat list using parentID
- `breadcrumbs(for pageID: UUID, in flatList: [ExercisePage]) -> [ExercisePage]` — ancestor chain

### Task 5 — Migration Logic
Add `migrateToV2Pages()` to `MigrationManager`:
- Walk entire Exercises Database/ directory tree
- For each directory WITH manifest.json:
  - Try decode as ExerciseManifest (old) → convert to ExercisePageManifest
  - Write updated manifest.json
  - Ensure guide.md exists with full content
- For each directory WITHOUT manifest.json (legacy folders):
  - Create ExercisePageManifest from directory name
  - Record child directory IDs
  - Write manifest.json
- Auto-backup Exercises Database/ to Backups/ before migration
- Set migration marker: UserDefaults "migration_v2_pages_complete" = true
- Do NOT create duplicate pages — check for existing ExercisePageManifest first

### Task 6 — DatabaseStore Rewrite
Modify `TimeMaster/ViewModels/DatabaseStore.swift`:
- Replace `rootFolders`, `rootNotes`, `rootExercises` with `rootPages: [ExercisePage]` + `allPagesFlat: [ExercisePage]`
- `loadFromFileSystem()` calls `walkPageTree` + `PageTreeBuilder.build()`
- CRUD methods rewritten for page operations
- Keep backward-compatible load path for pre-migration state
- `page(id:)`, `children(of:)`, `breadcrumbs(for:)` lookup methods
- `reload()` triggers full tree rebuild

### Task 7 — Schema Update
Modify `SchemaDefinition` / `SchemaManager` to include ExercisePageManifest in the generated `schema.json`.

## Files to Create/Modify
- **create:** `TimeMasterCore/Sources/Models/ExercisePageManifest.swift`
- **create:** `TimeMaster/Models/ExercisePage.swift`
- **create:** `TimeMaster/ViewModels/PageTreeBuilder.swift`
- **modify:** `TimeMasterCore/Sources/DatabaseManager.swift`
- **modify:** `TimeMasterCore/Sources/MigrationManager.swift`
- **modify:** `TimeMasterCore/Sources/Models/ExerciseManifest.swift` — add deprecation warning
- **modify:** `TimeMaster/ViewModels/DatabaseStore.swift`
- **modify:** `TimeMasterCore/Sources/Models/SchemaDefinition.swift` — add page schema
- **modify:** `TimeMaster/Models/ExerciseDatabase.swift` — add ExercisePage, deprecate old types

## Verification
- [ ] ExercisePageManifest Codable round-trip test
- [ ] ExercisePageManifest with all optionals nil encodes without error
- [ ] walkPageTree returns pages from 5-level deep nesting
- [ ] walkPageTree handles empty directories gracefully
- [ ] createPage creates directory + manifest.json + guide.md at correct path
- [ ] updatePage updates manifest.json and guide.md
- [ ] movePage renames/moves directory on disk, updates parentID
- [ ] deletePage moves folder + children to .trash/
- [ ] getPagePath returns correct breadcrumb string
- [ ] searchPages filters by title, content, type
- [ ] PageTreeBuilder.build() constructs correct tree from flat list
- [ ] PageTreeBuilder.breadcrumbs() returns ancestor chain
- [ ] DatabaseStore loads pages correctly from file system
- [ ] Migration: ExerciseManifest → ExercisePageManifest no data loss
- [ ] Migration: ExerciseFolder → ExercisePageManifest with children
- [ ] Migration: backup created before migration
- [ ] Migration: marker prevents re-migration
- [ ] macOS arm64 build succeeds
- [ ] All 63 existing core tests pass (no regressions)

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create `prompts/F01-B-phase-3-store-ui.md` for the DatabaseStore rewrite + UI updates.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
