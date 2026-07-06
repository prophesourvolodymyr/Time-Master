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

## Verification Summary (Cycles 0-3)
All features verified: project builds successfully (`xcodebuild` passed with 0 errors).
iPhone 16 Pro simulator, iOS 18.6, Xcode beta, SwiftUI, Swift 5.

---

## Cycle 4 — Bug Fixes & Enhancements (1-month usage feedback) — COMPLETE
- [x] F03-A — Persistence & Resume (background save every 5s, resume prompt, partial logging)
- [x] F03-B — In-Workout Controls (rest preview, full media overlay, +15s/+30s buttons, long-press picker)
- [x] F04-A — Streaks & Partial Logging (streak calendar removed, activity heatmap enhanced, rest days)
- [x] F05-A — Import, Export & Previews (referenced-only export, DB photo preview, ungrouped items)
- [x] F06-A — Text Selection (hold to select AI chat text)
- [x] F07-A — UI Polish (nav fade fix, toolbar transparency)

---

## Cycle 5 — Dynamic Types, Schedule & Analytics Rework — COMPLETE
(Ad-hoc user-driven features built 2026-07-04 to 2026-07-06)

### Data Model
- [x] WorkoutType enum → dynamic struct (Codable backward compat, custom types with icon + color)
- [x] WorkoutTypesSettingsView — create/edit/delete custom types, icon color picker
- [x] Type goals: GoalsManager shared between Settings and Analytics, inline goal setter

### Workout Editing
- [x] Section reorder fix — sectionIDs array for drag stability
- [x] Prepare time per section (4s default, stepper in SectionEditorView)
- [x] Per-workout music fix — toggle plays selected tracks only
- [x] WorkoutDetailView fix — reads from store directly, no stale state

### Analytics
- [x] Calendar page — year overview with mini grids, month detail, day info sheet
- [x] Heatmap colors: green (workout), blue (rest), red (scheduled-missed), gray (unscheduled)
- [x] Training schedule card — pick days + duration, drives heatmap coloring
- [x] Vacation sheet — multi-month range, multi-type selection, blue days
- [x] StreakCalendarView removed, ActivityHeatmap enhanced (24 weeks, tappable)
- [x] Custom types appear in analytics filter

### Database
- [x] Workout type tag on folders (NewFolderSheet picker)
- [x] Ungrouped section with badge in DatabaseView

---

## Cycle 6 — File-Based Data Architecture (REV-01) — DOCUMENTED, NOT BUILT

### Planning
- [x] Revolution Document: `genesis/REVOLUTION-rev-01-file-based-data.md` (COLOSSAL)
- [x] F09/DOCKS.md — main architecture doc
- [x] F09-A/DOCKS.md — TimeMasterCore (shared Swift library, DatabaseManager, AI safety)
- [x] F09-B/DOCKS.md — Knowledge Layer (AGENTS.md, skills/, AI session startup)
- [x] F09-C/DOCKS.md — CLI Tool (`timemaster-tool`)
- [x] F09-D/DOCKS.md — AI Tool Calling (function-calling loop, 10 tool schemas)

### Build (pending)
- [ ] F09-A — TimeMasterCore (shared library + migration tool)
- [ ] F09-B — Knowledge Layer + AGENTS.md bootstrap
- [ ] F09-C — CLI tool binary
- [ ] F09-D — AI tool calling loop
- [ ] F01-A — Migrate models to file manifests
- [ ] F05-A-v2 — Import writes to Exercises Database/
- [ ] F06-B — AI tool-calling in chat (depends on F09-D)

---

## Cycle 7 — V2: Notion-Style Rework (from IDEA.md) — PLANNED

### Foundation
- [ ] F01-B — Unified Page Model (ExercisePage replaces Folder/Exercise/TrayItem)
- [ ] F05-B — Notion-Style Pages (covers, links, YouTube embedding, unlimited nesting UI)

### Workout Builder
- [ ] F02-A-a — Database Browser + Workout Page
- [ ] F02-A-b — Drag-to-Build + Sets
- [ ] F02-A-c — Bundle Section Mode
- [ ] F02-A-d — Player Page Popup (exercise detail overlay during workout)

### Player & Analytics
- [ ] F03-C — Player Overlay (floating controls bar)
- [ ] F04-B — Flame Streak + Per-Type Analytics

### Extras
- [ ] F07-B — Notification Pipeline (motivational, humane, scheduled)
- [ ] F07-C — Workout Types & Schedules (extended from Cycle 5)
- [ ] Mac app — native macOS build, same TimeMasterCore, Finder integration

---

## Notes
- Codebase converted to this system: 2026-07-04.
- Cycles 1-3: original F01-F08 features (documented retroactively).
- Cycle 4: user feedback from 1 month of use (built 2026-07-04).
- Cycle 5: dynamic types, analytics rework, vacation, prepare time (built 2026-07-04 to 2026-07-06).
- Cycle 6: Revolution REV-01 — file-based data architecture (DOCUMENTED 2026-07-06, NOT BUILT).
- Cycle 7: V2 Notion-style rework from IDEA.md (PLANNED, no code written).
- server.py and start_server.command are F05 companion files.
- .gitignore covers xcuserdata, DerivedData, .ipa, .DS_Store.
