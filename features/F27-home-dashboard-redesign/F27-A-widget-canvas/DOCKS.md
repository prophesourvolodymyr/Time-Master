# F27-A — Adaptive Widget Canvas

The Home canvas is an infinite vertical workspace made from a responsive snapped grid. Users can add any supported module, place modules in the order they want, remove modules without confirmation, and switch each module between its supported visual shapes.

## What We Build

- A responsive macOS grid that uses the available detail-pane width.
- A platform-appropriate iOS arrangement using the same module identities and saved options.
- Compact 0.5:2 half-width two-row, square 1:1 full-width, and wide 1:2 full-width widget footprints selected per module.
- Greeting is a full-width text strip rather than a shaped card and has no selectable footprint.
- A first-run layout containing Greeting, Today, Quick Start, Activity Shortcuts, and Metrics.
- Continuous local persistence of module order, footprint, and options.
- Edit mode entered by Pencil or a background long press.
- Done and Add controls in edit mode.
- Direct per-module options and shape controls in edit mode when a module supports them.
- Red remove controls and dashed boundaries on every module while editing.
- Insertion slots remain hidden at rest and appear only while a module is actively dragged.
- Drag-to-reorder starts from any point on the widget base and snaps into insertion slots without changing widget size.
- Action-heavy modules such as Quick Start may use a card surface; ordinary modules rest directly on the canvas.
- Keyboard equivalents for focus, move, remove, add, and finish editing on macOS.

## Architecture

- The normal header has Pencil and Settings. To keep the header to two active controls while editing, edit mode uses Add and Done; each module exposes its own options and shape control while editing.

## States

| State | Behavior |
|---|---|
| editing | Modules show direct options/shape controls, removal controls, dashed boundaries, and a full-base drag affordance. Insertion slots are not visible until a drag begins. |
| adding | The picker remains modal to the edit flow; adding inserts immediately when selected. |
| moving | The dragged module follows the pointer from any point on its base and neighboring insertion slots appear to make room. |
| removed | The module disappears immediately and can be restored from Add. |
| restored | The module returns using its saved shape and options. |
| empty canvas | Add remains available and a calm empty-state prompt points to the picker. |
| narrow width | Compact, square, and wide footprints follow the available width while retaining their own ratios. |
| wide width | Compact, square, and wide footprints follow the available width while retaining their own ratios. |

## Animation Rules

- Editing controls appear with a short opacity and scale transition anchored to the module.
- Shape changes settle into the selected footprint without changing module order.
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
