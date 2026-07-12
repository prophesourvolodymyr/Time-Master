# Phase 5 of F01-B — F05-B — Database Browser + Workout Page UI

## Context
We are building the V2 Notion-style Unified Page Model. Phase 4 completed page UI enhancement: inline video embed cards (YouTube/Instagram/TikTok with thumbnails + play overlays), cover image upload via PhotosPicker, media upload to page folders, edit-to-guide markdown integration (full guide.md loading), page reorder persistence, and breadcrumb navigation. All 63 core tests pass, macOS arm64 build succeeds.

## What You Need to Read First
- `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md` — full spec
- `features/DOCKS.md` — root index (check what F02-A-a requires)
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — detail view (Phase 3+4)
- `TimeMaster/Views/Database/PageCardView.swift` — card view (Phase 3)
- `TimeMaster/Views/Database/DatabaseView.swift` — root browser (Phase 3+4)
- `TimeMaster/Views/Database/VideoEmbedCard.swift` — video embed cards (Phase 4)
- `TimeMaster/ViewModels/DatabaseStore.swift` — V2 store (Phase 3+4)
- `TimeMasterCore/Sources/DatabaseManager.swift` — core operations (Phase 3+4)

## What Happened Last Session (Phase 4)
- Created VideoEmbedCard.swift: rich media cards with YouTube thumbnail (via `img.youtube.com/vi/{id}/hqdefault.jpg`), Instagram/TikTok/Web thumbnails via AsyncImage, play button overlays, platform-colored icons
- Created VideoEmbedListView replaced PageLinkList in ExercisePageDetailView
- Added `loadGuideContent()` to ExercisePageDetailView — reads full guide.md from disk, reloads on edit dismiss
- Added cover image upload: PhotosPicker → save to `cover.{ext}` → update manifest, preview in PageCreationSheet
- Added media upload: PhotosPicker → save to `media/` subdirectory → preview grid with delete buttons (max 20)
- Added DatabaseManager methods: `reorderChildren()`, `uploadCoverImage()`, `uploadMediaToPage()`, `readGuideContent()`, `removeMediaFromPage()`
- Added `persistRootPageOrder()` to DatabaseStore — root page drag reorder now persists
- Made breadcrumbs tappable NavigationLinks → navigate back to ancestor pages
- Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions

## What to Build

### Task 1 — Grid/Browser View for Pages
- Create a toggleable gallery/browser view for DatabaseView's V2 mode
- Users can switch between list mode (current) and grid mode (card tiles)
- Grid mode: 2-column grid of PageCardView tiles (stretched to fill)
- List mode: current list with Section headers
- Add sort options: by name, by date created, by workout type
- Add filter chips: "All", each workout type, "Containers", "Leaves"

### Task 2 — Drag Exercise Page into Workout
- From ExercisePageDetailView, add "Add to Workout" button
- Shows a WorkoutPickerSheet listing all workouts
- Tapping a workout adds this page as a new section
- If page has workoutConfig (duration/sets/rest), pre-fill the section with those values
- Show a confirmation toast/banner after adding

### Task 3 — Section Configuration from Page
- When a page with workoutConfig is dragged into a workout, create a section with pre-filled values:
  - duration → section.duration
  - sets → section.sets
  - restAfter → section.restAfter
  - restBetweenSets → section.restBetweenSets
  - title → section.name (use page title)
- If page has no workoutConfig, prompt user to configure section inline before adding

### Task 4 — Quick-Action Context Menu on Page Cards
- Long-press or right-click on PageCardView shows context menu:
  - "Add to Workout" → opens WorkoutPickerSheet
  - "Edit" → opens PageCreationSheet
  - "Add Child Page" → opens PageCreationSheet with parent pre-set
  - "Duplicate" → creates copy of page with same content
  - "Delete" → moves to trash
- Context menu works in both list and grid views

### Task 5 — Search & Filter
- Add search bar to DatabaseView (V2 mode)
- Filters pages by title, markdownBody content, tags
- Real-time filtering as user types
- Use existing `DatabaseManager.searchPages()` method
- Show "No results" state with clear button

## Files to Create/Modify
- **modify:** `TimeMaster/Views/Database/DatabaseView.swift` — add grid/list toggle, search, filter chips
- **modify:** `TimeMaster/Views/Database/PageCardView.swift` — add context menu, expand for grid mode
- **modify:** `TimeMaster/Views/Database/ExercisePageDetailView.swift` — add "Add to Workout" button + WorkoutPickerSheet
- **create:** `TimeMaster/Views/Database/WorkoutPickerSheet.swift` — sheet to pick workout for adding page
- **modify:** `TimeMaster/Views/Database/PageCreationSheet.swift` — accept optional pre-set parentID

## Verification
- [ ] Grid/list toggle works in V2 DatabaseView
- [ ] Filter chips filter pages by type/container status
- [ ] Search bar filters in real-time
- [ ] "Add to Workout" from detail view opens workout picker
- [ ] Selecting a workout adds page as section with pre-filled config
- [ ] Context menu on page cards shows all 5 actions
- [ ] "Add to Workout" from context menu works
- [ ] "Duplicate" creates a copy of the page
- [ ] macOS arm64 build succeeds
- [ ] All 63 core tests pass (no regressions)

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create the next prompt file.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
