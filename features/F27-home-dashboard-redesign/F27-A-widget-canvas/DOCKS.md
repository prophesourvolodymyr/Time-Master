# F27-A — Adaptive Widget Canvas

The Home canvas is an infinite vertical workspace made from a responsive snapped grid. Users can add any supported module, place modules in the order they want, remove modules without confirmation, and resize modules to visual preset footprints.

## What We Build

- A responsive macOS grid that uses the available detail-pane width.
- A platform-appropriate iOS arrangement using the same module identities and saved options.
- Visual footprint presets including compact half-width, standard full-width, tall, and large modules.
- A first-run layout containing Greeting, Today, Quick Start, Activity Shortcuts, and Metrics.
- Continuous local persistence of module order, footprint, and options.
- Edit mode entered by Pencil or a background long press.
- Done and Add controls in edit mode.
- Red remove controls on every module while editing.
- Drag-to-reorder and snapped resize gestures that do not run during normal browsing.
- Keyboard equivalents for focus, move, resize, remove, add, and finish editing on macOS.

## Architecture

The canvas renders persisted module instances through the catalog. Modules are not hard-coded as permanent vertical sections. A module may render a compact or larger visual variant depending on its saved footprint, while keeping the same identity and destination action.

The normal header has Pencil and Settings. To keep the header to two active controls while editing, edit mode uses Add and Done; Settings remains available through the platform menu during editing.

## States

| State | Behavior |
|---|---|
| normal | Modules are tappable and scrollable; no drag or remove affordances are visible |
| editing | Modules show red removal controls, selection/drag affordances, and supported resize handles |
| adding | The picker remains modal to the edit flow; adding inserts immediately when selected |
| moving | The dragged module follows the pointer and neighboring modules make room |
| resizing | The module snaps between supported visual footprints |
| removed | The module disappears immediately and can be restored from Add |
| restored | The module returns using its default or last saved options |
| empty canvas | Add remains available and a calm empty-state prompt points to the picker |
| narrow width | The grid reduces columns and modules retain readable content |
| wide width | Standard and large modules use additional available space without fixed coordinates |

## Animation Rules

- Editing controls appear with a short opacity and scale transition anchored to the module.
- Reordering uses a critically damped spring and follows the pointer continuously.
- Resizing previews the resting footprint during the gesture and settles with a short spring.
- Removing a module fades it while the remaining layout closes the gap.
- Reduced Motion replaces movement with opacity and restrained layout changes.

## Files

- `TimeMaster/Models/HomeWidget.swift` — canvas-facing module instance and footprint types.
- `TimeMaster/ViewModels/HomeWidgetStore.swift` — saved layout and mutation operations.
- `TimeMaster/Views/Home/HomeWidgetCanvas.swift` — grid, edit gestures, and accessibility actions.
- `TimeMaster/Views/Home/HomeWidgetPicker.swift` — add-module presentation.
- `TimeMaster/Views/Home/HomeDashboardView.swift` — header and edit-mode ownership.

## Dependencies

- F27-B — Today module provides the schedule-first default content.
- F27-C — catalog provides module identities, categories, sizes, and option support.
- Existing `Theme` and navigation components provide platform styling and routing.

## Reference

- User Home blueprint — dashed edit boundaries, visible remove controls, visual size previews, and long-press editing.
