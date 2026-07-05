# Phase 1 of F04-A — Streaks & Partial Logging

## Context
Time-Master V1 iOS app. F04-A enhances analytics with a streak calendar, planned rest day support, configurable workout goals, and partial workout tracking from interrupted sessions.

## What You Need to Read First
- `features/F04-history-analytics/F04-A-streaks-partial-logging/DOCKS.md`
- `TimeMaster/Views/Analytics/AnalyticsView.swift` (current analytics dashboard)
- `TimeMaster/Views/History/HistoryView.swift` (history list with partial entries)
- `TimeMaster/Models/WorkoutHistory.swift` (WorkoutHistoryEntry)
- `TimeMaster/ViewModels/WorkoutStore.swift` (workout goal storage, history)
- `TimeMaster/Utilities/Theme.swift`

## What Happened Last Session
F03-B completed: rest preview, full media overlay, rest adjustment built.

## What to Build

### 1. Streak Calendar with Rest Days
- New section in AnalyticsView: "Streak Calendar" with month view
- Calendar grid: 7 columns (days), rows = weeks
- Each day: colored dot/circle:
  - Green: workout completed
  - Gray: planned rest day (user marked)
  - Red/outlined: missed day (streak broken)
  - Empty: future day or no plan
- Current streak: large number + "🔥 days" label
- Longest streak: secondary stat below
- "Mark Rest Day" button: marks today as planned rest, doesn't break streak
- "Mark Missed Day": if user wants to acknowledge a miss

### 2. Workout Goal Configuration
- New settings option: "Weekly Workout Goal" (3, 4, 5, 6, or 7 days/week)
- Saved to UserDefaults
- Streak logic: if user's goal is 4 days/week, only Mon/Thu/Wed/Fri are "workout days"
- Other days: automatically considered rest days
- Streak breaks only if user misses a scheduled workout day
- Goal can be changed anytime, existing streak recalculates

### 3. Partial Workout Logging
- WorkoutHistoryEntry already has `isPartial: Bool`, `elapsedSeconds: Int` (added in F03-A)
- HistoryView: partial entries show "[Partial]" badge (orange/amber) + elapsed time instead of full duration
- Analytics: partial workouts count toward streak and workout count
- Partial workout duration: use elapsed time in charts (not full planned duration)

## Files to Create/Modify
- `TimeMaster/Views/Analytics/AnalyticsView.swift` — streak calendar, goal config
- `TimeMaster/Views/History/HistoryView.swift` — partial badge rendering
- `TimeMaster/ViewModels/WorkoutStore.swift` — goal storage, streak calculation

## Verification
- [ ] Streak calendar shows green/gray/red days correctly
- [ ] Current streak counter updates with each workout
- [ ] Marking a day as rest doesn't break streak
- [ ] Missing a scheduled workout day resets streak to 0
- [ ] Weekly goal configurable, streak logic adapts
- [ ] Partial workouts appear in history with badge
- [ ] Partial workouts count toward streak and analytics
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F04-A): streak calendar, rest days, workout goals, partial logging"
3. **GENERATE THE NEXT PROMPT:** Create `prompts/F05-A-phase-1-database.md`
