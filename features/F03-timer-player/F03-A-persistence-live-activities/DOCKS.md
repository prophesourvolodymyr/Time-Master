# F03-A — Persistence & Resume

Background persistence, crash recovery, and partial workout logging.

## 1. Background Persistence & Resume
- Auto-save workout state every 5s (section index, time remaining, elapsed)
- Extended background execution via BGTaskScheduler + audio session (~3min)
- On relaunch after kill/crash: "Resume Workout?" prompt with elapsed time + section name
- Resume restores exact position; Discard clears state

## 2. Partial Workout Logging
- Workout interrupted after 3+ min → log as "Partial" to history (counts for analytics/streaks)
- Workout <3 min → not logged

## Architecture
```
ViewModels/
└── WorkoutResumeManager.swift       (new)
```

## Files
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` (new)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (modify)
- `TimeMaster/App/TimeMasterApp.swift` (modify)

## Verification
- [ ] Progress auto-saves every 5s
- [ ] App killed → relaunch shows resume prompt, restores correctly
- [ ] 3+ min partial workout logged to history
- [ ] <3 min partial workout not logged
