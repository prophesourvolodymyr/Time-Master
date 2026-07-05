# F03-C — Player Overlay

Floating controls bar that stays visible when the user opens an exercise page overlay during a workout. Compact pill with timer, pause/stop, and section progress.

## What We Build
- Compact pill bar (44pt height, rounded, semi-transparent dark background)
- Position: top or bottom of screen (configurable, default bottom)
- Content: current exercise name (truncated), countdown/elapsed timer, pause/resume icon, stop icon (X), section progress (e.g. "3/5")
- Timer format: `MM:SS` for timed, `MM:SS elapsed` for bundle
- Pause/Resume: tap to pause, icon changes, timer freezes
- Stop: tap → confirmation alert → end workout
- Always on top of any overlay (F02-A-d, F03-B)
- Hides during active player full-screen view (only shown when overlay is open)

## States
| Context | Controls shown |
|---------|---------------|
| Timed section, page overlay open | Countdown, pause, stop, section progress |
| Rest phase, page overlay open | Rest countdown, skip rest, stop |
| Bundle section, page overlay open | Elapsed time, next exercise name, stop |
| Player full-screen (no overlay) | Hidden — player has its own controls |

## Architecture
- `FloatingControlsBar.swift` — standalone View, no external dependencies except workout state
- Receives: timer state, pause action, stop action, section progress
- Updates in real-time via timer publisher (same timer used by player)
- Semi-transparent: `Theme.background.opacity(0.85)` with blur effect

## Files
- `TimeMaster/Views/Player/FloatingControlsBar.swift` (new — shared with F02-A-d)

## Verification
- [ ] Pill bar visible when page overlay is open during workout
- [ ] Timer updates in real-time, matches player timer
- [ ] Pause pauses the workout, icon toggles correctly
- [ ] Stop shows confirmation, stops workout on confirm
- [ ] Section progress indicator updates on section change
- [ ] Hidden during full-screen player (no overlay)
- [ ] Works for both timed and bundle modes
- [ ] compiles without errors
