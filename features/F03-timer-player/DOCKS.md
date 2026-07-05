# F03 — Timer & Player

Full-screen workout player with countdown timer, sequential section execution, rest periods, pause/resume, and audio cues.

## Sub-Features
- [ ] **F03-A** — Persistence & Resume (background, resume, partial save)
- [ ] **F03-B** — In-Workout Controls & Media (rest preview, full media overlay, rest adjustment)

## What We Build
- WorkoutPlayerView: immersive full-screen player with photo, timer, progress bar
- Sequential section execution with configurable rest between sections
- Audio countdown cues (3-2-1 beeps via AudioManager)
- Pause/Resume controls
- Stop/exit with confirmation
- Background timer support (app backgrounded during workout)
- Workout completion screen → auto-log to history

## Architecture
```
Views/Player/
└── WorkoutPlayerView.swift  — Full workflow: section display → countdown → rest → advance → done

Utilities/
└── AudioManager.swift       — System sounds for countdown beeps, exercise name announcement
```

## States
| State | UI | Behavior |
|-------|----|----------|
| playing | Full-screen photo + name + countdown | Timer ticks down, progress bar animates |
| paused | Dimmed overlay + "Paused" label | Timer frozen, resume button prominent |
| rest | Teal background + "Rest" + timer | Auto-advances when rest timer reaches 0 |
| countdown | 3-2-1 overlay | Audio beeps on each number |
| completed | "Done!" screen | Workout logged to history, dismiss button |
| empty | N/A | Cannot reach player without sections |

## Animation Rules
- Progress bar: smooth fill from 100% to 0% over section duration
- Section transition: crossfade photo + slide name text
- Countdown overlay: scale + opacity spring on each number

## Files
- `TimeMaster/Views/Player/WorkoutPlayerView.swift`
- `TimeMaster/Utilities/AudioManager.swift`

## Dependencies
- F01 — Core Data Layer (WorkoutStore for workout data, Theme for colors)

## Verification
- [x] Start workout → first section photo + name + timer displayed
- [x] Timer counts down correctly, progress bar animates
- [x] 3-2-1 audio countdown plays at end of section
- [x] Rest period displays between sections (configurable)
- [x] Pause freezes timer, resume continues from paused time
- [x] Stop button exits player, returns to detail view
- [x] Workout completion logs to history
- [x] App backgrounding does not interrupt timer (background audio enabled)
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
