# Phase 1 of F02-B — Learning Tab & Practice Type

## Context
Time-Master V1 iOS app. F02-B adds a 6th "Learning" tab for organizing techniques/drills without timers, a new "Practice" workout type, and warmup/break/wind-down timer phases in the player.

## What You Need to Read First
- `features/F02-workout-management/F02-B-learning-practice/DOCKS.md`
- `TimeMaster/Views/MainTabView.swift` (current 4-tab layout)
- `TimeMaster/Models/Workout.swift` (Workout, Section, WorkoutType — add .practice case)
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` (how workouts are created/listed)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (player phases — warmup, rest, winddown)
- `TimeMaster/Utilities/AudioManager.swift` (audio cues)
- `TimeMaster/Utilities/Theme.swift`

## What Happened Last Session
F02-A completed: pin workouts + per-workout settings built. CRUD reactivity fixed earlier.

## What to Build

### 1. Learning Tab (New Tab)
- Add 5th tab (index 4) to MainTabView: "Learning" with `book.fill` icon
- LearningListView: grid or list of practice folders/items
- LearningFolderView: when user taps a folder, show items inside with full-screen viewer
- LearningDetailView: full-screen immersive view — large photo/video, technique name, notes, tags
- Swipe left/right between items in a folder
- Create new practice item flow: name, photo/video picker, tags (comma-separated), notes

### 2. Practice Workout Type
- Add `case practice = "Practice"` to `WorkoutType` enum with `book.fill` icon
- Practice type: no timer sections — just name, media, tags, notes
- Practice items stored in WorkoutStore but filtered out of regular workout list
- Practice items DON'T appear in Workouts tab, only in Learning tab

### 3. Warmup, Break & Wind-down
- **Warmup:** Before first section, optional warmup timer. Per-workout duration (from F02-A settings). "Skip Warmup" button visible during warmup.
- **Break:** Between sections, dedicated rest phase showing "Next: [Exercise Name]" preview (full preview in F03-B)
- **Wind-down:** After last section, optional cooldown timer. Per-workout duration.
- AudioManager: add distinct sounds for warmup start, break start, workout complete

## Files to Create/Modify
- `TimeMaster/Views/MainTabView.swift` — add Learning tab
- `TimeMaster/Views/Learning/LearningListView.swift` (new)
- `TimeMaster/Views/Learning/LearningDetailView.swift` (new)
- `TimeMaster/Views/Learning/LearningFolderView.swift` (new)
- `TimeMaster/Models/Workout.swift` — add `.practice` case, `tags: [String]`, `notes: String`
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` — filter out practice items
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — add warmup/winddown phases, skip button
- `TimeMaster/Utilities/AudioManager.swift` — add warmup/break/complete sounds

## Verification
- [ ] Learning tab appears in MainTabView
- [ ] Create practice item: name, photo/video, tags, notes
- [ ] Practice items grouped into folders
- [ ] Full-screen viewer with swipe between items
- [ ] Practice items don't appear in Workouts tab
- [ ] Warmup timer with skip button
- [ ] Wind-down timer at workout end
- [ ] Audio cues for each phase transition
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F02-B): learning tab + practice type + warmup/break/wind-down"
3. **GENERATE THE NEXT PROMPT:** Create `prompts/F03-A-phase-1-persistence-live.md`
