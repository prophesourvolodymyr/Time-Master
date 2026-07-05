# F04-B — Flame Streak + Per-Type Analytics

Animated flame streak counter with per-workout-type tracking. Burning effect on streak number, calendar with per-type coloring, and analytics breakdown by workout type.

## What We Build

### Flame Streak Animation
- Streak number displayed large with animated flame effect
- Animation: gradient colors (#FF6B35 → #FFD700 → #FF4500) cycling, slight scale pulse, particle embers rising from the number
- Streak = consecutive days with a completed workout (respecting rest days from F04-A)
- "🔥 X days" label with the number "burning"
- Longest streak shown as secondary stat below current streak

### Per-Type Analytics
- Analytics dashboard breaks down by workout type (strength, cardio, hiit, custom types from F07-C)
- Each type shows: workouts this week, total time, streak for that type
- Type tags on every workout → analytics aggregates by tag
- Color coding: each type gets a distinct color for charts
- Filter: tap type to filter analytics view to only that type

### Per-Type Weekly Goals
- Goal config per type (e.g., "3× strength, 2× cardio per week")
- Analytics shows completion % per type vs goal
- Streak per type: if you miss a scheduled strength day but do cardio, strength streak resets

## Architecture
```
Views/Analytics/
└── AnalyticsView.swift               — add flame animation, per-type breakdown

Utilities/
└── FlameStreakAnimator.swift         (new) — flame particle effect
```

## States
| Streak | Visual |
|--------|--------|
| 0 days | Gray flame outline, "Start your streak" |
| 1-2 days | Small flame, orange only |
| 3-6 days | Medium flame, orange + gold gradient |
| 7-14 days | Large flame, embers rising |
| 15+ days | Inferno: large flame, gold + red, heavy particle system |

## Files
- `TimeMaster/Views/Analytics/AnalyticsView.swift` (modify)
- `TimeMaster/Utilities/FlameStreakAnimator.swift` (new)
- `TimeMaster/ViewModels/WorkoutStore.swift` (per-type streak calc)
- `TimeMaster/Models/Workout.swift` (type tags link)

## Verification
- [ ] Streak counter animated with flame effect
- [ ] Flame intensity scales with streak length (7 tiers)
- [ ] Per-type breakdown shows correct counts and percentages
- [ ] Filter by type works, charts update
- [ ] Per-type weekly goal shows completion %
- [ ] Missed type-specific day resets that type's streak
- [ ] compiles without errors
