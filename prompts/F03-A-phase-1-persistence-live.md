# Phase 1 of F03-A — Background Persistence & Live Activities

## Context
Time-Master V1 iOS app. F03-A prevents workout data loss on app close/phone death via auto-save and resume, extends background execution, saves partial workouts to history, and adds iOS Live Activities on lock screen.

## What You Need to Read First
- `features/F03-timer-player/F03-A-persistence-live-activities/DOCKS.md`
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (full player, timer, state)
- `TimeMaster/App/TimeMasterApp.swift` (app entry point, environment setup)
- `TimeMaster/Models/Workout.swift` (Workout, Section — all properties)
- `TimeMaster/Models/WorkoutHistory.swift` (history entry struct)
- `TimeMaster/ViewModels/WorkoutStore.swift` (addHistoryEntry, @Published)
- `TimeMaster/Utilities/NotificationManager.swift` (existing notification setup)
- `TimeMasterWidget/TimeMasterWidget.swift` (existing widget structure for reference)
- `TimeMaster/TimeMaster.entitlements` (app groups, capabilities)

## What Happened Last Session
F02-B completed: learning tab, practice type, warmup/break/wind-down built.

## What to Build

### 1. Background Persistence & Resume
- Create `WorkoutResumeManager.swift` — ObservableObject that persists/restores in-progress workout state
- State to save: workout ID, currentSectionIndex, currentSetIndex, timeRemaining, elapsedTotal, phase (warmup/active/setRest/sectionRest/winddown), paused state
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

### 3. Live Activities (iOS 16.1+)
- Create Widget extension target files (or extend existing widget):
  - `TimeMasterLiveActivity.swift` — ActivityAttributes with `WorkoutActivityAttributes`
  - `TimeMasterLiveActivityUI.swift` — lock screen + Dynamic Island views
- ActivityAttributes: workout name, exercise name, time remaining, next exercise, sections completed/total, color hex
- Start activity when workout player starts
- Update activity every 1-2s with current timer state (use minimum interval to avoid rate limiting)
- End activity when workout completes or user stops
- Lock screen: exercise name + large timer + next exercise + progress bar
- Dynamic Island compact: timer only; expanded: exercise name + timer + next
- Dark theme matching app palette (#0F0F1A bg, #FF6B35 accent, white text)

## Files to Create/Modify
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` (new)
- `TimeMaster/LiveActivity/TimeMasterLiveActivity.swift` (new — may live in widget target)
- `TimeMaster/LiveActivity/TimeMasterLiveActivityUI.swift` (new)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — auto-save on tick, read resume state
- `TimeMaster/App/TimeMasterApp.swift` — check resume on launch, present prompt
- `TimeMaster/Models/WorkoutHistory.swift` — add isPartial, elapsedSeconds
- `TimeMasterWidget/` — may need to add Live Activity target or extend existing

## Verification
- [ ] Progress auto-saves every 5s
- [ ] App killed → relaunch shows resume prompt with correct section + time
- [ ] Resume restores exact position, Discard clears
- [ ] 3+ min partial workout logged to history with [Partial] badge
- [ ] <3 min partial not logged
- [ ] Live Activity appears on lock screen with timer + exercise info
- [ ] Dynamic Island shows compact on supported devices
- [ ] Activity updates in real-time, dismisses on workout end
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F03-A): background persistence, resume, partial logging, live activities"
3. **GENERATE THE NEXT PROMPT:** Create `prompts/F03-B-phase-1-in-workout-controls.md`
