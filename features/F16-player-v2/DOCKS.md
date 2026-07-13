# F16 — V2 Player Rework

The user reports the player is "the same, old feature". The current player supports the file-based workout model (timed slots + bundle slots) but is brittle: media loads on the main thread, AVQueuePlayer/AVPlayerLooper are not always invalidated, the warm-up flow double-fires on resume, the page overlay can lock the UI behind a half-dismissed transition, and music selection "loops one track" instead of advancing through the workout's selected tracks. This feature rebuilds the player around the V2 page-backed runtime model with a clean phase machine, background-safe checkpoints, and music that queues correctly.

## What We Build

- A single phase-machine state object (`WorkoutPlayerEngine`) that owns phase, current section, current slot, elapsed time, and checkpoints. The view becomes a pure render of the engine state.
- Page-backed slot rendering: each slot resolves to an `ExercisePage` (cover, markdown preview, media carousel). If a slot has no page (legacy), it falls back to its inline `name` + `mediaItems`.
- Background-safe checkpoints triggered on `.didEnterBackground` (iOS) and `.windowDidResignKey` (macOS) — restore works across both platforms.
- Music playback uses `MusicManager.startPlayback(tracks: workout.selectedTrackFilenames)` with `AVQueuePlayer` looping *over the selected track list*, not over a single track. When the user manually picks track N mid-workout, after track N finishes the queue advances to track N+1 (not loop N). Only if the user explicitly enables repeat-one for this workout do tracks loop individually.
- The exercise page overlay (`ExercisePageOverlay` + `FloatingControlsBar`) opens with a smooth transition, never blocks the timer, and dismisses cleanly on swipe-down. It never re-enters a half-state.
- The "Open Page" button on the timed section appears only when the slot has a real `exercisePageID`.
- Skip-section + skip-rest always land on a deterministic next state; no orphan `timer.fire()` calls.
- Wins from prior cycle are kept: warm-up picker, partial-logging, resume reconciliation, AVQueueLooper for video carousel.
- macOS: the player sheet presents as a full-window modal so the user never sees a half-clipped player smearing across the sidebar.

## Architecture

```
WorkoutPlayerView
  └─ WorkoutPlayerEngine (ObservableObject)
      ├─ phase: WorkoutPhase  // warmUp / active / setRest / sectionRest / completed
      ├─ currentSectionIndex, currentSlotIndex
      ├─ elapsedSeconds, timeRemaining
      ├─ musicTracks: [String]  // from workout.musicTrackFilenames
      └─ actions: tick / pause / resume / skip / stop / extendRest / openPageOverlay
```

```
MusicManager.startPlayback(tracks:)
  └─ AVQueuePlayer with all tracks as AVPlayerItem
     ├─ default actionAtEnd = .advanceToNextMedia
     └─ after last track finishes → loop back to first track (queue-level loop, not per-track)
     └─ if user manually jumps to track N → queue continues from N until end + loops to 0
```

## States

| Phase | Visible | Engine behavior |
|---|---|---|
| warmUpPicker | warm-up duration grid + Start/Skip | no timer running |
| warmUp | "WARM UP" countdown + pause + skip | timer ticks `warmUpDuration` seconds |
| active (timed) | section media carousel + name + set N/M + countdown + pause + skip | timer ticks `slot.duration` |
| active (bundle) | bundle cover + name + index/total + Next | self-paced; elapsed counter advances; no auto-advance |
| setRest | "REST BETWEEN SETS" + countdown + skip + extend | timer ticks `slot.restAfter` |
| sectionRest | "REST" + next preview + skip + extend | timer ticks `section.customRestAfter ?? workout.restBetweenSections` |
| completed | confetti + Done | timer stopped, history entry written |
| page overlay active | full-screen `ExercisePageOverlay` + `FloatingControlsBar` | timer keeps running in background; overlay dismiss returns to phase view |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| warmUpPicker → warmUp | 0.3s ease-out | start button tap |
| phase transition | 0.25s ease-out | tick reaches zero |
| page overlay open | 0.3s ease-out | section name tap |
| page overlay dismiss | 0.3s ease-in | swipe down or chevron |
| rest-extension flash | 0.3s ease-in-out | +15s/+30s extension |
| music track change | none | user scrubber |

## Files

- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — pure V2 view + engine binding
- `TimeMaster/Views/Player/WorkoutPlayerEngine.swift` — new phase-machine class
- `TimeMaster/Views/Player/FloatingControlsBar.swift` — already V2, integrate with engine state
- `TimeMaster/Views/Player/ExercisePageOverlay.swift` — already V2, verify dismiss path
- `TimeMaster/Utilities/MusicManager.swift` — AVQueuePlayer over selected list, queue-level loop only
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` — checkpoint already correct; consume from engine

## Dependencies

- F02-A-a/b/c — page-backed section model and bundle mode
- F11 — resilient background timer reconciliation
- F13 — stability (must land first or the player stays fragile)
- F19 — music behavior agreement

## Reference

- `genesis/ISSUES.md` — "Workout management was never built … same with the player"
- `genesis/REFERENCE/` — none

## Verification

- [ ] Warm-up → active → setRest → active → sectionRest → next active → completed flows without missed ticks
- [ ] Mid-section tap → page overlay opens, timer continues; swipe down dismisses and returns to same phase
- [ ] Skip-section → lands on the correct next section; no skipped first/last slot
- [ ] Background (iOS) → checkpoint written; foreground reconciles elapsed time
- [ ] macOS window resigns key → checkpoint written; re-key restores
- [ ] Workout with 3 selected music tracks: manually play track 2; once track 2 ends, track 3 starts (then loops queue, not track)
- [ ] Bundle workout swipe navigation advances slots correctly
- [ ] History entry written exactly once per completed workout
- [ ] macOS + iOS builds succeed; core tests pass
