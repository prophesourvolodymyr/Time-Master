# F13 — Stability & Freeze Investigation

The app freezes at unpredictable moments while the user is doing ordinary things — tapping a card, opening a sheet, opening settings, navigating between tabs. No visible cause, no crash. Workouts sometimes stop responding. This feature tracks the diagnosis and the fixes that bring the app to stable, always-responsive behaviour.

## What We Build

- Reproduce the freeze with a small set of repeating user flows (home → workout → player; home → database → page detail; settings open/close; rapid tab switches).
- Identify the dominant causes by inspection and Instruments: main-thread file I/O, recursive `DatabaseStore.reload()` storms, runaway `onAppear` work, scroll-offset preference-key churn, AVQueuePlayer/AVPlayerLooper retain cycles, and any `@StateObject` re-allocation on view re-render.
- Eliminate every main-thread file read on the hot path — move disk reads (cover images, guide markdown, media thumbnails) to background queues with a single cached published value, and invalidate any scroll-offset `PreferenceKey` bindings that re-evaluate the body every frame.
- Stop cascading `store.reload()` calls — each sheet dismiss should trigger at most one reload, debounce if necessary.
- Add an in-app stability checklist (manual test script) that the user runs after the fix to confirm freezes are gone.

## Architecture

```
Diagnostic pass
  tap → main queue blocks? → identify blocker
     ├─ File I/O on main        → move to background + cache
     ├─ Reload storm            → single reload, debounced
     ├─ PreferenceKey churn     → remove or batch
     ├─ Timer + AVQueue cycle   → break retain cycle, centralize observer lifecycle
     └─ @StateObject recreation → hoist to long-living owner
```

## States

| State | What user sees | Behavior after fix |
|---|---|---|
| idle in any screen | static UI | no timers firing, no main-thread reads |
| open sheet | sheet animate in | one reload on dismiss only |
| scroll detail page | smooth scroll | scroll-offset preference does not re-render body |
| play workout | timer ticks | no freeze at phase transitions |
| switch tabs quickly | instant | no sheet/sheet collision, no orphan observers |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| none — this feature is correctness-only | — | — |

## Files

- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — loadGuideContent already async; review cover/coverImageURL reads on main
- `TimeMaster/Views/Database/PageCardView.swift` — coverImageGrid reads Data on main; move to async thumbnail cache
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — Timer + AVQueuePlayer + AVPlayerLooper lifecycle review
- `TimeMaster/ViewModels/DatabaseStore.swift` — reload() callers, debounce if many call in same runloop
- `TimeMaster/Utilities/PhotoManager.swift` — cache thumbnails, never block main thread
- `TimeMaster/Views/AsyncCoverImage.swift` — async cached cover loader used by page, card, overlay, and player cover paths
- Any view using `GeometryReader` + `PreferenceKey` for scroll offset — remove or batch

## Dependencies

- None — must be done first so later features build on a stable base.

## Reference

- `genesis/ISSUES.md` — "app keeps freezing when I'm doing something random"
- `genesis/REFERENCE/` — none needed

## Verification

Implementation evidence: macOS Debug build succeeded with Xcode; `swift test` passed all 67 core tests. Hardware freeze flows remain unchecked until the app is exercised on the target device.

- [ ] Fresh launch → 30s idle in Home → no main-thread stalls
- [ ] Open a page detail from grid → smooth scroll through 200-point content
- [ ] Open + close 5 different sheets in a row → no freeze between sheets
- [ ] Run a timed workout through two section transitions → timer continues, no hang
- [ ] Run a bundle workout with 5 swipes → no pause/skip glitch
- [ ] Open Settings window on macOS → close immediately → no crash
- [ ] Switch tabs 20× rapidly → no freeze, no orphan sheet
