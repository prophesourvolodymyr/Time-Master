# F27-C — Home Widget Catalog

The widget catalog turns existing Home, Analytics, Outdoor, Database, and workout data into selectable modules. Every module is honest about the data and actions it can provide on the current platform.

## What We Build

### Today

- Greeting: compact greeting text only; removable and option-free.
- Today schedule: scheduled instances, status, checkbox, and Start action.
- Quick Start: first pending Today instance with a safe fallback.

### Workouts

- Activity Shortcuts: one configurable module containing supported Workout, Run & Walk, and Bike actions.
- Recent Workouts: recent history entries with a configurable visible count.
- Resume Workout: current resumable player state when available.
- Selected Workout: a manually chosen workout shortcut where a stable selection is useful.

### Analytics

- Metrics: sessions this week, current streak, and active minutes.
- Streak: current and best streak.
- Weekly Rhythm: per-type completion against goals.
- Activity Heatmap: the existing Analytics heatmap with Analytics navigation.
- Lifetime Stats: total sessions and minutes.
- Type Breakdown: type-specific sessions, time, streak, adherence, and goal progress.
- Outdoor Summary: finished run/bike counts and distance.

### Outdoor

- Recover Activity: resumable unfinished outdoor activity.
- Saved Routes: route list and supported start actions.
- Outdoor Summary may also be available here when the user wants an outdoor-focused view.

### Database

- Exercise Database: database entry point and useful current counts.
- Database Overview: current page, folder, or exercise totals.
- Build from Database: a direct path to creating a workout from the existing database flow.

Competition/Elo is not included until a real feature, data model, and interaction contract exist. AI Coach and Music remain separate destinations until a stable Home summary has a clear user benefit.

## Options

Options are deliberately small and content-focused:

- visible fields
- visible row count
- selected workout type
- selected workout
- selected activity actions
- time range where an existing data source supports it
- destination behavior where more than one valid destination exists

A module without meaningful options has no edit command. Duplicate instances are allowed only for modules where different configurations are useful.

## States

| State | Behavior |
|---|---|
| data available | Render real persisted values and actions |
| no data | Explain how to create or reach the source; never invent sample content |
| loading | Use a restrained placeholder only while the existing store is loading |
| unsupported platform | Do not offer the module or action in the picker |
| configured | Show only the selected fields and data scope |
| invalid saved option | Normalize to the module's default safe option |
| deleted source | Keep the module with a clear recovery action or remove it only when its identity no longer exists |

## Animation Rules

- Content changes use scoped numeric or opacity transitions.
- Heatmap and list modules do not animate every cell independently during routine refresh.
- Picker previews render the real module content using each module's content-aware default shape, followed by an explicit Add action. Shape can be changed after adding.
- Preview content is non-interactive; the Add action is the only control in the preview row.
- Reduce Motion keeps content transitions but removes large movement.

## Files

- `TimeMaster/Models/HomeWidget.swift` — catalog identities, categories, footprints, and option values.
- `TimeMaster/Views/Home/HomeWidgetViews.swift` — module renderers.
- `TimeMaster/Views/Home/HomeWidgetPicker.swift` — grouped previews and add actions.
- `TimeMaster/Views/Analytics/AnalyticsView.swift` — source behavior for Analytics modules.
- `TimeMaster/ViewModels/WorkoutStore.swift` — workouts, history, goals, streaks, and schedule data.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` — outdoor activity and route data.
- `TimeMaster/ViewModels/DatabaseStore.swift` — database data.
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` — resumable workout state.

## Dependencies

- F27-A — canvas renders catalog modules and their footprints.
- Existing WorkoutStore, Analytics, OutdoorActivityStore, DatabaseStore, and WorkoutResumeManager data.

## Reference

- `features/F12-home-dashboard/DOCKS.md` — existing Home modules.
- `features/F04-history-analytics/DOCKS.md` or current `AnalyticsView.swift` — existing analytics behavior.
- User Home blueprint — visual module categories, add flow, and removable modules.
