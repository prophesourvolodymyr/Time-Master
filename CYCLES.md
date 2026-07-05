# CYCLES.md — Time-Master

## Cycle 0 — Documentation
- [x] Project structure + all DOCKS.md files
- [x] CYCLES.md created
- [x] genesis/ORIGINAL IDEA.md created

## Cycle 1 — Core Foundation
- [x] F01 — Core Data Layer
- [x] F02 — Workout Management
- [x] F03 — Timer & Player

## Cycle 2 — Polish & Extend
- [x] F04 — History & Analytics
- [x] F05 — Database Import
- [x] F06 — AI Coach

## Cycle 3 — Final Touches
- [x] F07 — Settings & Extras
- [x] F08 — Home Screen Widget

## Verification Summary
All features verified: project builds successfully (`xcodebuild` passed with 0 errors).
iPhone 16 Pro simulator, iOS 18.6, Xcode beta, SwiftUI, Swift 5.

## Cycle 4 — Bug Fixes & Enhancements (from 1-month usage feedback)
- [ ] F02-A — UI & Data Bugs (CRUD, sets, rest+/-, pinning, per-workout settings)
- [ ] F02-B — Learning Tab & Practice Type (new tab, practice workouts, warmup/break/wind-down)
- [ ] F03-A — Persistence & Live Activities (background, resume, partial save, lock screen timer)
- [ ] F03-B — In-Workout Controls & Media (rest preview, full media overlay, rest adjustment)
- [ ] F04-A — Streaks & Partial Logging (rest days, workout goals, partial logging)
- [ ] F05-A — Import, Export & Previews (import btn, files picker, photo preview, photo export fix)
- [ ] F06-A — Text Selection (hold to select AI chat text)
- [ ] F07-A — UI Polish (nav fade fix, toolbar transparency)

## Notes
- Existing codebase converted to this documentation system on 2026-07-04.
- All features (F01-F08) were built before documentation — documented retroactively.
- F02-A through F07-A are new sub-features from 1 month of user feedback (2026-07-04).
- server.py and start_server.command are companion files for F05 video import.
- .gitignore covers xcuserdata, DerivedData, .ipa, .DS_Store.
