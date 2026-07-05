# Phase 1 of F03-A — Background Persistence & Resume

## Context
Time-Master V1 iOS app. F03-A prevents workout data loss on app close/phone death via auto-save and resume, extends background execution, and saves partial workouts to history.

## What You Need to Read First
- `features/F03-timer-player/F03-A-persistence-live-activities/DOCKS.md`
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (full player, timer, state)
- `TimeMaster/App/TimeMasterApp.swift` (app entry point, environment setup)
- `TimeMaster/Models/Workout.swift` (Workout, Section — all properties)
- `TimeMaster/Models/WorkoutHistory.swift` (history entry struct)
- `TimeMaster/ViewModels/WorkoutStore.swift` (addHistoryEntry, @Published)
- `TimeMaster/Utilities/NotificationManager.swift` (existing notification setup)

## What Happened Last Session
F02-A and F02-B removed from scope. Three quick fixes applied to V1: tab bar opacity, AI text selection, CRUD reactivity. Build verified.

## What to Build

### 1. Background Persistence & Resume
- Create `WorkoutResumeManager.swift` — ObservableObject that persists/restores in-progress workout state
- State to save: workout ID, currentSectionIndex, currentSetIndex, timeRemaining, elapsedTotal, phase (active/setRest/sectionRest), paused state
- Auto-save every 5s during active workout (any phase)
- On app launch, WorkoutResumeManager checks for saved state, exposes `hasResumableWorkout: Bool`
- TimeMasterApp: on launch, if `hasResumableWorkout`, present resume prompt sheet
- Resume prompt: "Resume [Workout Name]?" with elapsed time + section name
- Resume restores exact position; Discard clears state
- Extended background: when workout active, use `beginBackgroundTask` to request up to 3 min. Also enable audio background mode for timer ticks.

### 2. Partial Workout Logging
- When user discards a >3min workout, or state is corrupted: log to history as partial
- Add `isPartial: Bool`, `elapsedSeconds: Int` to WorkoutHistoryEntry
- Partial entries show in history with "[Partial]" badge
- Partial entries count toward analytics and streaks
- <3 min discarded → not logged

## Files to Create/Modify
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` (new)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — auto-save on tick, read resume state
- `TimeMaster/App/TimeMasterApp.swift` — check resume on launch, present prompt
- `TimeMaster/Models/WorkoutHistory.swift` — add isPartial, elapsedSeconds

## Verification
- [ ] Progress auto-saves every 5s
- [ ] App killed → relaunch shows resume prompt with correct section + time
- [ ] Resume restores exact position, Discard clears
- [ ] 3+ min partial workout logged to history with [Partial] badge
- [ ] <3 min partial not logged
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F03-A): background persistence, resume, partial logging"
3. **GENERATE THE NEXT PROMPT:** Create `prompts/F03-B-phase-1-in-workout-controls.md`
