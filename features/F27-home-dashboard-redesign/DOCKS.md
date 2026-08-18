# F27 — Home Dashboard Redesign

The Home dashboard becomes a user-owned, adaptive canvas of workout, schedule, progress, analytics, outdoor, and database modules. The canvas works on macOS and iOS, stays visually polished and dark, and lets each person decide what deserves space on the first screen.

## What We Build

- A responsive Home canvas that grows vertically as modules are added.
- A snapped visual grid with compact, standard, tall, and large module footprints.
- A removable Greeting module; Greeting is not permanent page chrome.
- A schedule-first Today module built from scheduled workout instances.
- A Quick Start module that uses the first pending Today instance and falls back to the first matching ready workout.
- One configurable Activity Shortcuts module containing supported Workout, Run & Walk, and Bike actions.
- Extracted progress and analytics modules backed by existing stores rather than copied data.
- A Home edit mode entered by Pencil or a background long press.
- Edit mode controls for adding, removing, moving, and resizing modules.
- A native module picker grouped into Today, Workouts, Analytics, Outdoor, and Database.
- Lightweight per-module content options exposed through a context menu only when useful.
- Local per-device layout persistence with immediate saves after every layout change.
- Full macOS accessibility, keyboard support, Dynamic Type, Reduce Motion, and reduced-transparency behavior.

The Workouts destination is intentionally outside this feature. It will receive its own redesign after its blueprint is supplied.

## Architecture

The Home screen owns only the canvas, header, edit state, module instances, and presentation of module actions. Individual modules own their visual content and use existing stores for data and navigation.

```
Home dashboard
 ├─ canvas state and local layout persistence
 ├─ Greeting
 ├─ Today schedule and Quick Start
 ├─ Activity Shortcuts
 ├─ progress and analytics modules
 ├─ outdoor modules when supported
 └─ database modules
```

The module catalog declares each module's category, supported visual footprints, platform availability, default configuration, and whether it has editable options. The persisted layout stores module instances, order, footprint, and option values. The catalog itself does not store user layout state.

## States

| State | What the user sees | Behavior |
|---|---|---|
| first launch | Greeting, Today, Quick Start, Activity Shortcuts, and Metrics in the default order | Every module can later be removed or rearranged |
| populated | An adaptive dark grid with modules arranged in the saved order | The canvas scrolls vertically and uses the available width |
| empty Today | A calm empty Today module with a path to schedule or browse workouts | No invented workout instance is shown |
| no workouts | Empty modules explain how to create a workout or open the database | Quick Start and workout-dependent modules show useful empty actions |
| no history | Progress modules show zero-state copy without fabricated progress | Analytics modules remain addable |
| edit mode | Done and Add controls are visible; each module exposes a red remove control and drag/resize affordances | Taps on module content are replaced by editing interactions where necessary |
| module picker | A native popover or sheet with grouped visual previews | Adding a module inserts it immediately and saves the layout |
| module options | A context menu or compact options presentation for supported modules | Changes update the module instance and save immediately |
| unavailable platform action | The module is not offered on that platform | The canvas never presents a dead disabled outdoor action |
| reduced motion | Changes use short fades and restrained layout updates | No large slide, bounce, or continuous motion is required |
| reduced transparency | Surfaces become more opaque while retaining hierarchy | Text contrast remains stable |
| accessibility focus | Every module, control, footprint action, and status has a meaningful label | Keyboard and VoiceOver users can perform the same operations |

## Animation Rules

| Animation | Behavior | Trigger |
|---|---|---|
| enter edit mode | The canvas changes to an editing presentation with controls materializing near their targets | Pencil or background long press |
| add module | The new module appears at the insertion point with a restrained spring and opacity transition | Add from picker |
| remove module | The module leaves immediately and the remaining modules settle into their new grid positions | Red remove control |
| move module | The module follows the edit drag and neighboring modules make room continuously | Drag in edit mode |
| resize module | The preview and canvas snap to the next supported footprint without a hard jump | Resize drag |
| exit edit mode | Editing affordances fade while the resting canvas remains in place | Done |
| data refresh | Numeric and status changes use scoped content transitions | Store or schedule change |

## Files

- `TimeMaster/Models/HomeWidget.swift` — module identities, categories, footprints, options, and persisted instances.
- `TimeMaster/ViewModels/HomeWidgetStore.swift` — local layout persistence and layout mutations.
- `TimeMaster/Views/Home/HomeDashboardView.swift` — Home shell, header, edit state, and existing route/player/settings presentation.
- `TimeMaster/Views/Home/HomeWidgetCanvas.swift` — adaptive grid and edit interactions.
- `TimeMaster/Views/Home/HomeWidgetPicker.swift` — grouped visual module picker.
- `TimeMaster/Views/Home/HomeWidgetViews.swift` — extracted module renderers and shared module chrome.
- `TimeMaster/Models/Workout.swift` — schedule time data used by Today instances.
- `TimeMaster/ViewModels/WorkoutStore.swift` — scheduled workout instance query and status calculation.
- `TimeMaster/Views/Settings/WorkoutTypesSettingsView.swift` — schedule time and duration editing.
- `TimeMasterCore/Sources/Models/ConfigManifest.swift` — persisted schedule time fields.

## Dependencies

- F01 — workout and history data.
- F03 — player presentation for Quick Start and Today actions.
- F04 — progress, streak, and Analytics data.
- F07 — Settings, outdoor, and database destinations.
- F12 — existing Home dashboard behavior and routing.
- F22 — schedule time data is absorbed into the Today implementation needed by this redesign.

## Reference

- `features/F12-home-dashboard/DOCKS.md` — existing Home dashboard behavior.
- `features/F20-scheduled-today-widget/DOCKS.md` — scheduled Today and missed-state intent; the system WidgetKit part is not included here.
- `features/F22-type-time-of-day/DOCKS.md` — schedule time and duration behavior.
- `TimeMaster/Views/Analytics/AnalyticsView.swift` — existing Analytics modules, including ActivityHeatmap.
- The user's Home blueprint — authoritative visual and interaction direction for this redesign.
