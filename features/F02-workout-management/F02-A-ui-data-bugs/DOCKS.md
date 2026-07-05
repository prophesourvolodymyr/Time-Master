# F02-A — UI & Data Bugs

Fixes for broken CRUD reactivity, sets, rest timer stepper, pinning, and per-workout settings.

## Bug Fixes
1. **CRUD not reflecting:** Adding/editing/deleting workouts/sections requires navigating away and back to see changes. Fix: ensure `@Published` / `objectWillChange` fires on all mutation paths in WorkoutStore + views properly observe changes.
2. **Reorder not persisting:** Drag-and-drop section order doesn't stick. Fix: verify reorder handler calls store mutation that triggers `objectWillChange`.
3. **Delete needs restart:** Deleting workout from list requires app restart. Fix: remove from array + call `objectWillChange.send()`.
4. **Rest timer +/- broken:** Stepper buttons in SectionEditorView don't respond. Fix: binding issue with 5s step interval, ensure min 5s / max 300s enforced.
5. **Sets functionality broken:** Setting sets count in SectionEditorView doesn't affect playback. Fix: add `sets: Int` + `restBetweenSets: Int` to Section model, implement set repetition loop in WorkoutPlayerView.

## Enhancements
6. **Pin workouts:** Long-press → "Pin to Top". Pinned workouts appear at top with pin icon. State persists. Add `isPinned: Bool` to Workout model.
7. **Per-workout settings:** Gear icon on WorkoutDetailView → settings sheet: custom music track, cover image, motivational quote basket, accent color. Falls back to global defaults when not set.

## Files
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift`
- `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift`
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift`
- `TimeMaster/Views/WorkoutList/WorkoutCard.swift`
- `TimeMaster/Models/Workout.swift`
- `TimeMaster/ViewModels/WorkoutStore.swift`
- `TimeMaster/Views/Player/WorkoutPlayerView.swift`
- `TimeMaster/Views/WorkoutDetail/WorkoutSettingsView.swift` (new)

## Verification
- [ ] Add/edit/delete/reorder section → reflects immediately, no nav needed
- [ ] Create/delete workout → list updates instantly
- [ ] Rest +/- increments 5→10→15... correctly
- [ ] Sets=3 causes section to repeat 3x during playback
- [ ] Pin/unpin workout with long-press, persists across relaunch
- [ ] Per-workout settings sheet opens, selections save and apply
