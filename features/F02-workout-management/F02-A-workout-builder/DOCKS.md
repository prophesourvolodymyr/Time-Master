# F02-A — Workout Builder Rework

Complete rework of the workout creation and editing experience. Lego-style builder that pulls exercises from the unified database, supports work sections with sets/drops/rest exercises and bundle sections for technique browsing. Player page popup with floating controls.

## Sub-Features
- [ ] **F02-A-a** — Database Browser + Workout Page
- [ ] **F02-A-b** — Drag-to-Build + Sets
- [ ] **F02-A-c** — Bundle Section Mode
- [ ] **F02-A-d** — Player Page Popup

## Architecture
All sub-features share the unified `ExercisePage` model (F01-A) and the reworked `Workout` model with `WorkoutSection` blocks.

## Files (summary, detailed in sub-features)
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` (full rewrite)
- `TimeMaster/Models/Workout.swift` (add WorkoutSection, SetSlot, SectionMode)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (add bundle mode, page popup)
- New builder views under `TimeMaster/Views/WorkoutDetail/`

## Dependencies
- F01-A — Unified Page Model (must be verified first)
- F05-B — Notion-Style Pages (pages must exist in DB to build workouts from)

## Verification
- [x] All sub-feature implementation items pass
- [x] Workout creation flow is wired end-to-end: DB browse → preview/select pages → configure sets → save
- [x] Both section modes (timed + bundle) are wired into the player

Evidence: F02-A is implemented on the active `WorkoutDetailView` → `DatabasePageBrowserSheet` → `WorkoutStore` path and on the `WorkoutPlayerView` timed/bundle path. macOS arm64 and iOS Simulator Debug builds succeeded on 2026-07-13; the iPhone 16 Pro Simulator app installed and launched; `TimeMasterCore` passed 67 tests.
