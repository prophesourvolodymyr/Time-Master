# F04 — History & Analytics

Completed workout log with timestamps, duration tracking, and analytics dashboard with visual charts.

## Sub-Features
- [ ] **F04-A** — Streaks & Partial Logging (rest days, workout goals, partial workout logging)
- [ ] **F04-B** — Flame Streak + Per-Type Analytics (burning streak animation, per-type breakdown)

## What We Build
- HistoryView: chronological list of completed workouts
- Each entry shows: workout name, completion date/time, total duration
- Swipe to delete history entries
- AnalyticsView: dashboard with charts showing workout trends
- VideoEditorViewModel: analytics data aggregation

## Architecture
```
Views/
├── History/
│   └── HistoryView.swift       — NavigationStack + List of history entries
└── Analytics/
    └── AnalyticsView.swift     — Charts, summaries, trends

ViewModels/
└── VideoEditorViewModel.swift  — Analytics data processing (shared with F05)
```

## States
| State | View | Behavior |
|-------|------|----------|
| empty | HistoryView | "No completed workouts" placeholder |
| populated | HistoryView | Scrollable list with name, date, duration |
| empty | AnalyticsView | "No data yet" state |
| has data | AnalyticsView | Charts render with workout frequency, duration trends |

## Files
- `TimeMaster/Views/History/HistoryView.swift`
- `TimeMaster/Views/Analytics/AnalyticsView.swift`
- `TimeMaster/ViewModels/VideoEditorViewModel.swift`

## Dependencies
- F01 — Core Data Layer (WorkoutStore for history data)
- F03 — Timer & Player (completion triggers history logging)

## Verification
- [x] Completed workout automatically appears in HistoryView
- [x] History entries show correct name, date, duration
- [x] Swipe-delete removes history entry
- [x] Analytics dashboard renders charts with workout data
- [x] Empty states display correctly when no history
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
