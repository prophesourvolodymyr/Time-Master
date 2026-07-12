# Phase 6 of F01-B — F05-B — Drag-to-Build + Inline Section Config

## Context
We are building the V2 Notion-style Unified Page Model. Phase 5 completed database browser enhancements: grid/list toggle with 2-column layout, sort by name/date/type, filter chips (All/Containers/Leaves/per-type), real-time search bar, context menu on PageCardView (5 actions), WorkoutPickerSheet with pre-filled workoutConfig, "Add to Workout" button in page detail view, and DatabaseStore.duplicatePage(). All 63 core tests pass, macOS arm64 build succeeds.

## What You Need to Read First
- `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md` — full spec
- `features/DOCKS.md` — root index (check what F02-A-b requires)
- `TimeMaster/Views/Database/WorkoutPickerSheet.swift` — workout picker sheet (Phase 5)
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — detail view (Phase 3-5)
- `TimeMaster/Views/Database/PageCardView.swift` — card view (Phase 3-5, now with context menu)
- `TimeMaster/Views/Database/DatabaseView.swift` — root browser (Phase 3-5, grid/list/search/filter)
- `TimeMaster/ViewModels/WorkoutStore.swift` — workout CRUD (addSection, updateSection, deleteSection)
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — existing workout detail
- `TimeMaster/Models/Workout.swift` — Workout, Section models

## What Happened Last Session (Phase 5)
- Grid/list toggle button in toolbar for V2 DatabaseView
- Sort options: by name, date created, workout type (Menu in toolbar)
- Filter chips: All, Containers, Leaves, per-workout-type (horizontal scroll)
- Search bar: real-time filtering by title, markdownBody content, tags
- PageCardView grid variant: 2-column gallery with cover hero, icon, workout config badges
- Context menu: Add to Workout, Edit, Add Child Page, Duplicate, Delete
- WorkoutPickerSheet: lists all workouts, config summary with steppers (Dur/Sets/Rest/Btwn), pre-fills from page workoutConfig, confirmation toast on add
- "Add to Workout" toolbar button in ExercisePageDetailView → opens WorkoutPickerSheet
- DatabaseStore.duplicatePage() copies manifest, cover image, and media files
- WorkoutStore environment object wired to DatabaseView + MainTabView
- Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions

## What to Build

### Task 1 — Drag Page to Workout from Browser
- In WorkoutDetailView, add a "Browse Pages" button that opens a DatabasePageBrowserSheet
- The sheet shows the V2 database browser (list/grid of pages)
- Tapping a page shows a mini-preview with its workoutConfig
- "Add Section" button adds the page as a workout section (same logic as WorkoutPickerSheet)
- Long-press or drag from the browser side to add to the workout (on macOS: drag-to-sidebar)

### Task 2 — Inline Section Config When Adding
- When a page is added to a workout, show an inline SectionConfigCard at the top of the sections list
- The card shows all pre-filled values: duration, sets, rest after, rest between sets
- Each value has +/- steppers for quick adjustment before finalizing
- "Confirm" button finalizes the section, "Cancel" discards
- After confirming, the section appears in the list

### Task 3 — Set Reps Per Section
- Add a "rep count" field to Section (currently Section only has duration/sets)
- Each set can have a rep count (e.g., "12 reps per set")
- When a page has sets configured, auto-populate the rep count
- In the WorkoutPickerSheet steppers, add a "Reps" stepper alongside existing "Dur/Sets/Rest/Btwn"
- Display rep count in section detail and during workout playback

### Task 4 — Drag-to-Reorder Sections in Workout
- Enhance existing section reorder to support drag-and-drop gesture
- Sections can be dragged up/down in the list using a drag handle
- Visual feedback: dragged section lifts with shadow, target position highlights
- On drop, reorder persists via workoutStore.reorderSections
- Works on both iOS and macOS

### Task 5 — Quick-Add "Bundle" Section
- Add a "Bundle" button in the DatabasePageBrowserSheet
- When in bundle mode, tapping pages adds them to a bundle (multi-select)
- The bundle creates ONE workout section named after the first page
- All pages in the bundle share the same duration timer (bundle mode)
- Each page's workoutConfig contributes to the bundle's total sets
- "Create Bundle Section" button finalizes and adds to workout

## Files to Create/Modify
- **create:** `TimeMaster/Views/WorkoutDetail/DatabasePageBrowserSheet.swift` — embedded V2 browser in workout context
- **modify:** `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — add "Browse Pages" button, inline SectionConfigCard, drag-to-reorder
- **modify:** `TimeMaster/Views/Database/WorkoutPickerSheet.swift` — add "Reps" stepper
- **modify:** `TimeMaster/Models/Workout.swift` — add repCount field to Section
- **modify:** `TimeMasterCore/Sources/Models/WorkoutManifest.swift` — add repCount to WorkoutSectionManifest
- **modify:** `TimeMaster/Views/Player/WorkoutPlayerView.swift` — show rep count during playback
- **modify:** `TimeMaster/ViewModels/WorkoutStore.swift` — conversion handles repCount

## Verification
- [ ] "Browse Pages" button in WorkoutDetailView opens the browser sheet
- [ ] Tapping page in browser adds it as section with config
- [ ] Inline SectionConfigCard appears with editable values
- [ ] "Reps" field in WorkoutPickerSheet steppers
- [ ] repCount persists in Section model and Codable
- [ ] Drag-to-reorder sections works with visual feedback
- [ ] Bundle mode: multi-select pages → creates single bundled section
- [ ] macOS arm64 build succeeds
- [ ] All 63 core tests pass (no regressions)

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create the next prompt file.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
