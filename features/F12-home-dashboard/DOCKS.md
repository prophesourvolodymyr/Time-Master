# F12 — Home Dashboard & Quick Start

The everyday landing screen: a focused, dark training brief with fast access to the next workout, current progress, and a few useful daily signals. It replaces the app's initial workout-list view while retaining the full workout library as its own destination.

## What We Build

- Home tab for iOS and the first sidebar destination on macOS.
- Greeting/status hero, weekly completion, current streak, total active minutes, and a compact next-workout card.
- Quick Start selects the most recently completed-matching workout; otherwise it uses the first available workout. The user can choose a different workout from the library.
- Empty state provides clear actions to create a workout or open the exercise database.
- Recent workouts and a compact type-progress strip offer useful context without duplicating the Analytics screen.

## Architecture

```
MainTabView
 ├─ HomeDashboardView
 │   ├─ WorkoutStore → workouts, history, streak, weekly type progress
 │   └─ WorkoutPlayerView sheet → Quick Start
 ├─ Workouts
 ├─ Database
 ├─ Analytics
 └─ AI Coach
```

## States

| State | Content | Behavior |
|---|---|---|
| populated | suggested workout, metrics, recent activity | quick start opens player; secondary action opens library |
| no history | starter metrics and workout suggestion | labels explain that the first workout starts a streak |
| no workouts | onboarding card | Create opens the workout-creation flow; Database opens the database tab |
| no active schedule | weekly progress remains available | no false "due today" claim |
| dark mode | app monochrome palette with type-color accents | all text maintains contrast |
| macOS | same cards in a scrollable detail pane | buttons and sheets work with mouse/keyboard |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| dashboard card entrance | 0.35s ease-out with small stagger | first appearance |
| progress change | 0.3s ease-out | history/workout data changes |
| quick-start sheet | platform default | button tap |

## Files

- `TimeMaster/Views/Home/HomeDashboardView.swift` — new dashboard
- `TimeMaster/Views/MainTabView.swift` — home tab/sidebar and cross-tab routing
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` — accepts command routing for home actions when needed

## Dependencies

- F01 — workout data and persistence.
- F03 — player presentation.
- F04 — metrics and streaks.

## Reference

- `genesis/REFERENCE/` — no direct reference required.

## Verification

- [ ] Home is the initial destination on iOS and macOS.
- [ ] Quick Start opens a valid workout player.
- [ ] Empty state exposes create and database actions.
- [ ] Metrics update from persisted history.
- [ ] macOS build launches the dashboard.
