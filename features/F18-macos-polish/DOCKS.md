# F18 — macOS Polish (window clip, box artifacts, settings crash)

The macOS build has three blocking UI defects: (1) the main app window clips on the sidebar side — the background color gets cut off at the sidebar boundary so the visual edge looks wrong; (2) there are unexplained bordered boxes behind the "go to page" navigation links inside the Analytics page and inside the Player — they look like leftover SwiftUI `GroupBox`/bordered container views; (3) the Settings window opens wrongly because it currently is presented as a sheet that overlaps the title-strip area, and trying to close it crashes the app. This feature fixes all three for a clean macOS desktop experience.

## What We Build

- Main window sidebar background fills its full column — no color clipping at the split. Apply `Theme.background` to the sidebar container explicitly so the `NavigationSplitView` column shows the right color from edge to edge.
- Remove every `GroupBox`/`.box`/bordered container that surrounds "go to page" navigation on macOS. Audit `AnalyticsView`, `WorkoutPlayerView` (page overlay hints, rest context), and any other place where `GroupBox { ... }` or `RoundedRectangle.stroke` may be wrapping a navigation link.
- Settings becomes a real macOS sheet anchored correctly under the title bar — the close button (`.cancel` placement + ⌘W) dismisses the sheet without crashing. Investigate crash cause: most likely the SettingsView on macOS opens inside a `NavigationStack` inside a sheet whose dismiss path is racing with the toolbar's window-close command; either present Settings as a separate `Window` (`.window(resizability:)`) or as a fixed-position sheet with explicit toolbar cancel handler.
- Verify rest-pickers, sort menus, and popovers are not double-bordering on macOS.
- Maintain iOS parity — none of the macOS fixes should change the iOS layout.

## Architecture

```
MainTabView (macOS)
  ├─ NavigationSplitView {
  │     List { Home, Workouts, Database, Analytics, AI Coach }
  │       .background(Theme.background.ignoresSafeArea()) // ← ensure full-bleed
  │  } detail: {
  │     detailView
  │  }
  └─ Settings: present as a Command-triggered sheet with explicit cancel
     └─ macOS sheet close path:
         ├─ ⌘W → dismiss sheet (NOT close window)
         └─ toolbar cancel → dismiss sheet
         └─ no windowWillClose mutation race
```

```
AnalyticsView on macOS
  └─ remove GroupBox wrappers around navigation links
     └─ links render as plain rows with chevron — no extra box
```

## States

| State | Before | After |
|---|---|---|
| macOS sidebar background | clipped at split, lighter strip | full-bleed Theme.background |
| Analytics "go to page" navigation | visible GroupBox / framed box | plain row + chevron, no box |
| Player rest-context / page overlay hint | bordered box behind row | clean row, no box |
| Settings open on macOS | sheet spills into title strip, close crashes | separate sheet with safe dismiss, ⌘W works |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| settings sheet open | system default | ⌘, or "Settings" menu |
| settings sheet close | system default | cancel button / ⌘W for sheet |

## Files

- `TimeMaster/Views/MainTabView.swift` — sidebar background fill fix
- `TimeMaster/Views/Settings/SettingsView.swift` — crash-safe presentation on macOS (use `.sheet` with explicit cancel handler; remove any windowWillClose code)
- `TimeMaster/App/TimeMasterApp.swift` — ensure `.windowStyle` doesn't conflict with Setting sheet host
- `TimeMaster/App/MacCommands.swift` — `Settings...` command posts `openSettingsCommand`; home view observes and presents sheet OR app presents a dedicated `Settings` scene
- `TimeMaster/Views/Analytics/AnalyticsView.swift` — remove GroupBox wrappers
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — remove bordered hint boxes in rest view, page overlay hint, etc.

## Dependencies

- F13 — stability must be confirmed first because settings close crash may be same root cause

## Reference

- `genesis/ISSUES.md` — "main app window clips in teh sidebase side … weird boxes around the ap behind the go to page … cannot prop properly open the settings window … crash"
- `genesis/REFERENCE/` — none

## Verification

- [ ] macOS sidebar fills the full column with `Theme.background`, no lighter strip at edge
- [ ] Analytics page on macOS shows navigation links without a visible box/frame
- [ ] Player on macOS shows rest and page transition hints without a visible box
- [ ] Open Settings via ⌘, → opens as a sheet, can be closed with cancel button or ⌘W without crash
- [ ] Open Settings, then close → main window remains interactive
- [ ] iOS layout unchanged after the macOS fixes
- [ ] macOS build succeeds, all core tests pass
