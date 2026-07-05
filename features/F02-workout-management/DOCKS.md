# F02 — Workout Management

CRUD UI for workouts and sections: list, detail, section editor, photo picker, drag-and-drop reorder.

## What We Build
- WorkoutListView: main workout list with floating "+" button, swipe-to-delete
- WorkoutCard: card UI showing name, section count, total duration
- WorkoutDetailView: edit workout, list sections, drag reorder, "Start Workout" button
- SectionRow: photo thumbnail + name + duration, swipe edit/delete
- SectionEditorView: photo picker, name textfield, duration stepper, color picker
- MediaPreviewSheet: full-screen photo/video preview
- MainTabView: TabView with Workouts, Database, AI Coach, Analytics, Settings tabs

## Architecture
```
Views/
├── MainTabView.swift               — 5-tab root (Workouts, Database, AI Coach, Analytics, Settings)
├── WorkoutList/
│   ├── WorkoutListView.swift       — NavigationStack + List + "+" FAB
│   └── WorkoutCard.swift           — RoundedRectangle card on Surface color
├── WorkoutDetail/
│   ├── WorkoutDetailView.swift     — Edit mode, section list, drag handles, "Start Workout"
│   ├── SectionRow.swift            — HStack: 60x60 thumbnail + VStack(name, duration)
│   ├── SectionEditorView.swift     — PhotosPicker + TextField + Stepper (5-300s, 5s increments)
│   └── MediaPreviewSheet.swift     — Full-screen media with dark overlay
└── History/
    └── HistoryView.swift           — Completed workout log
```

## States
| State | View | Behavior |
|-------|------|----------|
| empty | WorkoutListView | "No workouts yet" placeholder, "+" button visible |
| populated | WorkoutListView | Scrollable list of WorkoutCards |
| no sections | WorkoutDetailView | "Start Workout" disabled, empty state message |
| has sections | WorkoutDetailView | Sections listed with drag handles, "Start Workout" enabled |
| editing | WorkoutDetailView | Edit mode: name editable, sections draggable, delete enabled |
| rest enabled | SectionEditorView | Extra stepper for rest duration between sections |

## Files
- `TimeMaster/App/TimeMasterApp.swift`
- `TimeMaster/Views/MainTabView.swift`
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift`
- `TimeMaster/Views/WorkoutList/WorkoutCard.swift`
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift`
- `TimeMaster/Views/WorkoutDetail/SectionRow.swift`
- `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift`
- `TimeMaster/Views/WorkoutDetail/MediaPreviewSheet.swift`

## Dependencies
- F01 — Core Data Layer (WorkoutStore, PhotoManager, Theme)

## Verification
- [x] Create workout → appears in list
- [x] Edit workout name → persists
- [x] Delete workout → removed from list and store
- [x] Add section with photo → photo thumbnail visible, name + duration correct
- [x] Drag reorder sections → order persists
- [x] Delete section → removed from workout
- [x] "Start Workout" disabled when no sections, enabled when sections exist
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
