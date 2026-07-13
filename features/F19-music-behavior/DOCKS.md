# F19 — Music Behavior (general upload + sequential default)

Today the user uploads music tracks inside Settings. Each workout can select a subset via Workout Settings. Inside the player, if the user manually picks the second track and it finishes, the player just loops the second track instead of advancing. Per ISSUES.md the desired behavior is:
- **Settings** music upload stays general (one shared library) — that's already the design; we only need to make sure no per-workout upload exists.
- **Default** playback during a workout is sequential over the playlist: track 1 → track 2 → … → track N → back to track 1 (queue-level loop), regardless of whether the user manually jumped to a different track mid-workout.
- A per-workout "Repeat one" toggle is optional and OFF by default. When ON, the current track loops until the user advances manually.

## What We Build

- `MusicManager.startPlayback(tracks:)`:
  - Build `AVQueuePlayer` with one `AVPlayerItem` per track in `tracks`.
  - `actionAtEnd = .advanceToNextMedia` (default).
  - When the last track finishes, rebuild the queue and replay (queue-level loop).
  - "Repeat one" mode: when ON, replace the queue with a single looping `AVPlayerLooper`-wrapped item; when OFF, restore queue.
- A user jump to track index `i` mid-workout: replace queue from index `i` onward and continue; once queue ends, loop back to track 0 (NOT track `i`).
- Settings music library UI clarifies: "These tracks play during a workout. Pick subsets per workout inside the workout's settings."
  - Ensure Settings has NO per-workout upload; only the global library.
  - Workout Settings sheet keeps the "select subset" UI; clarifying subtitle is removed for minimalist text goals.
- Player floating controls bar exposes a small music scrubber/playlist button (open the per-workout playlist) and a Repeat-one toggle button.

## Architecture

```
MusicManager
  ├─ shared AVQueuePlayer
  ├─ currentTracks: [String]
  ├─ repeatOne: Bool = false
  │
  ├─ startPlayback(tracks:)  → build queue (no per-track loop)
  ├─ jumpToTrack(index:)      → rebuild queue starting at index
  ├─ toggleRepeatOne()        → if true, hand queue to AVPlayerLooper for current track
  ├─ onItemDidPlayToEndTime   → if no items remaining and not paused → rebuild full queue, repeat from 0
  └─ stopPlayback()           → invalidate looper, queue player, observers
```

## States

| State | Behavior |
|---|---|
| workout launched, no music selected | no playback unless user opens playlist and picks a track manually |
| workout launched, playlist selected | queue starts at track 0, advances each item |
| user jumps mid-workout to track 2 | queue continues from track 2; once reaches end, loops back to track 0 |
| workout paused | queue pauses; resume on timer resume |
| workout completes | queue stops, manager resets |
| Repeat One ON for this workout | only current track loops; toggle off restores queue |
| settings music library | no per-workout upload; library is shared, subscribes for all workouts |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| repeat-one toggle | 0.15s spring | tap |
| playlist reveal | 0.2s ease-out | tap playlist icon |

## Files

- `TimeMaster/Utilities/MusicManager.swift` — AVQueuePlayer queue-level loop, repeat-one toggle, jumpToTrack
- `TimeMaster/Views/Settings/MusicSettingsView.swift` — keep global-only upload; remove "play during workout" subtitle clutter
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — `WorkoutSettingsView` selection UI stays; clarify copy
- `TimeMaster/Views/Player/FloatingControlsBar.swift` — add playlist/repeat buttons
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — music button switches to playlist popover instead of single-track action

## Dependencies

- F16 — player rework (engine drives music lifecycle)
- F17 — text cleanup

## Reference

- `genesis/ISSUES.md` — "the purchase to like the second one when it's finished and person does not select another one it just goes onto loop … inside of the settings that music upload has to be general"

## Verification

- [ ] Settings → Background Music: only a global library; no per-workout upload exists
- [ ] Start workout with selected tracks → plays track 1, then auto-advances to track 2, then to track N, then loops back to track 1
- [ ] Mid-workout user jumps to track 3 → plays track 3, then track 4…N, then loops to track 1 (NOT back to track 3)
- [ ] "Repeat One" toggle for a workout: when ON, current track loops; turning OFF resumes sequential queue from next track
- [ ] Pause workout → music pauses; resume workout → music resumes correctly
- [ ] Complete workout → music stops cleanly, no orphan observers
- [ ] macOS + iOS builds succeed; core tests pass
