# F15 — V2 Workout Management Rework

The user reports that "workout management was never built — right now it is an old feature." The current `WorkoutListView` + `WorkoutDetailView` chain still leans on the legacy section model in places, behaves inconsistently between iOS and macOS, and the "Add to Workout from database" path is fragile. This feature rebuilds the workout-management flow on top of the V2 page-backed workout model so that every section is page-backed, the editor is single-pane (no double-sheet ping-pong), and the macOS sidebar + list + detail three-pane layout works smoothly.

## What We Build

- A clean V2 `WorkoutListView` with card layout, today-only filter, scheduled-time badges, and empty state pointing to the database.
- A V2 `WorkoutDetailView` that always shows page-backed sections in a single scrollable list — section header (page cover thumbnail, title, rep count, duration), slot list inline, add-set / add-item / set-rest-exercise actions all reachable without leaving the screen.
- Inline slot editing (steppers for Dur/Sets/Reps/Rest/Btwn) without a separate sheet for the common case.
- Mac three-pane awareness: selection in the workouts list pushes into the detail pane; nothing in the editor requires a sheet pop-up that breaks the macOS sidebar flow.
- Workouts can be created from the empty state, from the database (Add to Workout on a leaf page), and from a quick action on the Home dashboard.
- Remove all "old database" picker paths from the editor — see F23.
- Validate that the workout manifest file is written through `WorkoutStore.updateWorkout` → `DatabaseManager` only; no UserDefaults-only writes.

## Architecture

```
WorkoutListView (V2)
  └─ WorkoutCard (cover from first section page, type icon, duration, scheduled-time badge)
     └─ WorkoutDetailView (V2)
        ├─ Header (name, type icon, color, total duration, "Start" button)
        ├─ Section list (single scroll)
        │   └─ SectionRow (page thumbnail + name + sets badge + duration)
        │       └─ SlotEditor (inline expandable: each slot's Dur/Reps/Rest; add-set; add-item; set-rest-exercise)
        │       └─ RestSeparator row (stepper for restAfter)
        └─ WorkoutSettings sheet (rest between sections, color, music)
```

```
Database leaf page → "Add to Workout" button
   └─ WorkoutPickerSheet (list of workouts, secondary section config)
       └─ returns to WorkoutDetailView with a new pending section
```

## States

| State | What it shows | Behavior |
|---|---|---|
| empty workouts | empty state with "Create from Database" + "Start from blank" | navigates user to database tab |
| workout with no sections | "Add first exercise" prompt → opens DatabasePageBrowserSheet | section added inline |
| workout with sections | one scrolling list, expandable slot editors | no double sheet |
| drag reorder | section list supports drag handles on macOS and onMove on iOS | order persists |
| macOS selection | sidebar pushes detail | no popover-modal ping-pong |
| Add to Workout from database | picker sheet appears, picks workout, returns to details with pending section | one navigation hop |
| delete workout | alert confirm | workout file removed from disk via DatabaseManager |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| slot editor expand/collapse | 0.25s spring | tap section header |
| new section card slide-in | 0.3s ease-out | confirm pending config |
| drag-to-reorder | system spring | drag handle |

## Files

- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` — V2 card list, today filter, badges
- `TimeMaster/Views/WorkoutList/WorkoutCard.swift` — page-backed cover thumbnail
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — single-pane editor
- `TimeMaster/Views/WorkoutDetail/SectionRow.swift` — page-backed row, inline expand
- `TimeMaster/Views/WorkoutDetail/DatabasePageBrowserSheet.swift` — already V2; remove legacy fallbacks
- `TimeMaster/Views/Database/WorkoutPickerSheet.swift` — already V2; ensure clean return signal
- `TimeMaster/ViewModels/WorkoutStore.swift` — ensure V2 manifest is the only writer, fallbacks removed

## Dependencies

- F01-B, F02-A — page-backed workout/section model exists
- F23 — editor DB picker fix (do not link to legacy entries)
- F14 — page-kind model so only leaf exercises can become sections

## Reference

- `genesis/ISSUES.md` — "Workout management was never built, right now it is an old feature"
- `genesis/REFERENCE/` — none

## Verification

- [ ] Create new workout from empty workouts tab → opens detail with prompt
- [ ] Add first section from database browser → section shows page-backed cover
- [ ] Edit a section's duration inline → persisted to file manifest
- [ ] Reorder sections via drag → order persists across launches
- [ ] Add-to-Workout from database page → new section lands at end and persists
- [ ] macOS sidebar → detail flow opens without modal sheet for normal edits
- [ ] Delete workout → manifest file removed from disk
- [ ] macOS + iOS builds succeed; all core tests pass
