# CYCLES.md — Time-Master
**Planned with user:** 2026-07-04, revised 2026-07-06

<!-- V0.1: Cycle 0 | V0.2: Cycle 1-3 | V1.0: Cycle 4-5 | V2.0: Cycle 6-7 -->

## Dependency Chain

```
F01 (Core Data Layer) ──┐
                         ├── F09 (File-Based Data Architecture)
F06 (AI Coach) ─────────┘
                              │
                    F09-A (TimeMasterCore)
                      FIRST — everything depends on it
                         │
              ┌──────────┴──────────┐
        F09-B (Knowledge)     F09-C (CLI Tool)
          └──────────┬──────────┘
                     │
              F09-D (AI Tool Calling)
                     │
              F09-E (Mac App)
              1:1 iOS clone — external AI bridge
                     │
         ┌───────────┼───────────┐
    F01-A (migrate)  F05-A-v2   F06-B (AI in chat)
```

---

## Cycle 0 — Documentation

## Cycle 0 — Documentation
- [x] Project scaffold (`projinit`)
- [x] genesis/ORIGINAL IDEA.md
- [x] genesis/INITIAL IDEA.md
- [x] Feature breakdown: F01 → F08 mapped
- [x] features/DOCKS.md index
- [x] All F01-F08 DOCKS.md files drafted

## Cycle 1 — Core Foundation
- [x] F01 — Core Data Layer
  - [x] Models: Workout, Section, WorkoutHistoryEntry, Exercise, ExerciseFolder, TrayItem
  - [x] Stores: WorkoutStore (UserDefaults), DatabaseStore (root + folders)
  - [x] Utilities: PhotoManager, Theme, KeychainHelper
  - [x] Verified: models compile, Codable round-trip, CRUD persists across launches
- [x] F02 — Workout Management
  - [x] WorkoutListView with ForEach + NavigationLink
  - [x] WorkoutDetailView with section list, reorder, add/edit/delete sections
  - [x] SectionEditorView: name, duration, sets, rest, media, AI naming
  - [x] Verified: create/edit/delete/reorder workouts + sections, photos save/load

## Cycle 2 — Timer, Analytics, Import
- [x] F03 — Timer & Player
  - [x] WorkoutPlayerView: warm-up picker, active section, rest view, completed
  - [x] Timer logic: tick, phase transitions, sets, inter-section rest
  - [x] Media: photo/video carousel, AVQueuePlayer looper, thumbnails
  - [x] TTS: AudioManager speaks section names, countdown, motivation
  - [x] Confetti on completion
  - [x] Verified: timer counts down, phases transition, media plays, TTS speaks

## Cycle 3 — AI, Import, Settings, Widget
- [x] F04 — History & Analytics
  - [x] HistoryView: list with delete, HistoryRow with date + duration
  - [x] AnalyticsView: type picker, weekly goal ring, StreakCard, ActivityHeatmap
  - [x] GoalsManager: per-type goal storage
  - [x] Verified: history persists, analytics display correct stats
- [x] F05 — Database Import
  - [x] ImportSheetView: video from camera roll + URL download
  - [x] BackupManager: export/import ZIP with manifest + media
  - [x] DatabaseView: root folders, exercises, notes, media thumbnails
  - [x] DatabaseSectionPickerView: pick exercise from DB to add to workout
  - [x] Verified: import/export works, backup ZIP contains all data
- [x] F06 — AI Coach
  - [x] AICoachView: chat UI, streaming, reply/copy/attach
  - [x] AIProvider: 25 providers across 7 groups, OpenAI-compatible API
  - [x] AIStore: conversation persistence
  - [x] ExerciseNamingService: AI-powered name suggestions from photos
  - [x] Verified: messages send/stream, provider switching, API key in Keychain
- [x] F07 — Settings & Extras
  - [x] SettingsView: backup, motivation, music, reminders, AI, server config
  - [x] MusicSettingsView: import/delete background music tracks
  - [x] MusicManager: AVQueuePlayer playback, per-workout track selection
  - [x] NotificationManager: daily pre/post-workout push notifications
  - [x] ServerSettingsView: companion server config for video import
  - [x] Verified: settings persist, music plays, notifications schedule
- [x] F08 — Home Screen Widget
  - [x] Widget extension: show last workout, total count, next due
  - [x] App Group sync via UserDefaults suite
  - [x] Verified: widget updates, deep link to workout detail

---

## Cycle 4 — Bug Fixes & Enhancements
**Built 2026-07-04 from 1 month of usage feedback**

- [x] F03-A — Persistence & Resume
  - [x] Detail: WorkoutResumeManager with auto-save every 5s (workout ID, section, time, phase)
  - [x] Detail: Resume prompt on app relaunch with elapsed time + section name
  - [x] Detail: Partial workout logging (>3min → history, <3min → discarded)
  - [x] Detail: isPartial + elapsedSeconds on WorkoutHistoryEntry
  - [x] Detail: beginBackgroundTask for ~3min background extension
  - [x] Verified: F03-A DOCKS.md checklist (auto-save, kill+relaunch, partial logging)
- [x] F03-B — In-Workout Controls & Media
  - [x] Detail: Rest preview — next exercise thumbnail at 50% opacity during section-rest
  - [x] Detail: Full-screen media overlay — tap exercise photo, timer continues in corner
  - [x] Detail: OverlayVideoPlayerView with play/pause/seek, tap/swipe to dismiss
  - [x] Detail: +15s/+30s rest adjustment buttons, max 120s cap, long-press context menu
  - [x] Verified: F03-B DOCKS.md checklist (preview, overlay, timer unaffected, rest buttons)
- [x] F04-A — Streaks & Partial Logging
  - [x] Detail: 28-day streak calendar removed — replaced by enhanced ActivityHeatmap
  - [x] Detail: ActivityHeatmap: 24 weeks, tappable cells → DayInfoSheet with workouts list
  - [x] Detail: Heatmap colors: green (workout), blue (rest), red (scheduled-missed), gray (no plan)
  - [x] Detail: Weekly goal config (3-7 days) in WorkoutStore, per-type goals via GoalsManager
  - [x] Detail: [Partial] badge in HistoryRow with elapsed time, counts toward analytics
  - [x] Verified: F04-A DOCKS.md checklist (calendar, rest toggle, goal config, partial badge)
- [x] F05-A — Import, Export & Previews
  - [x] Detail: Backup export only bundles referenced media (not all Photos/)
  - [x] Detail: collectDatabaseMediaFilenames for exercise/folder media
  - [x] Detail: DatabaseView exercise thumbnail tap → MediaPreviewSheet full-screen
  - [x] Detail: "Ungrouped" section header + badge for root-level exercises
  - [x] Detail: Import button in DatabaseView toolbar (ZIP import + merge)
  - [x] Verified: F05-A DOCKS.md checklist (export size, preview, ungrouped, import)
- [x] F06-A — Text Selection
  - [x] Detail: Hold to select partial text in AI chat, not just copy all
  - [x] Verified: text selection works, copy extracts selected portion only
- [x] F07-A — UI Polish
  - [x] Detail: Tab bar opacity fix, navigation fade fix, toolbar transparency
  - [x] Verified: UI renders correctly, no visual glitches

---

## Cycle 5 — Dynamic Types, Schedule & Analytics Rework
**Built 2026-07-05 to 2026-07-06 from user-driven requests**

### Data Model Revolution
- [x] WorkoutType: enum → dynamic struct (Identifiable, Codable with backward compat)
  - [x] Detail: Built-in types (7) with colorHex (Strength=orange, Stretch=green, etc.)
  - [x] Detail: Custom types stored in WorkoutStore.customWorkoutTypes (UserDefaults)
  - [x] Detail: All(custom:) helper for type pickers everywhere
  - [x] Detail: Codable migration: old "Strength" string → new {id, name, icon, colorHex}
  - [x] Verified: existing data migrates, custom types persist, all pickers show both
- [x] WorkoutTypesSettingsView (Settings → Workout Types)
  - [x] Detail: Built-in grid + custom grid, 2-column card layout
  - [x] Detail: TypeEditorSheet: name, icon grid (24 SF Symbols), IconColorPicker
  - [x] Detail: Preview card shows icon in selected color with name
  - [x] Detail: Tap card → TypeGoalSheet for weekly goal editing
  - [x] Verified: create custom type, pick icon+color, set goal, delete custom type
- [x] GoalsManager → shared between Settings and Analytics
  - [x] Detail: Inline goal setter card in Analytics (appears when no goal set)
  - [x] Detail: Tap number (1-7) → goal saved instantly, card disappears, ring appears
  - [x] Verified: goal set in Settings → reflected in Analytics, and vice versa

### Workout Editing Fixes
- [x] Section reorder via sectionIDs array
  - [x] Detail: @State sectionIDs: [UUID] for drag stability, synced to store on move
  - [x] Detail: ForEach(sectionIDs, id: \.self) → lookup by ID
  - [x] Detail: moveSections updates local array then store.updateWorkout
  - [x] Verified: drag to reorder works, order persists after reopen
- [x] WorkoutDetailView reads from store directly (no stale @State copy)
  - [x] Detail: workoutID: UUID + computed `var workout: Workout` from store
  - [x] Detail: Removed syncWorkout(), onReceive → always reads latest store value
  - [x] Verified: edits reflect immediately, reorders don't snap back
- [x] Prepare time per section (4s default)
  - [x] Detail: Section.prepareTime: Int (0-30s), stepper in SectionEditorView
  - [x] Detail: Default changed 5→4 in model init, Codable, and SectionEditor
  - [x] Verified: save/edit section, prepare time persists
- [x] Per-workout music fix
  - [x] Detail: MusicManager.togglePlayback() → explicit startPlayback(tracks: workout.musicTrackFilenames)
  - [x] Detail: Music button in player respects per-workout selection, not all tracks
  - [x] Verified: select specific tracks in Workout Settings, only those play

### Analytics Rework
- [x] Calendar page (tap Activity heatmap → full-screen)
  - [x] Detail: Year overview: 12 month rows with mini heatmap grids + stats
  - [x] Detail: Month detail: full calendar grid, weekday headers, day cells
  - [x] Detail: DayInfoSheet: date, workout count, total time, status badges, HistoryRow list
  - [x] Detail: Year nav: ←/→ arrows for year, month nav: ←/→ for month
  - [x] Detail: Toggle: toolbar button switches year overview ↔ month detail
  - [x] Verified: tap heatmap opens calendar, navigate months/years, tap day shows info
- [x] Heatmap colors
  - [x] Detail: Green (workout done, 3 intensity levels), Blue (rest day), Red (scheduled-missed), Gray (unscheduled)
  - [x] Detail: Legend only on calendar page, heatmap card minimal (just "Activity" + chevron)
  - [x] Verified: colors render correctly based on schedule, rest, workout data
- [x] Training schedule card (Weekly Schedule)
  - [x] Detail: Day picker (Mon-Sun), duration stepper (1-12 months)
  - [x] Detail: Drives isScheduledDay() → heatmap coloring
  - [x] Detail: Saved to UserDefaults, loaded on init
  - [x] Verified: select days → heatmap shows red for missed scheduled days
- [x] Vacation sheet (calendar page moon button)
  - [x] Detail: Start/end month date pickers, multi-type selection
  - [x] Detail: Marks all days in range as rest (blue) via restDays.insert
  - [x] Detail: Day-by-day iteration, saveRestDays() after
  - [x] Verified: set vacation range → all days blue in heatmap and calendar

### Database Enhancements
- [x] Workout type tag on ExerciseFolder
  - [x] Detail: ExerciseFolder.workoutType: WorkoutType? (Codable, optional)
  - [x] Detail: NewFolderSheet: type picker grid (None + all types)
  - [x] Detail: DatabaseStore.addRootFolder/addSubfolder accept workoutType
  - [x] Verified: create folder with type tag, persists in JSON
- [x] TypeSchedule model (for per-type workout schedules)
  - [x] Detail: TypeSchedule: folderID, type, daysOfWeek, startDate, durationMonths, weeklyGoal
  - [x] Detail: isActive computed from startDate + durationMonths
  - [x] Verified: model compiles, Codable round-trip

---

## Cycle 6 — File-Based Data Architecture (REV-01)
**DOCUMENTED 2026-07-06 — NOT BUILT**

### Revolution Document
- [x] genesis/REVOLUTION-rev-01-file-based-data.md (COLOSSAL)
  - [x] Detail: Why, What Changes, Migration Path, Affected Features, Architecture Decisions, Risk Assessment

### Feature Docs (all DOCUMENTED, zero code)
- [x] F09/DOCKS.md — main architecture: directory tree, schema.json, key rules
- [x] F09-A/DOCKS.md — TimeMasterCore
  - [x] Detail: shared Swift library, DatabaseManager, SchemaManager, MigrationManager
  - [x] Detail: Atomic writes, validation, search, AI safety (.trash/, approval gate, auto-backup)
- [x] F09-B/DOCKS.md — Knowledge Layer + AGENTS.md
  - [x] Detail: Knowledge/ folder, AGENTS.md bootstrap, skills/ directory, AI session startup
- [x] F09-C/DOCKS.md — CLI Tool (`timemaster-tool`)
  - [x] Detail: 12 sub-commands, JSON I/O, read-only mode, Claude/Cursor integration
- [x] F09-D/DOCKS.md — AI Tool Calling
  - [x] Detail: 10 tool schemas, function-calling loop, session context injection, streaming pause/resume
- [x] F09-E/DOCKS.md — Mac App
  - [x] Detail: native macOS target, 1:1 SwiftUI codebase, non-sandboxed, Finder-browsable, CLI + external AI handshake

### Build (pending)
- [x] F09-A — TimeMasterCore
  - [x] Detail: Create Swift Package, implement DatabaseManager + SchemaManager + MigrationManager
  - [x] Detail: Bootstrap directory structure on first launch
  - [x] Detail: Atomic writes with validation
  - [x] Detail: .trash/ soft-delete, approval gate for AI writes
  - [x] Verified: all F09-A DOCKS.md checklist items (25 tests, 0 failures, macOS arm64, 2026-07-06)
- [x] F09-B — Knowledge Layer
  - [x] Detail: Create Knowledge/ directory + AGENTS.md + skills/ at bootstrap
  - [x] Detail: AISystemPromptBuilder reads Knowledge/*.md into prompt prefix
  - [x] Verified: F09-B DOCKS.md checklist (36 tests, 0 failures, macOS arm64, 2026-07-06)
- [x] F09-C — CLI Tool
  - [x] Detail: Build timemaster-tool binary, all 12 sub-commands
  - [x] Detail: Install to /usr/local/bin, test from Terminal
  - [x] Verified: F09-C DOCKS.md checklist (49 tests, 0 failures, macOS arm64, 2026-07-06)
- [x] F09-D — AI Tool Calling
  - [x] Detail: ToolRouter routes calls → DatabaseManager
  - [x] Detail: Function-calling loop in AIStore, context injection
  - [x] Detail: Max 5 tool calls per message, approval gate for writes
  - [x] Detail: SessionContext builder in AISystemPromptBuilder
  - [x] Detail: Tool schema definitions in AIProvider (OpenAI + Anthropic)
  - [x] Detail: Tool call indicator UI in AICoachView
  - [x] Verified: F09-D DOCKS.md checklist (iOS build succeeds, 49 core tests pass, 2026-07-07)
- [x] F09-E — Mac App
  - [x] Detail: Add macOS target to Xcode project
  - [x] Detail: Platform-adaptive UI (#if os(macOS) where needed)
  - [x] Detail: Non-sandboxed ~/Documents/TimeMaster/ path
  - [x] Detail: Bundle timemaster-tool CLI with app
  - [x] Verified: F09-E DOCKS.md checklist (builds, 49 tests pass, 2026-07-07)

### Migration (after F09-A)
- [x] F01-A — Migrate models to file manifests
  - [x] Detail: MigrationManager.migrateFromUserDefaults() reads all 11 UserDefaults keys
  - [x] Detail: WorkoutStore + DatabaseStore load from DatabaseManager after migration
  - [x] Detail: TimeMasterApp triggers MigrationManager.migrateIfNeeded() in init()
  - [x] Detail: Migration marker (.migration_complete) prevents re-migration
  - [x] Detail: Backup JSON written to Backups/ before migration
  - [x] Verified: 14 MigrationTests pass + 49 existing tests pass, macOS arm64, 2026-07-09
- [ ] F05-A-v2 — Import writes to Exercises Database/
  - [ ] Detail: BackupManager.importBackup creates file-based manifests
  - [ ] Verified: import ZIP → creates correct folder structure
- [ ] F06-B — AI Tool Calling in Chat
  - [ ] Detail: AICoachView shows tool call progress, approval cards
  - [ ] Detail: Knowledge injection on session start
  - [ ] Verified: AI can search, create, and explain exercises via chat

---

## Cycle 7 — V2: Notion-Style Rework
**PLANNED from IDEA.md — no code written**

### Foundation
- [ ] F01-B — Unified Page Model
  - [ ] Detail: ExercisePage struct replaces ExerciseFolder + Exercise + TrayItem
  - [ ] Detail: Every page has cover image, markdown body, media, links, nested sub-pages
  - [ ] Detail: Unlimited nesting with parent/child relationships
- [ ] F05-B — Notion-Style Pages UI
  - [ ] Detail: Exercise page opens as rich view (not just edit form)
  - [ ] Detail: Inline video playback (YouTube, Instagram embeds)
  - [ ] Detail: Link attachments with previews

### Workout Builder
- [ ] F02-A-a — Database Browser + Workout Page
  - [ ] Detail: Browse exercises as cards/pages, drag-to-workout
- [ ] F02-A-b — Drag-to-Build + Sets
  - [ ] Detail: Drag exercise into workout, configure sets/reps inline
- [ ] F02-A-c — Bundle Section Mode
  - [ ] Detail: Group multiple exercises into one timed section
- [ ] F02-A-d — Player Page Popup
  - [ ] Detail: Tap image/title during workout → exercise page overlay with floating player controls

### Player & Analytics
- [ ] F03-C — Player Overlay
  - [ ] Detail: Floating controls bar (pause, skip, music) during exercise page view
- [ ] F04-B — Flame Streak + Per-Type Analytics
  - [ ] Detail: Animated fire icon for streak number
  - [ ] Detail: Per-type analytics breakdown in calendar page

### Extras
- [ ] F07-B — Notification Pipeline
  - [ ] Detail: Motivational, human-written push notifications
  - [ ] Detail: Scheduled notifications tied to training schedule
- [ ] F07-C — Workout Types & Schedules (extended)
  - [ ] Detail: Per-type schedule UI (not just global)
  - [ ] Detail: Schedule templates, recurring patterns
- [ ] Mac App
  - [ ] Detail: Native macOS build using same TimeMasterCore
  - [ ] Detail: Finder integration for Exercises Database/ folder

---

## Notes
- Codebase converted to this system: 2026-07-04.
- Cycles 1-3: original F01-F08 features (documented retroactively from working code).
- Cycle 4: user feedback from 1 month of use (built 2026-07-04).
- Cycle 5: dynamic types, analytics rework, vacation, prepare time, fixes (built 2026-07-05 to 2026-07-06).
- Cycle 6: Revolution REV-01 — file-based data architecture (DOCUMENTED 2026-07-06, NOT BUILT).
- Cycle 7: V2 Notion-style rework from IDEA.md (PLANNED, no code written).
- server.py and start_server.command are F05 companion files.
- .gitignore covers xcuserdata, DerivedData, .ipa, .DS_Store.
