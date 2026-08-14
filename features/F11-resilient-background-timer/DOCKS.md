# F11 — Resilient Background Timer

Makes an active workout recover honestly after an interruption or backgrounding on devices that do not support Live Activities. iOS may suspend ordinary apps; this feature never promises indefinite background execution. Instead it checkpoints immediately, requests the system's permitted finite background task window, and reconciles elapsed wall-clock time when the app returns.

## What We Build

- Timestamped checkpoints that capture phase, remaining time, section/set indices, and total elapsed duration.
- Background and interruption observers save a checkpoint before suspension and start a finite iOS background task.
- Resume reconciliation consumes time elapsed since the checkpoint and advances through timer phases as required; expired workouts continue from the correct phase or complete cleanly.
- Foreground/relaunch recovery uses the same reconciliation path and persists the reconciled checkpoint.

## Architecture

```
WorkoutPlayerView lifecycle → WorkoutResumeManager checkpoint
   background/interruption          ↓
   finite iOS task             elapsed-time reconciliation
                                     ↓
                           resume timer / transition phase / complete
```

## States

| State | Behavior |
|---|---|
| foreground active | timer ticks each second and checkpoints every five seconds |
| background transition | checkpoint immediately; request finite background task time on iOS |
| suspended | no false claim of continuous execution; elapsed time is reconstructed on return |
| foreground within phase | reduce remaining time by elapsed duration and resume |
| foreground after one or more phases | advance all consumed phases deterministically, preserving sets/sections |
| app relaunched | resume prompt offers the reconciled state; discarded state follows existing partial-workout rules |
| macOS window inactive | timer continues while the process remains running; timestamp reconciliation protects against interruption |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| resume prompt | existing app sheet transition | resumable checkpoint found at launch |

## Files

- `TimeMaster/ViewModels/WorkoutResumeManager.swift` — checkpoint reconciliation
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — lifecycle, phase transition, finite background task handling
- `TimeMaster/App/TimeMasterApp.swift` — resume prompt uses reconciled state

## Dependencies

- F03-A — existing persistence and partial logging.

## Reference

- `genesis/REFERENCE/` — no direct reference required.

## Verification

- [ ] Background checkpoint saves immediately and finite task ends safely.
- [ ] A timer resumes with correct remaining/elapsed time after time away from the app.
- [ ] Resume spans set rest, section rest, warm-up, and active phases.
- [ ] A fully elapsed workout completes without corrupting history.
- [ ] macOS target compiles.
