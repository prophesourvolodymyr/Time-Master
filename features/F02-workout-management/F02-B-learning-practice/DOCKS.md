# F02-B — Learning Tab & Practice Type

New "Learning" tab + "Practice" workout type + warmup/break/wind-down timer phases.

## 1. Learning Tab
- 6th tab in MainTabView: "Learning" (book icon)
- Organize techniques, drills, practice routines — no timer, just visual reference
- Folders/categories: e.g. "Wrestling Takedowns", "BJJ Submissions"
- Full-screen immersive view: large photo/video, technique name, notes, tags
- Swipe between items in a folder

## 2. Practice Workout Type
- New `WorkoutType` enum: `.timed` (existing) and `.practice` (new)
- Practice: no duration required, tags + notes fields instead of timer config
- Lives in Learning tab, not regular workout list

## 3. Warmup, Break & Wind-down
- **Warmup:** Optional timer before first section. Configurable in workout settings. "Skip Warmup" button during warmup phase.
- **Break:** Dedicated rest phase between sections with "Next: [Name]" preview. Distinct audio cues.
- **Wind-down:** Optional cooldown timer at workout end. Configurable per workout.
- Audio cues for each phase transition.

## Architecture
```
Views/Learning/
├── LearningListView.swift    (new)
├── LearningDetailView.swift  (new)
└── LearningFolderView.swift  (new)

Models/
└── Workout.swift — add WorkoutType enum, warmupDuration, windDownDuration
```

## Files
- `TimeMaster/Views/MainTabView.swift`
- `TimeMaster/Views/Learning/LearningListView.swift` (new)
- `TimeMaster/Views/Learning/LearningDetailView.swift` (new)
- `TimeMaster/Views/Learning/LearningFolderView.swift` (new)
- `TimeMaster/Models/Workout.swift`
- `TimeMaster/Views/Player/WorkoutPlayerView.swift`
- `TimeMaster/Utilities/AudioManager.swift`

## Verification
- [ ] Learning tab appears, creates practice items with tags/notes
- [ ] Folders group practice items, full-screen viewer works
- [ ] Warmup timer with skip button, wind-down at end
- [ ] Break phase shows next exercise preview, audio cues work
- [ ] Practice items don't appear in regular workout list
