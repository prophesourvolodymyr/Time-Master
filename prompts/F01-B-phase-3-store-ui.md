# Phase 3 of F01-B — DatabaseStore UI Integration + ExercisePageDetailView

## Context
We are building the V2 Notion-style Unified Page Model. Phase 2 implemented the data model and file-system layer (ExercisePageManifest, ExercisePage, DatabaseManager page CRUD, PageTreeBuilder, MigrationManager.migrateToV2Pages(), DatabaseStore V2 rewrite, Schema update). Phase 3 connects the new data layer to the UI: the DatabaseView, ExercisePageDetailView, and the page creation/editing flow.

## What You Need to Read First
- `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md` — full spec (page detail states, media rules, animations)
- `TimeMaster/ViewModels/DatabaseStore.swift` — new V2 store (`rootPages`, `allPagesFlat`, page CRUD, PageTreeBuilder integration)
- `TimeMaster/Models/ExercisePage.swift` — runtime model wrapping ExercisePageManifest
- `TimeMaster/Models/ExerciseDatabase.swift` — old models (deprecated, still used in V1 fallback)
- `TimeMaster/Views/Database/DatabaseView.swift` — current DB view (needs V2 adaptation)
- `TimeMaster/Views/Database/DatabaseSectionPickerView.swift` — current section picker
- `TimeMaster/ViewModels/PageTreeBuilder.swift` — tree builder utility
- `TimeMasterCore/Sources/Models/ExercisePageManifest.swift` — manifest model

## What Happened Last Session (Phase 2)
- Created `ExercisePageManifest.swift` (TimeMasterCore) — full Codable struct with LinkMetadata, LinkPlatform, 20 fields
- Created `ExercisePage.swift` (app runtime model) — wraps manifest, resolved URLs, computed props (isContainer, isLeaf, hasCover, etc.)
- Created `PageTreeBuilder.swift` — flat→tree conversion + breadcrumbs utility
- Added 9 page CRUD methods to `DatabaseManager`: createPage, updatePage, deletePage, getPage, searchPages, walkPageTree, movePage, getPagePath, listRootPages
- Added `migrateToV2Pages()` to `MigrationManager` — converts ExerciseManifest/ExerciseFolder → ExercisePageManifest, creates backup, sets marker
- Rewrote `DatabaseStore` — dual-mode: V2 (rootPages + allPagesFlat) when page-migrated, V1 fallback otherwise
- Updated `SchemaManager` — added "page" object schema + 8 page tools (listPages, getPage, searchPages, createPage, updatePage, deletePage, movePage, getPagePath)
- Deprecated `ExerciseManifest`, `Exercise`, `ExerciseFolder`, old exercise CRUD
- Added new files to Xcode pbxproj
- Verified: macOS arm64 build succeeds, 63/63 core tests pass, schema test counts updated (5 objects, 18 tools)

## What to Build

### Task 1 — DatabaseView V2 Adaptation
- Read `rootPages` and `allPagesFlat` from the V2 store path
- Display page tree using PageTreeBuilder.build(from: allPagesFlat)
- Page card design: cover image (or icon/gradient fallback), title, child count badge, workout type tag
- Tap page → navigate to ExercisePageDetailView
- Long-press → context menu (delete, move, edit)
- "Create Page" button → page creation sheet
- Keep V1 fallback rendering when not yet migrated to V2 pages

### Task 2 — ExercisePageDetailView (New)
- Full-screen page view per DOCKS.md `page-detail` state:
  - Cover image hero at top (parallax on scroll)
  - Title (editable)
  - Markdown body rendered from guide.md
  - Media gallery grid (tap → fullscreen viewer)
  - Link list with platform-detected previews
  - Child pages grid below content
  - Edit button in toolbar → toggles editing state
- Page-detail-empty state: gradient placeholder, "Add content" prompt
- Animations: cover parallax (0.5 factor), child page expand (0.25s easeInOut)

### Task 3 — Page Creation / Editing Flow
- New/Edit sheet for ExercisePageManifest fields:
  - Title text field
  - Cover image picker
  - Icon picker (SF Symbols grid)
  - Workout type tag picker
  - Duration/rest/sets steppers (if has workout config)
  - Tags input
  - Markdown editor for guide.md
- Save writes via DatabaseStore.createPage / updatePage
- Delete with confirmation dialog

### Task 4 — Media Viewer Integration
- Full-screen media viewer for page media gallery
- Photos: pannable/zoomable with swipe between items
- Videos: AVPlayer inline playback
- Dismiss with tap or swipe down

### Task 5 — Link Previews
- Fetch link metadata from URLs (YouTube, Instagram, TikTok, web)
- Display platform-specific preview cards in page detail
- Cache metadata in manifest.linkMetadata

### Task 6 — Page Reorder + Move
- Drag-to-reorder pages in list (long-press + drag)
- Move page to different parent (sheet with page picker)
- Update childIDs + parentID via DatabaseStore.movePage

## Files to Create/Modify
- **create:** `TimeMaster/Views/Database/ExercisePageDetailView.swift`
- **create:** `TimeMaster/Views/Database/PageCardView.swift`
- **create:** `TimeMaster/Views/Database/PageCreationSheet.swift`
- **create:** `TimeMaster/Views/Database/PageMediaGallery.swift`
- **create:** `TimeMaster/Views/Database/PageLinkPreview.swift`
- **modify:** `TimeMaster/Views/Database/DatabaseView.swift`
- **modify:** `TimeMaster/Views/Database/DatabaseSectionPickerView.swift`
- **modify:** `TimeMaster/ViewModels/DatabaseStore.swift` — add createPage/updatePage/deletePage public wrappers

## Verification
- [ ] DatabaseView renders page tree from V2 store
- [ ] DatabaseView shows V1 fallback when not migrated
- [ ] ExercisePageDetailView shows cover + title + markdown + media + links + children
- [ ] ExercisePageDetailView empty state works
- [ ] Page creation sheet creates page on disk
- [ ] Page editing updates manifest and guide.md
- [ ] Media viewer: tap image → fullscreen, swipe between items
- [ ] Video playback works in media viewer
- [ ] Link previews fetch and display correct platform cards
- [ ] Drag-to-reorder changes childIDs order
- [ ] Move page to new parent updates parentID + filesystem
- [ ] Delete page moves to .trash/ with confirmation
- [ ] All animations per DOCKS.md spec
- [ ] macOS arm64 build succeeds
- [ ] All 63 core tests pass (no regressions)

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create the next prompt file.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
