# Phase 1 of F02-A — Pin Workouts & Per-Workout Settings

## Context
Time-Master V1 iOS app. F02-A sub-feature adds pinning workouts to top of list and per-workout settings sheet (music, cover image, motivational quotes, accent color).

## What You Need to Read First
- `features/F02-workout-management/F02-A-ui-data-bugs/DOCKS.md`
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` (current list, context menu, pinToWidget)
- `TimeMaster/Views/WorkoutList/WorkoutCard.swift` (card rendering)
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` (detail view, settings sheet)
- `TimeMaster/Views/WorkoutDetail/WorkoutSettingsView.swift` (existing settings view)
- `TimeMaster/Models/Workout.swift` (Workout struct, WorkoutType)
- `TimeMaster/ViewModels/WorkoutStore.swift` (CRUD, @Published)
- `TimeMaster/Utilities/MusicManager.swift` (music library)
- `TimeMaster/Utilities/MotivationManager.swift` (quotes system)
- `TimeMaster/Utilities/Theme.swift` (colors, design tokens)

## What Happened Last Session
Three quick fixes applied to V1: CRUD reactivity (.onReceive sync), tab bar opacity, AI text selection. Build verified. Sets/rest steppers inspected — code is correct, the CRUD fix should resolve propagation issues.

## What to Build

### 1. Pin Workouts to Top
- Long-press on WorkoutCard or add to existing context menu: "Pin to Top" action
- Pinned workouts sort to top of WorkoutListView, with pin icon (SF Symbol `pin.fill`)
- Second long-press on pinned workout: "Unpin"
- Pin state persists in Workout model: add `isPinned: Bool` + `pinnedAt: Date?`
- WorkoutStore: add `pinnedWorkouts` computed property, sort logic

### 2. Per-Workout Settings
- Gear icon in WorkoutDetailView toolbar already exists → opens WorkoutSettingsView
- Settings sheet content:
  - **Music:** pick from MusicManager library, "None" = use global/default
  - **Cover Image:** photo picker for custom card image (falls back to first section photo)
  - **Motivational Quotes:** text editor to add/edit custom quote list (empty = use global)
  - **Accent Color:** color picker for workout card tint
  - **Warmup Duration:** stepper (0-300s, step 5s)
  - **Wind-down Duration:** stepper (0-120s, step 5s)
- Save to Workout model: add `WorkoutSettings` struct or inline properties
- WorkoutCard renders cover image if set

## Files to Create/Modify
- `TimeMaster/Models/Workout.swift` — add `isPinned`, `pinnedAt`, `coverImageFilename`, `customMusicTrack`, `customQuotes`, `accentColorHex`, `warmupDuration`, `windDownDuration`
- `TimeMaster/ViewModels/WorkoutStore.swift` — add `pinWorkout()`, `unpinWorkout()`, `pinnedWorkouts` computed property
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` — pin context menu, sort pinned to top
- `TimeMaster/Views/WorkoutList/WorkoutCard.swift` — pin indicator, cover image
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — gear icon already wired
- `TimeMaster/Views/WorkoutDetail/WorkoutSettingsView.swift` — full settings form (modify existing, may need significant rewrite)

## Verification
- [ ] Long-press workout → "Pin to Top" option, workout moves to top with pin icon
- [ ] Pin another → both at top, sorted by pin date
- [ ] "Unpin" returns workout to normal position
- [ ] Pin state survives app relaunch
- [ ] Workout settings sheet opens from gear icon
- [ ] Music picker shows MusicManager library, selection saves and plays during workout
- [ ] Cover image appears on WorkoutCard, falls back to first section photo
- [ ] Custom quotes save, fall back to global MotivationManager
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** Commit with message "feat(F02-A): pin workouts + per-workout settings"
3. **GENERATE THE NEXT PROMPT:** After finishing, create `prompts/F02-B-phase-1-learning-practice.md`.
