# F02-A-b — Drag-to-Build + Sets

Lego-style workout builder: drag exercises from database into workout sections, configure sets, drops, and rest exercises. Two section types share the same set/rest model.

## What We Build

### Data Model
```swift
struct WorkoutSection: Identifiable, Codable {
    var id: UUID
    var mode: SectionMode       // .timed or .bundle
    var sets: [SetSlot]
}

enum SectionMode: String, Codable {
    case timed                 // countdown timer, auto-advance
    case bundle                // card browser, self-paced, swipe-to-next
}

struct SetSlot: Identifiable, Codable {
    var id: UUID
    var exercisePageID: UUID   // which DB page
    var duration: Int          // work time (ignored in bundle mode)
    var restAfter: Int         // rest duration after this set
    var restExerciseID: UUID?  // optional DB page to show during rest (nil = passive rest)
}
```

### Builder UI
- **Add Work Section:** Pick exercise from DB browser, sets=1 default. Expand to add sets.
- **Add Set:** Same exercise, new slot with rest between.
- **Add Drop:** Pick a DIFFERENT DB exercise for the next set slot with short rest (5s default).
- **Rest slot:** Tap → pick exercise from DB (or clear for passive rest). Shows exercise thumbnail during playback.
- **Add Bundle Section:** Pick multiple DB pages, reorderable list, no timer config needed.
- **Drag reorder:** Sections, sets, bundle items — all draggable via List `.onMove`.

### UI Layout
```
┌─ Work Section ─────────────────────────┐
│  Bicep Curls                    [collapse]  [≡ drag]
│  ┌─────────────────────────────────────┐
│  │ Set 1  Bicep Curls (heavy)   30s     │
│  │  Rest  Shoulder mobility    [15s] [✕]│
│  ├─────────────────────────────────────┤
│  │ Set 2  Bicep Curls (light)   30s     │
│  │  Rest  (passive)           [15s] [✕] │
│  ├─────────────────────────────────────┤
│  │ Set 3  Bicep Curls (drop)    30s     │
│  │  Rest  —                         [✕] │
│  └─────────────────────────────────────┘
│  [+ Add Set]  [+ Add Drop]              │
└────────────────────────────────────────┘

┌─ Bundle Section ─────────────────────┐
│  Boxing Combos              [≡ drag] │
│  • Jab            [≡ drag]           │
│  • Cross          [≡ drag]           │
│  • Hook           [≡ drag]           │
│  [+ Add from DB]                     │
└─────────────────────────────────────┘
```

## Files
- `TimeMaster/Models/Workout.swift` (add WorkoutSection, SetSlot, SectionMode)
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` (rewrite)
- `TimeMaster/Views/WorkoutDetail/WorkoutSectionRow.swift` (new)
- `TimeMaster/Views/WorkoutDetail/SetSlotRow.swift` (new)

## Verification
- [ ] Create work section: pick exercise, configure sets
- [ ] Add set: new slot appears with rest between
- [ ] Add drop: pick different exercise, short rest auto-set
- [ ] Rest slot: pick exercise from DB → thumbnail appears
- [ ] Rest slot: clear → passive rest shown
- [ ] Create bundle section: pick multiple pages, reorder via drag
- [ ] Sections, sets, bundle items all draggable
- [ ] compiles without errors
