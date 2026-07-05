# F03-A — Persistence & Live Activities

Background persistence, crash recovery, partial workout logging, and iOS Live Activities on lock screen.

## 1. Background Persistence & Resume
- Auto-save workout state every 5s (section index, time remaining, elapsed)
- Extended background execution via BGTaskScheduler + audio session (~3min)
- On relaunch after kill/crash: "Resume Workout?" prompt with elapsed time + section name
- Resume restores exact position; Discard clears state

## 2. Partial Workout Logging
- Workout interrupted after 3+ min → log as "Partial" to history (counts for analytics/streaks)
- Workout <3 min → not logged

## 3. Live Activities (iOS 16.1+)
- Lock screen: exercise name + countdown timer + next exercise + progress
- Dynamic Island: compact timer + exercise name
- Updates in near-real-time (minimum 1s interval)
- Dismisses when workout stops/completes
- Dark theme matching app palette

## Architecture
```
ViewModels/
└── WorkoutResumeManager.swift       (new)

LiveActivity/
├── TimeMasterLiveActivity.swift     (new)
└── TimeMasterLiveActivityUI.swift   (new)
```

## Files
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` (new)
- `TimeMaster/LiveActivity/TimeMasterLiveActivity.swift` (new — Widget extension)
- `TimeMaster/LiveActivity/TimeMasterLiveActivityUI.swift` (new)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (modify)
- `TimeMaster/App/TimeMasterApp.swift` (modify)

## Verification
- [ ] Progress auto-saves every 5s
- [ ] App killed → relaunch shows resume prompt, restores correctly
- [ ] 3+ min partial workout logged to history
- [ ] <3 min partial workout not logged
- [ ] Live Activity appears on lock screen with timer + exercise info
- [ ] Dynamic Island compact view on supported devices
- [ ] Activity updates in real-time, dismisses on workout end
