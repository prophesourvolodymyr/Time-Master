# F23 — Editor Database Picker Fix (old empty DB issue)

When the user tries to add a workout item from the Database to a Workout editor, two failures happen: (1) sometimes adding doesn't work at all; (2) the Workout editor opens an "old database" view that is empty (showing only the V1 folder/exercise picker roots, not the V2 page tree). The user is seeing old app data leaking through. This feature ensures the workout editor ALWAYS uses the V2 page browser, never the legacy folder picker, AND that DatabaseStore reloads before showing the browser so the latest tree (after any AI import, migration, or external change) is presented.

## What We Build

- Audit every entry that opens a "pick exercise to add to the workout" sheet — confirm they all open `DatabasePageBrowserSheet`, NOT the legacy `DatabaseSectionPickerView`.
- `DatabaseStore.shared` reloads (`store.reload()`) immediately before the `DatabasePageBrowserSheet` appears so the user always sees the current page tree.
- The legacy `DatabaseSectionPickerView` is removed (or archived to `features/_archive`) only if no production code references it. Otherwise, mark it `@available(*, deprecated)` and route all callers to V2.
- The "Add to Workout" button from `ExercisePageDetailView` and `PageCardView` context menus — verify they pass the current page forward (no stale page snapshot).
- The "Add to Workout" flow on the Workout editor `WorkoutDetailView.handlePageSelection` correctly stamps the new section's `pageID` with `page.id` and persists the workout manifest.

## Architecture

```
WorkoutDetailView "Add Section" button
  └─ store.reload()
  └─ present DatabasePageBrowserSheet(workout, onAdd:, onAddBundle:)
      └─ user selects page → onAdd(page, dur, sets, reps, restAfter, restBetween)
          └─ handlePageSelection → PendingSectionConfig(pageID: page.id, …)
              └─ confirmPendingSection → Section(... pageID: page.id ...)
                  └─ store.addSection + store.updateWorkout (writes manifest file)

ExercisePageDetailView toolbar "Add to Workout" button
  └─ WorkoutPickerSheet(page:) → user picks workout → onAdd section to selected workout
```

## States

| State | Behavior |
|---|---|
| Workout detail with no sections → "Add First Exercise" | does NOT open legacy picker; opens V2 browser |
| Database newly populated (via AI import or external copy) → open workout editor → add exercise | browser shows the latest tree, no empty V1 roots |
| "Add to Workout" from a database leaf page | writes a new section to the picked workout; selecting another workout in the picker sheet persists correctly |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| none — pure flow fix | — | — |

## Files

- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — confirm only `DatabasePageBrowserSheet` is used; remove any fallback to legacy picker
- `TimeMaster/Views/Database/DatabaseSectionPickerView.swift` — remove or deprecate; confirm zero production callers
- `TimeMaster/Views/Database/WorkoutPickerSheet.swift` — verify WritePickerSheet returns the selected workout's `id` and writes via `WorkoutStore.updateWorkout`
- `TimeMaster/ViewModels/DatabaseStore.swift` — reload before browser sheet opens
- `TimeMaster/ViewModels/WorkoutStore.swift` — ensure `addSection`/`updateWorkout` writes through `DatabaseManager`

## Dependencies

- F14 — only leaf pages can be added to a workout
- F15 — V2 workout management backbone
- F09-A — DatabaseManager already writes manifests

## Reference

- `genesis/ISSUES.md` — "when I try to add the workout item from the date of birth to the workout. First of all, it may not work and second when I try to add the workout from the editor, it actually shows that old database, which is empty. This means that we have problem with old apps"

## Verification

Implementation evidence: macOS and iOS Simulator Debug builds succeeded after routing the section editor through `DatabasePageBrowserSheet`; core tests passed. Interactive picker selection and persistence remain pending.

- [ ] From WorkoutDetailView, "Add First Exercise" → V2 DatabasePageBrowserSheet opens (no V1 folder root)
- [ ] From ExercisePageDetailView, "Add to Workout" button → a new page-backed section appears in the chosen workout, persisted to disk manifest
- [ ] Designer imported via AI into the DB → reload home + open workout editor → new page visible in browser
- [ ] DatabaseSectionPickerView is no longer referenced by production code (search confirms zero call sites)
- [ ] Re-open workout editor after closing — the section just added is still present with its page ID intact
- [ ] macOS + iOS builds succeed; core tests pass
