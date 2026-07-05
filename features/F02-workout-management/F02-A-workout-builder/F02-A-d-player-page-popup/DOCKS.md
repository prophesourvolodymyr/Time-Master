# F02-A-d — Player Page Popup

During a workout, tapping an exercise name, photo, or the "Open Page" button on a bundle card opens the full ExercisePage from the database as an overlay. Floating player controls remain accessible: pause, stop, time remaining, next exercise preview.

## What We Build

### Exercise Page Overlay
- Full-screen overlay presenting the ExercisePage exactly as seen in the database browser (F05-B)
- Content: cover image, all media items (scrollable gallery), notes, external links (YouTube embed), tags
- Scrollable — user can browse everything about the exercise mid-workout
- Tap to dismiss, returning to the player

### Floating Player Controls
- Always visible on top of the exercise page overlay (or bottom)
- Semi-transparent pill bar showing:
  - Time remaining in current section/set
  - Pause/Resume button
  - Stop workout button
  - Exercise name + section progress (e.g. "3 of 5")
- Bar is compact, not obstructing content (40-50pt height)
- Works for both timed sections and bundle sections
- For bundle sections: shows elapsed time instead of countdown, "Next" button replaces time

### States
| Player state | Overlay | Controls |
|-------------|---------|----------|
| Timed, active | Page open, timer running | Shows countdown, pause, stop, section progress |
| Timed, rest | Page open, rest timer running | Shows rest countdown, skip rest |
| Bundle, active | Page open | Shows elapsed time, next exercise preview |
| Overlay dismissed | Return to player | Full player UI restored |

## Architecture
```
Views/Player/
├── WorkoutPlayerView.swift           — add page popup trigger
├── FloatingControlsBar.swift         (new) — compact pill with controls
└── ExercisePageOverlay.swift         (new) — full-screen page viewer

Reuse from F05-B:
└── Views/Database/ExercisePageView.swift — page content rendering
```

## Files
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (modify)
- `TimeMaster/Views/Player/FloatingControlsBar.swift` (new)
- `TimeMaster/Views/Player/ExercisePageOverlay.swift` (new)

## Verification
- [ ] Tap exercise in player → full page overlay opens
- [ ] Page shows all content: media, notes, links, YouTube embed
- [ ] Floating controls bar visible with timer, pause, stop
- [ ] Timer continues running while overlay is open
- [ ] Pause/stop works from floating controls
- [ ] Dismiss overlay → return to player at current position
- [ ] Bundle mode: elapsed time shown, next button works
- [ ] compiles without errors
