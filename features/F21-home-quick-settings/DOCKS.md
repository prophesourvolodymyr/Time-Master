# F21 — Home Quick Settings Access

The user wants a quick Settings button on the Home dashboard. Currently Settings is reachable only from the Workouts list toolbar (gear icon) — invisible from Home. Add a clearly visible Settings access on the Home dashboard toolbar so the user can open Settings in one tap.

## What We Build

- A `Settings` toolbar item in `HomeDashboardView` (gear icon, primaryAction placement on iOS, secondary-action on macOS sidebar detail).
- On iOS, tapping the gear opens a `.sheet` with `SettingsView`.
- On macOS, tapping opens a `.sheet` with `SettingsView` using the safe dismissal path implemented in F18 (NOT a separate window unless F18 decides so).
- The dashboard's existing toolbar keeps its "Browse Workouts" stack icon; the gear is added beside it.
- VoiceOver label: "Open Settings".

## Architecture

```
HomeDashboardView
  ├─ navigationTitle("Today")
  └─ toolbar
      ├─ Browse Workouts (stack.icon)
      └─ Settings (gear.icon) → .sheet(SettingsView)
```

## States

| State | Behavior |
|---|---|
| dashboard idle | gear visible in toolbar |
| sheet open | settings sheet appears, dismiss returns to dashboard |
| macOS | same path, no crash on close |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| settings sheet open | platform default | tap gear |

## Files

- `TimeMaster/Views/Home/HomeDashboardView.swift` — add toolbar item + sheet binding

## Dependencies

- F18 — macOS safe settings sheet path
- F17 — minimalist cleanup so the toolbar stays uncluttered

## Reference

- `genesis/ISSUES.md` — "Make sure on the home page there is a button to quickly access settings"

## Verification

- [ ] Gear icon visible on Home dashboard toolbar (iOS and macOS)
- [ ] Tap opens Settings sheet
- [ ] Close Settings sheet returns to Home with no crash
- [ ] VoiceOver announces "Open Settings"
- [ ] Both builds succeed
