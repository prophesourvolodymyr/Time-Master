# F07-A — UI Polish

Fix visual glitches: navigation bar fade/transparency and icon background rendering.

## What We Build
- **Navigation fade fix:** The fade/gradient at the top of scrollable views (behind nav bar) has a transparent gap where icons are visible through it. Fix: ensure gradient overlay extends full width and starts at safe area top edge.
- **Icon transparency:** Background behind toolbar/tab bar icons renders as transparent when it should be opaque. Fix: add proper background fill to toolbar areas.

## Architecture
- `MainTabView.swift` — verify toolbar background rendering
- Individual list views (`WorkoutListView.swift`, `DatabaseView.swift`, `HistoryView.swift`, `AnalyticsView.swift`, `AICoachView.swift`) — check navigation bar appearance modifiers

## Files
- `TimeMaster/Views/MainTabView.swift`
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift`
- View files with scroll content behind navigation bars

## Verification
- [ ] No transparent gap at top of scroll views behind navigation bar
- [ ] Toolbar/tab bar background fully opaque in all tabs
- [ ] Gradient overlays extend edge-to-edge
- [ ] Light/dark mode both render correctly
