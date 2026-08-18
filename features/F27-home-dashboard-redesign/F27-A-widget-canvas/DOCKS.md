# F27-A — Adaptive Widget Canvas

The Home canvas is an infinite vertical workspace made from a responsive snapped grid. Users can add any supported module, place modules in the order they want, remove modules without confirmation, and resize modules to visual preset footprints.

## What We Build

- A responsive macOS grid that uses the available detail-pane width.
- A platform-appropriate iOS arrangement using the same module identities and saved options.
- A single exact wide widget footprint: two grid columns by one row, rendered at a 2:1 width-to-height ratio on every platform.
- A first-run layout containing Greeting, Today, Quick Start, Activity Shortcuts, and Metrics.
- Continuous local persistence of module order, footprint, and options.
- Edit mode entered by Pencil or a background long press.
- Done and Add controls in edit mode.
- Red remove controls and dashed boundaries on every module while editing.
- Visible dashed insertion slots show where a dragged module can be placed.
- Drag-to-reorder uses a direct drag handle and snaps into insertion slots without changing widget size.
- Keyboard equivalents for focus, move, remove, add, and finish editing on macOS.

## Architecture

- The canvas renders persisted module instances through the catalog. Modules are not hard-coded as permanent vertical sections. Every module uses the same wide visual footprint so content previews and the canvas have one spatial contract.
- The normal header has Pencil and Settings. To keep the header to two active controls while editing, edit mode uses Add and Done; Settings remains available through the platform menu during editing.

## States

| State | Behavior |
|---|---|
| editing | Modules show red removal controls, dashed boundaries, insertion slots, and a direct drag handle. |
| adding | The picker remains modal to the edit flow; adding inserts immediately when selected. |
| moving | The dragged module follows the pointer from the handle and neighboring insertion slots make room. |
| removed | The module disappears immediately and can be restored from Add. |
| restored | The module returns using the standard wide footprint and saved options. |
| empty canvas | Add remains available and a calm empty-state prompt points to the picker. |
| narrow width | The wide footprint follows the available width while retaining its 2:1 ratio. |
| wide width | The wide footprint follows the available width while retaining its 2:1 ratio. |

## Animation Rules

- Editing controls appear with a short opacity and scale transition anchored to the module.
- Reordering uses a critically damped spring and follows the pointer continuously.
- Insertion slots expand and highlight while a module is dragged over them.
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
