# F15 — V2 Workout Management Rework

The user reports that "workout management was never built — right now it is an old feature." The current `WorkoutListView` + `WorkoutDetailView` chain still leans on the legacy section model in places, behaves inconsistently between iOS and macOS, and the "Add to Workout from database" path is fragile. This feature rebuilds the workout-management flow on top of the V2 page-backed workout model so that every section is page-backed, the editor is single-pane (no double-sheet ping-pong), and the macOS sidebar + list + detail three-pane layout works smoothly.

## What We Build

- A clean V2 `WorkoutListView` with a responsive card grid, a real training summary (saved workout count, weekly sessions, training time, current streak, and goal progress), today-only filter, type filter, search, scheduled-time badges, resume state, and an empty state with a connected create action.
- `WorkoutCard` renders live section, duration, weekly-session, last-completed, schedule, and resumable-workout data instead of placeholder metadata.
- A V2 `WorkoutDetailView` header shows the selected workout type, section count, set count, total duration, and completed-session counter above the threaded editor.
- A Reddit-style tree rail connects each child row to its parent: one quiet vertical rail per nesting depth, with a short branch into the child card. Names sit in the visual center column. Time and cover thumbnails occupy the leading column, and only row actions occupy the trailing column. Rows with an actual cover photo use its averaged color only across the thumbnail-side 22% and a subtle matching outline. Symbol fallback rows stay neutral.
- Duration controls preserve the configured range and step. On iOS, the inline configuration form uses a compact decrement / `M:SS` / increment capsule instead of clipped wheels; the full row editor retains separate readable minute and second wheels. On macOS, the control is an editable `M:SS` clock field beside the system stepper. Typing an invalid value, or leaving the allowed range, restores the normalized displayed duration.
- Workout cards use the platform zoom navigation transition on iOS 18 and later; earlier systems retain the accessibility-aware opening fade. The global dark header fade is iOS-only. Header actions retain the shared system glass background on iOS/macOS 26 and later rather than adding opaque custom chrome.
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
        │       ├─ SlotEditor (inline expandable: each slot's Dur/Reps/Rest/Prep; add-set; add-item; set-rest-exercise)
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
| workout with sections | one scrolling list, expandable slot editors with independently removable preparation, work, drop, rest, and rest-content rows | structural changes autosave; a slot with no remaining sibling requests parent-section deletion |
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
