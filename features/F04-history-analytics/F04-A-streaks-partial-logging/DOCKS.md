# F04-A — Streaks & Partial Logging

Analytics streak with planned rest day support, and partial workout logging from interruptions.

## 1. Streak with Rest Days
- Streak counter in AnalyticsView follows the user's workout goal indicator
- User sets goal: e.g. "4 workouts per week" — Analytics calculates expected on/off days
- Planned rest days: user can mark days as "Rest Day" → streak doesn't reset
- Visual: calendar-style streak grid with green (worked out), gray (rest day), red (missed/missed streak)
- Streak resets only if user misses a scheduled workout day (outside planned rest days)

## 2. Partial Workout Logging (from F03-A)
- Workout interrupted after 3+ min elapsed → logged as "Partial" in history
- Partial workouts count toward streak and analytics
- Partial workouts show in history with "[Partial]" badge and elapsed time (not full duration)
- <3 min → not logged, not counted

## Architecture
- `WorkoutHistory.swift` — add `isPartial: Bool`, `elapsedSeconds: Int`
- `AnalyticsView.swift` — streak calendar, rest day marking
- `WorkoutStore.swift` — workout goal storage (days per week)
- `WorkoutResumeManager.swift` — triggers partial logging on discard (F03-A)

## Files
- `TimeMaster/Views/Analytics/AnalyticsView.swift`
- `TimeMaster/Models/WorkoutHistory.swift`
- `TimeMaster/ViewModels/WorkoutStore.swift`

## Verification
- [ ] Streak calendar shows green/gray/red days correctly
- [ ] Marking a day as "Rest Day" doesn't break streak
- [ ] Skipping scheduled workout day resets streak
- [ ] Workout goal configurable (e.g. 3, 4, 5, 6 days/week)
- [ ] Partial workouts appear in history with badge + elapsed time
- [ ] Partial workouts count toward streak and analytics
