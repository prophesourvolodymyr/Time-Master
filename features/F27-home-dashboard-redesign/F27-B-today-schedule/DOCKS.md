# F27-B — Today Schedule

Today is a Home module made from scheduled workout instances. It is the first source for Quick Start and gives the user a compact view of what is due, what is complete, and what needs attention.

## What We Build

- A per-type start time and expected duration in the existing schedule editor.
- A Today query that expands active scheduled types into today's workout instances.
- Automatic selection of the first ready workout matching each scheduled type.
- Scheduled start and finish display when the schedule provides enough information.
- Pending, completed, and missed status calculation.
- Ordering with upcoming or pending items first and missed items below them.
- A prominent Quick Start target derived from the first pending Today instance.
- Compact rows with checkbox, status, and Start action.
- Start Now behavior for missed entries.
- A non-destructive Skip action for missed entries.
- A no-schedule state that points to the workout and schedule paths without inventing work.

## Architecture

The schedule remains owned by `WorkoutStore` and persisted through the active file-backed configuration path. A scheduled instance combines an active type schedule with the first matching ready workout and the date's start/finish window. History determines completion for that date. The Home module consumes the query; it does not duplicate schedule rules.

The first matching workout is deterministic by the store's current workout order. Users do not need an additional mapping flow for the first release.

## States

| State | What the user sees | Behavior |
|---|---|---|
| no schedule today | Nothing scheduled today | Browse and scheduling actions remain available |
| pending | Workout name, scheduled window, pending status, and Start | Start opens the existing player |
| completed | Checked row and completed status | The row remains visible as today's record |
| missed | Red status and Start Now action | Skip removes the instance from the Home presentation without deleting data |
| no matching workout | Schedule information with a clear missing-workout explanation | No fake workout card is created |
| multiple instances | Ordered rows for each scheduled type | The first pending instance drives Quick Start |
| schedule without time | Day-based scheduled item without a fabricated clock time | Existing schedule behavior remains valid until a time is configured |
| history unavailable | Pending state can still render from schedule | Completion is updated when history is available |

## Animation Rules

- Status changes use a short scoped transition.
- A missed item moves below pending items with a restrained spring.
- Completing the prominent item transfers Quick Start to the next pending instance without a full-page reload.
- Numeric and checkbox changes use content transitions rather than large card motion.

## Files

- `TimeMaster/Models/Workout.swift` — time-of-day and duration schedule values.
- `TimeMaster/ViewModels/WorkoutStore.swift` — scheduled instance query and status calculation.
- `TimeMaster/Views/Settings/WorkoutTypesSettingsView.swift` — schedule time and duration controls.
- `TimeMasterCore/Sources/Models/ConfigManifest.swift` — file-backed schedule persistence.
- `TimeMaster/Views/Home/HomeWidgetViews.swift` — Today and Quick Start renderers.

## Dependencies

- F01 — workout and history persistence.
- F03 — player route for Start and Start Now.
- F04 — history and completion data.
- F22 — existing schedule model and intent, with time-of-day behavior absorbed here for the Home flow.

## Reference

- `features/F20-scheduled-today-widget/DOCKS.md` — scheduled Today and missed-state intent.
- `features/F22-type-time-of-day/DOCKS.md` — schedule time and duration behavior.
