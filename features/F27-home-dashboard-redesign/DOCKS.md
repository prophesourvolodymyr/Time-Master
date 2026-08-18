# F27 — Home Dashboard Redesign

The Home dashboard becomes a user-owned, adaptive canvas of workout, schedule, progress, analytics, outdoor, and database modules. The canvas works on macOS and iOS, stays visually polished and dark, and lets each person decide what deserves space on the first screen.

## What We Build

- A responsive Home canvas that grows vertically as modules are added.
- A snapped visual grid with compact 0.5:2 half-width two-row, square 1:1, and wide 1:2 full-width module footprints.
- A removable Greeting text strip with no card background or shape selector.
- A schedule-first Today module built from scheduled workout instances.
- A Quick Start module that uses the first pending Today instance and falls back to the first matching ready workout.
- One configurable Activity Shortcuts module containing three circular Workout, Run & Walk, and Bike actions with subtle device-motion tilt on iOS.
- Extracted progress and analytics modules backed by existing stores rather than copied data.
- A Home edit mode entered by Pencil or a background long press.
- Edit mode controls for adding, removing, moving, changing module shape, and opening each module's direct options menu.
- A native module picker grouped into Today, Workouts, Analytics, Outdoor, and Database.
- Lightweight per-module content options exposed by a direct edit-mode menu and a secondary context menu only when useful.
- At rest, action modules and progress/analytics modules use quiet rounded bases so counters and charts do not float as disconnected text. Greeting remains the intentional background-free exception; in edit mode, each draggable non-Greeting module gains a smooth dark gradient base, subtle edge, shadow, and dashed editing boundary so the entire base reads as the drag target.
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
| edit mode | Done and Add controls are visible; each module exposes a red remove control, a direct options/shape menu when applicable, a smooth editable base, and a full-base drag affordance for reordering | A normal scroll gesture remains available; a long press followed by movement is required to start reordering, and no drag-handle icon is shown |
| module picker | A dark grouped sheet shows real widget previews in smooth rounded bases with a green circular plus button overlapping each preview's upper-right edge | Adding inserts immediately using the preview footprint, and the picker stays open for additional choices |
| module options | A direct options/shape menu is visible on the module while editing; a context menu remains available as a secondary path | Changes update the module instance and save immediately |
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
| move module | A long press followed by a direct drag from any point on the module base follows the pointer continuously; normal drags continue to scroll the canvas, the canvas temporarily stops scrolling only after a module drag begins, insertion slots appear, and neighboring modules make room | Long press then drag in edit mode |
| change shape | The module switches between its supported compact, square, and wide footprints and settles into the canvas | Shape selected from the direct module menu |
| shortcut tilt | Circular activity controls tilt a small amount toward the device's current gravity vector; unavailable sensors leave them level | Device motion on iOS |
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
