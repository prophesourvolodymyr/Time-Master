# F08 — Home Screen Widget

iOS Home Screen widget showing quick workout access and progress summary.

## What We Build
- TimeMasterWidget: WidgetKit widget with workout shortcuts
- TimeMasterWidgetBundle: widget entry point + configuration
- Small/medium widget sizes showing recent workouts or quick-start options
- The widget is configurable per instance: Quick Start opens a selected workout, Today summarizes scheduled workout instances, and Progress shows sessions, streak, and weekly goal progress.
- Small, medium, and large families use the same data with content-aware layouts. Existing saved payloads without newer metrics remain valid and render safe defaults.

## Architecture
```
TimeMasterWidget/
├── TimeMasterWidget.swift        — Widget provider + view
├── TimeMasterWidgetBundle.swift  — @main widget bundle
├── Info.plist                    — Widget configuration
└── TimeMasterWidget.entitlements — App group entitlements
```

## States
| State | Size | Content |
|-------|------|---------|
| has workouts | Small | Last workout name + duration |
| has workouts | Medium | Recent workouts list with quick-start tap targets |
| empty | Any | "Create a workout" prompt |
| loading | Any | Skeleton/spinner placeholder |

## Files
- `TimeMasterWidget/TimeMasterWidget.swift`
- `TimeMasterWidget/TimeMasterWidgetBundle.swift`
- `TimeMasterWidget/Info.plist`
- `TimeMasterWidget/TimeMasterWidget.entitlements`

## Dependencies
- F01 — Core Data Layer (shared UserDefaults via app groups)

## Verification
- [x] Widget compiles and registers as valid WidgetKit extension
- [x] Widget displays on Home Screen in small + medium sizes
- [x] Widget shows recent workout data from shared UserDefaults
- [x] Tap on widget opens main app
- [x] Empty state shows prompt when no workouts exist
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
