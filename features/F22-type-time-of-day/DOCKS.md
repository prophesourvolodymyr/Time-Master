# F22 — Per-Type Time-of-Day Schedule

Inside Settings → Workout Types, today each built-in or custom workout type can be tagged to a recurring weekly schedule (days of week) and a weekly goal number. The user now wants:
- Per workout-type, choose the specific **time of day** the user is expected to START and FINISH the workout.
- This start/finish time is what the home dashboard (`F20`) uses to render scheduled workouts with actual clock times and detect "missed" status.

## What We Build

- Extend `TypeSchedule` (already exists from Cycle 5) with two new fields: `startTime: TimeOfDay?` (hour + minute) and `durationMinutes: Int?` (fallback: derived from any workout using this type; required for finish-time computation).
- `WorkoutTypesSettingsView` → per-type editor sheet: existing grid (icon picker, color, weekly goal) plus a new "Schedule" card:
  - Weekly day picker (Mon–Sun toggle, multi-select) — existing.
  - "Start time" picker (compact time picker).
  - "Duration" stepper (5…240 minutes, step 5) — defaults to a typical duration for this type (e.g. 25 min for HIIT).
- The finish time = start time + duration (display a "x:xx – y:yy" hint inline).
- `WorkoutStore.scheduledTypes(for: Date)` already informs heatmap coloring. It continues to work.
- A query method `WorkoutStore.scheduledWorkouts(for: Date)` (consumed by F20) uses the per-type schedule to derive today's scheduled workouts ordered by start time.

## Architecture

```
TypeSchedule
  ├─ type: WorkoutType
  ├─ daysOfWeek: Set<Int>           // 1...7
  ├─ startDate: Date
  ├─ durationMonths: Int
  ├─ weeklyGoal: Int
  ├─ startTime: TimeOfDay?          // NEW — hour + minute
  └─ durationMinutes: Int?          // NEW — finish = start + duration

WorkoutTypesSettingsView
  └─ TypeEditor.sheet
      ├─ name, icon, color
      ├─ weeklyGoal
      └─ Schedule
          ├─ daysOfWeek picker
          ├─ startTime time-picker
          ├─ duration stepper (5...240)
          └─ "Per-day windows: 09:00–10:00" hint (no subtitle text per minimalist style)
```

## States

| State | What it shows | Behavior |
|---|---|---|
| no schedule for this type | toggle off; no time pickers | type has no scheduled plays |
| schedule set, no start time | days-only (back-compat with Cycle 5 behavior) | follows existing heatmap; no home-dashboard time |
| schedule set with start + duration | days + start + finish | home dashboard shows "Starts 09:00 – 10:00" |
| only start time, no duration | days + start only, finish blank | dashboard shows "Starts 09:00" |
| multiple times across multiple types | aggregates today | dashboard lists each work in order |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| schedule toggle | 0.2s ease-out | tap |
| time picker reveal | 0.25s ease-out | toggle ON |

## Files

- `TimeMaster/Models/Workout.swift` — `TimeOfDay` struct, `TypeSchedule` extension
- `TimeMaster/Views/Settings/WorkoutTypesSettingsView.swift` — add start/duration pickers
- `TimeMaster/ViewModels/WorkoutStore.swift` — `scheduledWorkouts(for:)` (consumed by F20)
- `TimeMasterCore` — persist schedule on disk alongside existing schedule JSON

## Dependencies

- F20 — home dashboard today list + missed-red relies on these scheduled start times
- Cycle 5 TypeSchedule model — extends, does not replace

## Reference

- `genesis/ISSUES.md` — "In the settings for the workout type, I also can choose the specific time of the day from which time Im expected to start and finish workout. this will help us with that home page thing"

## Verification

- [ ] Settings → Workout Types, open a type editor → Schedule card has Start Time + Duration pickers
- [ ] Set start time 09:00 + duration 30 → "9:00 – 9:30" hint visible
- [ ] Today is a scheduled day → home dashboard shows that type's workouts with the correct start/finish time
- [ ] After start time passes without completion → dashboard marks the workout red missed (F20 behavior)
- [ ] Existing heatmap/schedule behavior continues to work for existing types without start times
- [ ] Settings save persists across launches
- [ ] macOS + iOS builds succeed; core tests pass
