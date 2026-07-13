# F20 — Scheduled-Today Home Widget & Missed-Red Indicator

Currently the Home dashboard "Quick Start" card shows the most-recently-matching workout regardless of schedule. The user wants:
- A "Today" list on the Home dashboard that shows ONLY workouts scheduled for today (per-type training schedule + day-of-week + per-type start time).
- The first workout in that today-only list becomes the prominent Quick Start card.
- If a today-scheduled workout's start time has passed and the user has not completed it, it moves DOWN in the list (below the next upcoming one) and marks itself RED as "missed".
- Overdue workouts keep stacking at the bottom in red until either completed or skipped (manual skip action).

## What We Build

- A `TodaySchedule` helper in `WorkoutStore` that, for a given date, returns an ordered list of `ScheduledWorkout`:
  - source: each workout's `workoutType.schedule` (from F22) — days of week + start time.
  - filter: only workouts whose type's schedule contains today's weekday + schedule window is active.
  - ordered by start time.
- Each `ScheduledWorkout` carries: `workout`, `scheduledStart: Date`, `scheduledFinish: Date` (start + workout.totalDuration), `status: pending | completed | missed`.
- `status` computed:
  - `completed` if the user has any history entry for that workout on the same day before the scheduled finish.
  - `missed` if `now > scheduledStart` AND not completed.
  - `pending` otherwise.
- The Home dashboard:
  - Replaces the single "Quick Start" card with a "Today" section:
    - One prominent Quick Start card (first non-missed pending scheduled workout).
    - If none pending or all missed → show the first one (still red prominent), or an empty-state chip.
    - Beneath: a compact list of today's remaining scheduled workouts (name + time + status chip).
  - Missed (red) entries sort to the bottom of the list, and their card has a red "Missed" chip + a "Skip" and "Start Now" action.
- The iOS widget (`TimeMasterWidget`) shows the same: today's first scheduled workout, with a red badge if missed, and a deep-link to the workout detail.
- The dashboard recomputes on `WorkoutStore` change and on a 60s timer.

## Architecture

```
WorkoutStore.scheduledWorkouts(for: Date) → [ScheduledWorkout]
  ├─ scheduledStart, scheduledFinish
  ├─ status: pending | completed | missed
  └─ sort: pending(by start) | missed (after pending, by start)

HomeDashboardView
  ├─ todaySchedule = store.scheduledWorkouts(for: today)
  ├─ quickStartCard = todaySchedule.first(where: status == .pending) ?? todaySchedule.first
  ├─ todayList      = todaySchedule.sorted(pending-first then missed-by-start)
  └─ render: prominent quickStartCard + todayList below

TimeMasterWidget
  └─ same status + deep-link to workout detail (or quick-start if appended)
```

## States

| State | Home shows |
|---|---|
| no workouts scheduled today | empty "Nothing scheduled today" chip + library actions |
| one scheduled, before start time | quickStart card with "Starts at 09:00" + Start Now button |
| multiple scheduled, all pending | first one prominent; rest in compact today list with start times |
| one pending, one missed | pending remains prominent; missed shows red status below |
| all scheduled missed | first missed turns prominent with red "Missed" chip + Skip/Start Now actions |
| one completed today | completed shows green check; pending/missed shrink appropriately |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| status chip change | 0.3s ease-out | when status flips pending → missed |
| list reorder when status changes | 0.3s spring | missed entry drops down |
| card-prominent swap | 0.25s ease-out | when first pending becomes completed |

## Files

- `TimeMaster/Models/Workout.swift` — `ScheduledWorkout` model
- `TimeMaster/ViewModels/WorkoutStore.swift` — `scheduledWorkouts(for:)` helper, status computation
- `TimeMaster/Views/Home/HomeDashboardView.swift` — today list + missed-red
- `TimeMasterWidget/TimeMasterWidget.swift` (or wherever widget timeline provider lives) — today + missed-red badge
- `TimeMaster/App/TimeMasterApp.swift` — 60s schedule-refresh timer

## Dependencies

- F22 — per-type time-of-day schedule (so `ScheduledWorkout.scheduledStart` exists)
- F12 — Home dashboard foundation (already done)
- F04 — History drives the `completed` status check

## Reference

- `genesis/ISSUES.md` — "user has to do this three workouts today in their specific time … show first one in the list on the homepage … only the workouts that is set for today will be sad … skip the time of the workout, then it will just go down and mark itself red"

## Verification

- [ ] Today-scheduled workouts appear in the today list with start times
- [ ] Non-scheduled-today workouts do NOT appear in the today list
- [ ] The first pending workout is the prominent quick-start card
- [ ] After scheduled start time passes without completion, the workout drops to the bottom of the list and shows a red Missed chip
- [ ] Tapping "Start Now" on a missed workout launches the player
- [ ] Tapping "Skip" removes the missed state from the view (does not modify the underlying workout or history)
- [ ] Completing a workout today marks its entry green in the list
- [ ] iOS widget mirrors the dashboard's first scheduled + missed-red state
- [ ] macOS + iOS builds succeed; core tests pass
