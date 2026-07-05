# F07-C — Workout Types & Schedules

Custom workout types created by user in settings. Each type gets its own weekly goal and schedule duration. Types appear as filter tags in database and analytics. Drill-down scheduling per type.

## What We Build

### Custom Workout Types
- Settings → "Workout Types" → list of built-in + custom types
- Built-in (immutable): Strength, Stretch, Cardio, HIIT, Yoga, Face, Other
- Custom (user-created): "+" button, enter name, pick icon (SF Symbol picker), pick color
- Custom types appear everywhere built-in types appear: database tags, analytics filter, workout builder, workout list
- Edit/delete custom types (delete removes tag from all pages/workouts)

### Per-Type Schedule
- Settings → "Workout Types" → tap type → "Schedule"
- Set weekly goal: number of days per week (1-7)
- Set schedule duration: how long this schedule runs (1 week, 2 weeks, 1 month, 2 months, indefinite)
- Pick days: e.g., "Monday, Wednesday, Friday" for 2 months
- Multiple types can have overlapping schedules (e.g., Strength MWF + Cardio TTh)
- Calendar view: weekly overview showing which days have which workout types
- Notifications pipeline uses this schedule for reminders (F07-B)

### Analytics Integration
- F04-B uses per-type schedule to calculate per-type streaks
- Type completion % shown in analytics
- Schedule adherence: "You hit 85% of your strength workouts this month"

## Architecture
```
Models/
├── WorkoutType.swift        — expand: add isCustom, icon, colorHex, schedule fields
└── Workout.swift            — link: WorkoutType reference

Views/Settings/
├── WorkoutTypesSettingsView.swift    (new)
├── WorkoutTypeEditorView.swift       (new)
├── TypeScheduleView.swift            (new)
└── SettingsView.swift                (modify — add "Workout Types" row)
```

## Files
- `TimeMaster/Models/Workout.swift` (modify WorkoutType)
- `TimeMaster/Views/Settings/SettingsView.swift` (modify)
- `TimeMaster/Views/Settings/WorkoutTypesSettingsView.swift` (new)
- `TimeMaster/Views/Settings/WorkoutTypeEditorView.swift` (new)
- `TimeMaster/Views/Settings/TypeScheduleView.swift` (new)

## Verification
- [ ] Create custom type with name, icon, color
- [ ] Custom type appears in database tags, analytics filter, workout builder
- [ ] Per-type weekly goal configurable (1-7 days)
- [ ] Schedule duration: 1 week to indefinite
- [ ] Day picker for specific days of the week
- [ ] Calendar overview shows all active schedules
- [ ] Delete type removes tag from all pages/workouts
- [ ] Schedule adherence shown in analytics
- [ ] compiles without errors
