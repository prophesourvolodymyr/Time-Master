# CYCLES.md — Time-Master
**Planned with user:** 2026-07-04, revised 2026-07-06, 2026-07-13, and 2026-08-20

<!-- V0.1: Cycle 0 | V0.2: Cycle 1-3 | V1.0: Cycle 4-5 | V2.0: Cycle 6-7 | V2.0+: Cycle 8-9 | V0.3: Cycle 10 -->

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

Cycle 11 Outdoor Data ──┐
F09 File Storage ───────┼── F28 (Better Maps and Route Recording)
F24 Navigation ─────────┤
F25 Music ──────────────┤
F26 Liquid Glass ───────┤
F27 Home ───────────────┘

Existing Ranked accounts + trusted Rust service ──┐
F24 navigation + shared native styles ────────────┼── F29 (Physique Duels)
Validated image judge + consent + moderation ─────┘
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
- [x] F05-A-v2 — Import writes to Exercises Database/
  - [x] Detail: BackupManager.importBackup creates file-based manifests
  - [x] Detail: WorkoutStore.reload() reads from file system post-migration
  - [x] Detail: ImportSummary returned with counts (exercises, workouts, history, media)
  - [x] Verified: macOS arm64 build succeeds, all 63 core tests pass, 2026-07-11
- [x] F06-B — AI Tool Calling in Chat
  - [x] Detail: AICoachView shows tool call progress, approval cards
  - [x] Detail: Knowledge injection on session start
  - [x] Detail: Write approval gate with continuation-based UI
  - [x] Detail: Database context injected into system prompt via AISystemPromptBuilder
  - [x] Detail: DatabaseStore reload after AI creates exercises
  - [x] Detail: Tool schemas enhanced (restAfter, mediaFilenames, restBetweenSections, get_stats)
  - [x] Verified: macOS arm64 build succeeds, F06-B DOCKS.md checklist, 2026-07-11

---

## Cycle 7 — V2: Notion-Style Rework
**Phase 2 code completed 2026-07-11 — models, CRUD, migration, schema done**

### Foundation
- [x] F01-B — Unified Page Model
  - [x] Detail: DOCKS.md written (comprehensive spec: model, states, animations, migration, verification)
  - [x] Detail: ExercisePageManifest + ExercisePage + PageTreeBuilder models implemented
  - [x] Detail: DatabaseManager page CRUD + walkPageTree + searchPages + movePage
  - [x] Detail: DatabaseStore rewritten as flat page store with V1 backward compat
  - [x] Detail: Migration from ExerciseManifest/ExerciseFolder → ExercisePageManifest
  - [x] Detail: Schema updated with page object + 8 page tools
  - [x] Detail: Verified: macOS arm64 build succeeds, 63/63 tests pass, no regressions (2026-07-11)
  - [x] Detail: DatabaseStore UI integration, ExercisePageDetailView, page creation UI completed
  - [x] Detail: UI integration: DatabaseView V2 adaptation, ExercisePageDetailView, PageCreationSheet, PageMediaGallery, PageLinkPreview, page reorder/move (2026-07-11)
  - [x] Verified: macOS arm64 build succeeds, 63/63 tests pass, V2 page tree renders, page creation/edit/delete works, media viewer + link previews implemented (2026-07-11); iPhone 16 Pro simulator migration created `.migration_v2_pages_complete` and V2 page manifests with `guide.md` files (iOS 18.6, 2026-07-13)
- [x] F05-B — Notion-Style Pages UI
  - [x] Detail: Exercise page opens as rich view (not just edit form)
  - [x] Detail: Inline video playback (YouTube, Instagram embeds) — VideoEmbedCard with rich media cards, YouTube thumbnail via oembed, platform detection, play overlays
  - [x] Detail: Link attachments with previews — VideoEmbedListView replaces PageLinkList, AsyncImage thumbnails
  - [x] Detail: Cover image upload from detail view — PhotosPicker, save to cover.{ext}, manifest update
  - [x] Detail: Media upload to page — PhotosPicker, save to media/ subdir, preview grid with delete, max 20
  - [x] Detail: Edit-to-Guide integration — loadGuideContent() reads full guide.md from disk, reloads on edit dismiss
  - [x] Detail: Page reorder persistence — root pages persist via persistRootPageOrder(), DatabaseManager.reorderChildren()
  - [x] Detail: Breadcrumb navigation — tappable NavigationLinks, navigate back to ancestor pages
  - [x] Detail: New VideoEmbedCard.swift + DatabaseManager methods (reorderChildren, uploadCoverImage, uploadMediaToPage, readGuideContent, removeMediaFromPage)
  - [x] Detail: Page-creation parity repair — every page can add children; root/child/grandchild pages use the same cover and media editor; image/video imports preserve their file types and reload after persistence (2026-07-13)
  - [x] Detail: Regression test verifies a root → child → grandchild tree with independent cover, photo, and video storage paths (2026-07-13)
  - [x] Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions (2026-07-11)

### Workout Builder
- [x] F02-A-a — Database Browser + Workout Page
  - [x] Detail: Browse exercises as cards/pages, drag-to-workout
  - [x] Detail: Grid/list toggle, sort by name/date/type, filter chips (All/Containers/Leaves/per-type)
  - [x] Detail: Search bar with real-time filtering by title/content/tags
  - [x] Detail: Context menu on cards (Add to Workout, Edit, Add Child, Duplicate, Delete)
  - [x] Detail: WorkoutPickerSheet — lists workouts, pre-fills section config from page workoutConfig
  - [x] Detail: "Add to Workout" button in page detail view
  - [x] Detail: DatabaseStore.duplicatePage() — copies page with cover + media
  - [x] Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions (2026-07-11)
- [x] F02-A-b — Drag-to-Build + Sets
  - [x] Detail: Drag exercise into workout, configure sets/reps inline
  - [x] Detail: DatabasePageBrowserSheet — embedded V2 browser in workout context (grid/list, search/filter/sort)
  - [x] Detail: Inline SectionConfigCard with editable Dur/Sets/Reps/Rest/Btwn steppers, Confirm/Cancel
  - [x] Detail: repCount field on Section + WorkoutSectionManifest, displayed during playback
  - [x] Detail: Reps stepper in WorkoutPickerSheet + DatabasePageBrowserSheet
  - [x] Detail: Drag-to-reorder sections with drag handles in WorkoutDetailView
  - [x] Verified: macOS arm64 build succeeds, 63/63 core tests pass, 2026-07-11
- [x] F02-A-c — Bundle Section Mode
  - [x] Detail: Group multiple exercises into one timed section via bundle toggle in browser sheet
  - [x] Detail: Bundle creates ONE section named after first page with all page names in subtitle
  - [x] Detail: Total sets sums across all bundled pages' workoutConfig
  - [x] Verified: macOS arm64 build succeeds, 63/63 core tests pass, 2026-07-11
- [x] F02-A-d — Player Page Popup
  - [x] Detail: Tap exercise name (with book.pages icon) during workout → full ExercisePage overlay
  - [x] Detail: ExercisePageOverlay shows cover image, markdown guide, media grid, YouTube/Instagram embeds, tags, workout config badges
  - [x] Detail: FloatingControlsBar — semi-transparent pill with countdown/elapsed time, pause/stop/skip buttons, section progress, dismiss chevron
  - [x] Detail: pageID field added to Section model (Codable, optional UUID) for page linking
  - [x] Detail: WorkoutPickerSheet passes page.id when creating sections from pages
  - [x] Detail: WorkoutSectionManifest.exerciseID mapped to Section.pageID during conversion
  - [x] Detail: DatabaseStore injected into WorkoutPlayerView via all sheet presentations
  - [x] Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions (2026-07-11)

### Player & Analytics
- [x] F03-C — Player Overlay
  - [x] Detail: Floating controls bar (pause, stop, skip, timer, section progress, dismiss) during exercise page view, delivered via F02-A-d (2026-07-11)
  - [x] Detail: Music control added to FloatingControlsBar; respects the workout playlist (macOS build, 2026-07-13)
- [x] F04-B — Flame Streak + Per-Type Analytics
  - [x] Detail: Animated fire icon for streak number
  - [x] Detail: Per-type analytics breakdown with weekly progress and adherence

### Extras
- [x] F07-B — Notification Pipeline
  - [x] Detail: Motivational, human-written push notifications
  - [x] Detail: Scheduled notifications tied to per-type training schedules and rest days
- [x] F07-C — Workout Types & Schedules (extended)
  - [x] Detail: Per-type schedule UI (not just global)
  - [x] Detail: Recurring weekly patterns with dated schedule windows
- [x] Mac App
  - [x] Detail: Native macOS build using same TimeMasterCore
  - [x] Detail: Finder integration for Exercises Database/ folder
  - [x] Verified: Debug macOS build succeeded, launched from `/private/tmp/TimeMasterDerived/Build/Products/Debug/TimeMaster-macOS.app`; 64 TimeMasterCore tests passed, arm64, 2026-07-13

---

## Cycle 8 — Mac Readiness & Daily Flow
**Added 2026-07-13 from user request**

- [x] F10 — Agent Settings Control
  - [x] Detail: AI can read the user-safe settings snapshot
  - [x] Detail: AI proposes and applies supported setting changes only after explicit in-chat approval
  - [x] Verified: tool schemas, approval gate, validation, and persistence compile in the launched macOS build; 64 core tests pass, 2026-07-13
- [ ] F11 — Resilient Background Timer
  - [x] Detail: Persist a timestamped timer checkpoint whenever the app backgrounds or is interrupted
  - [x] Detail: Reconcile elapsed wall-clock time on return, even on devices without Live Activities
  - [x] Detail: Request the longest permitted iOS background task window without claiming indefinite execution
  - [ ] Verified: timer survives background/foreground and relaunch with correct elapsed state (requires a timed workout run on a device)
- [x] F12 — Home Dashboard & Quick Start
  - [x] Detail: Daily home dashboard with quick analytics, next workout, and recovery/training context
  - [x] Detail: Quick start starts a selected or suggested workout without navigating through its detail screen
  - [x] Detail: Empty state guides a new user to create a workout or use the exercise database
  - [x] Verified: Home is the initial macOS destination in the successfully launched native Debug build; 64 core tests pass, 2026-07-13

---

## Cycle 9 — V2 Workout Database Completion
**Built 2026-07-13 from the workout-builder and nested-page defects**

- [x] F02-A — Page-backed workout creation and playback
  - [x] Detail: Workout sections now persist `SectionMode` and ordered `SetSlot` records, with backward-compatible decoding of legacy scalar sections
  - [x] Detail: Builder browser reads `DatabaseStore.allPagesFlat`, so root, child, and arbitrarily deep pages are selectable; legacy folder/exercise picker is no longer used for new sections
  - [x] Detail: New sections retain the selected page ID; Add Set, Add Drop/Add Item, rest-exercise linking, slot reorder, and slot removal all write through `WorkoutStore` to the file database
  - [x] Detail: WorkoutStore creates/updates/deletes file-based workout manifests after migration and keeps widget/UserDefaults mirrors in sync
  - [x] Detail: Timed playback uses per-slot durations/rests; bundle playback is self-paced with next/previous swipe navigation and page overlay access
  - [x] Detail: Rest pages can be assigned per slot and opened directly from the rest screen
  - [x] Detail: Browser quick preview shows cover fallback, media count, links, tags, guide summary, and full media gallery; containers are visible but cannot be added as workout sections
  - [x] Detail: Expanded builder sections expose inline duration/reps/rest controls, passive-rest clearing, and drag reorder for slots and selected bundle items
  - [x] Detail: Bundle player supports inline media preview, full page opening, next-exercise context, and mid-workout reorder persistence
  - [x] Verified: 67 TimeMasterCore tests pass (including nested slot/bundle manifest round-trip); macOS arm64 Debug build succeeds; iOS `TimeMaster` simulator Debug build succeeds; installed/launched on iPhone 16 Pro Simulator, iOS 18.6, bundle `com.vovas.TimeMaster`; screenshot captured 2026-07-13

---

# V0.3 — Cleanup & Real-World Stability

## Cycle 10 — Bug Fixes & Real-World Polish
**Planned with user: 2026-07-13 from `genesis/ISSUES.md` after Cycle 9 build**
**Goal: clean polished app — fixes the freezing, the monolithic database model, the old/empty editor picker, the macOS visual glitches, and turns the Home dashboard from a "latest workout" tile into a real today-only schedule board.**

### Phase 0 — Stability (must land first)
- [ ] F13 — Stability & Freeze Investigation
  - [ ] F13-A — Reproduce freeze across home → workout → player; home → database → page detail; settings open/close; rapid tab switches
  - [ ] F13-B — Move main-thread file I/O (cover image, guide.md, media thumbnails) to background queues with cached published values
  - [x] F13-C — Debounce / coalesce `DatabaseStore.reload()` storms after sheet dismiss
  - [x] F13-D — Audit `PreferenceKey` scroll-offset usage and remove frame-by-frame re-renders
  - [ ] F13-E — Audit `Timer` + `AVQueuePlayer` + `AVPlayerLooper` retain cycles in player + media carousel
  - [ ] F13-F — Hoist any recreated `@StateObject` to a long-living owner
  - [ ] Verified: 30s idle + 5-sheet open/close sequence + two phase transitions + 20 rapid tab switches with no main-thread stall; macOS + iOS arm64 builds succeed; core tests pass

### Phase 1 — Database hierarchy + editor picker (parallelizable later features depend on this)
 - [x] F14 — Database Hierarchy Model (root container vs leaf exercise)
   - [x] F14-A — Add `PageKind` enum (`.container` / `.leaf`) to `ExercisePageManifest`; legacy fallback decoding
   - [x] F14-B — Split `PageCreationSheet` into container form (cover, NO duration/sets/media) and leaf form (NO cover, duration + sets + reps + rest + media + markdown + links)
   - [x] F14-C — Leaf cover fallback: `ExercisePage.coverImageURL` returns first `mediaFilenames` item when no explicit cover
   - [x] F14-D — Detail view hides workout config badge and "Add to Workout" button on container pages
   - [x] F14-E — Container-of-container creation works to unlimited depth (`Add Child Page` on container)
   - [x] F14-F — `schema.json` + `ToolRouter` expose `create_container_page` and `create_exercise_page` with per-kind field validation; rejects `duration`/`sets` on container or `coverImageFilename` on leaf
   - [x] F14-G — Migration: split any existing malformed container pages that have `duration`/`sets` into a container + child exercise
   - [x] F14-H — Root containers own workout type; nested containers and leaves inherit it and cannot override it
   - [x] F14-I — Remove legacy tags and clean cached page manifests/UserDefaults database snapshots
   - [x] Verified: hierarchy tests pass, cached manifests contain no tags or container timing, macOS build succeeds; human verification remains required

- [ ] F23 — Editor Database Picker Fix (old/empty DB issue)
  - [x] F23-A — Replace every "Add exercise to workout" sheet with `DatabasePageBrowserSheet` (NOT legacy `DatabaseSectionPickerView`); audit + remove `DatabaseSectionPickerView` from production callers
  - [x] F23-B — `DatabaseStore.reload()` runs immediately before opening the browser sheet
  - [ ] F23-C — `WorkoutPickerSheet` writes a new page-backed section to the chosen workout via `WorkoutStore.updateWorkout` → `DatabaseManager` manifest write
  - [ ] F23-D — `WorkoutDetailView.handlePageSelection` stamps `Section.pageID = page.id` and persists
  - [ ] Verified: workout editor never shows the old V1 folder picker; freshly-imported DB pages immediately selectable in the editor; section persists across re-open; macOS + iOS builds succeed; core tests pass



### Phase 1A — Database page creation and media polish
- [x] Allow root exercise pages without a container
- [x] Pin create actions and persist full local drafts
- [x] Apply orange creation form accents and disabled states
- [x] Replace link textarea with previewable add-below rows
- [x] Support manual and database-backed drop sets
- [x] Rename rest options dynamically, including Big Rest
- [x] Make ordered media the shared cover source and remove page icons
- [x] Render markdown live with a draggable editor height
- [x] Mark required and optional creation fields clearly
- [x] Give creation and edit controls orange button bases
- [x] Show large horizontal media thumbnails in page views
- [x] Style database corner controls with shared bases and orange accents
- [x] Exercise Database Fixture & Validation
  - [x] Detail: Seeded 52 source video clips across Boxing, Core & Wrestling, Flexibility, Gymnastics, and Kickboxing with generated cover frames, guides, durations, rests, sets, and SF Symbol icons
  - [x] Detail: Added parent links and explicit page kinds/workout types to the existing hierarchy; removed the stale accidental test page with a recoverable backup
  - [x] Detail: Updated `SchemaManager.validateAll()` to validate page manifests while retaining legacy exercise fallback; string-backed page enums are accepted by schema validation
  - [x] Verified: 88 page manifests decode through `DatabaseManager.walkPageTree`, 52 video references resolve, and CLI validation reports `valid: true`

### Phase 1B — Typed pages and skills boards
- [x] Model Exercise, Skill, and Tutorial as page types; skills and tutorials keep attachments, notes, links, child pages, and linked page references without workout timing
- [x] Add container-level Exercises and Skills tabs; double-tap opens each category as a full page
- [x] Add Not Started, Learning, and Completed skill views plus a horizontally scrollable board with custom sections and drag reordering
- [x] Allow skills and tutorials to be added to workouts while keeping containers out of workout sections
- [x] Remove the global Skills mode and title counts; skills are created and organized inside containers
- [x] Verified: 94 TimeMasterCore tests pass and the iOS simulator Debug app installs and launches; human verification remains required
- [ ] Repair the database header with a fixed scroll viewport and one continuously morphing title/action group
- [ ] Keep type filters pinned, center compact action icons, and preserve scrolling for short result sets
- [ ] Build and exercise database collapse, reversal, action menus, and detail navigation in the simulator; hand off for human review

### Phase 2 — V2 Workout Management + V2 Player (paired)
- [ ] F15 — V2 Workout Management Rework
- [x] F15-A — V2 `WorkoutListView` card grid with page-backed cover thumbnails, today-only filter (consumes F20), scheduled-time badges, empty state
- [x] F15-B — V2 `WorkoutDetailView` single-pane editor: section list with inline expandable slot editor (Dur/Sets/Reps/Rest/Btwn/Prep), Add Set / Add Drop / Set Rest Exercise actions inline, rest separators
    - [x] Detail: Centralized leaf-page and bundle import builds local slots with indexed drop templates and an inheritable per-set preparation default
    - [x] Detail: Builder preparation, work, drop, rest, and rest-content rows each support a visible destructive delete action and trailing swipe deletion with immediate manifest persistence; deleting preparation sets that slot's override to zero
    - [x] Detail: Add-to-workout now opens a shared type chooser on iOS and macOS; Bundle uses multi-select browser mode, saved Workout uses a picker with a centered empty-state create prompt, and Bike and Run & Walk create outdoor sections
    - [x] Detail: New page and bundle imports expose duration, sets, reps, rest, between-set rest, and preparation controls, and newly created workouts route straight to their detail builder
  - [x] Detail: Builder rows retain visible threaded hierarchy rails and category-specific set/drop/rest colors on iOS and macOS
  - [ ] F15-C — `WorkoutStore.updateWorkout` writes ONLY via `DatabaseManager` manifest; remove any UserDefaults-only write path
  - [ ] F15-D — Add-to-Workout from database leaf page → new section lands at end of picked workout and persists
  - [x] F15-E — Drag-to-reorder sections persists across launches
  - [ ] F15-F — macOS sidebar → detail three-pane flow opens without modal sheet for normal edits
  - [ ] Verified: create, add-first-exercise, edit inline, reorder, add-from-database, delete all persist; macOS sidebar linkage works; macOS + iOS builds succeed; core tests pass

- [ ] F16 — V2 Player Rework
  - [ ] F16-A — Extract `WorkoutPlayerEngine` (ObservableObject owning phase, sectionIndex, slotIndex, elapsed, timeRemaining, musicTracks)
  - [ ] F16-B — `WorkoutPlayerView` becomes pure render of engine state
  - [ ] F16-C — Page-backed slot resolving (cover, guide preview, media carousel) with legacy-slot fallback
  - [ ] F16-D — Background-safe checkpoints on iOS `.didEnterBackground` and on macOS `windowDidResignKey`
    - [x] Detail: Resume checkpoints preserve the same pending section and set during the `prepare` phase, including elapsed-time reconciliation
  - [ ] F16-E — `ExercisePageOverlay` + `FloatingControlsBar` open with smooth transition; never blocks timer; dismisses cleanly
  - [ ] F16-F — Skip-section + skip-rest always land on deterministic next state
    - [x] Detail: Preparation runs before every timed set and bundle item; skip routes deterministically into work or the self-paced item
  - [ ] F16-G — macOS player presented as full-window modal (no half-clipped smear across sidebar)
  - [ ] Verified: warmUp → active → setRest → active → sectionRest → next active → completed flow without missed ticks; page overlay opens/closes cleanly; macOS + iOS builds succeed; core tests pass

### Phase 3 — Home dashboard, scheduling, settings UX (parallelizable)
- [ ] F22 — Per-Type Time-of-Day Schedule
  - [ ] F22-A — Extend `TypeSchedule` with `startTime: TimeOfDay?` and `durationMinutes: Int?`
  - [ ] F22-B — `WorkoutTypesSettingsView` adds Start Time picker + Duration stepper; "9:00 – 9:30" hint (no extra subtitle per minimalist style)
  - [ ] F22-C — Persist across launches; load on app start
  - [ ] Verified: per-type time shows in settings, persists, drives home-dashboard times; macOS + iOS builds succeed

- [ ] F20 — Scheduled-Today Home Widget & Missed-Red Indicator
  - [ ] F20-A — `ScheduledWorkout` model: workout, scheduledStart, scheduledFinish, status
  - [ ] F20-B — `WorkoutStore.scheduledWorkouts(for:)` returns today's scheduled workouts ordered by start time
  - [ ] F20-C — Home dashboard "Today" section: prominent Quick Start card (first pending) + compact today list with start times + status chip
  - [ ] F20-D — Missed status when `now > scheduledStart` AND not completed; missed entry sorts to bottom of today list with red chip
  - [ ] F20-E — Skip / Start Now actions on missed entries
  - [ ] F20-F — iOS widget mirrors first-scheduled + missed-red
  - [ ] F20-G — 60s dashboard refresh timer; refresh on `WorkoutStore` change
  - [ ] Verified: today-only list renders with start times; missed entries drop and turn red; widget mirrors; macOS + iOS builds succeed; core tests pass

- [ ] F21 — Home Quick Settings Access
  - [ ] F21-A — Add gear toolbar item to `HomeDashboardView`; opens `SettingsView` sheet
  - [ ] F21-B — Settings sheet uses the safe dismiss path from F18 on macOS
  - [ ] Verified: gear visible on Home (iOS + macOS); opens settings sheet; closes without crash; macOS + iOS builds succeed

### Phase 4 — Music + UI minimalist cleanup (parallelizable, polish)
- [ ] F19 — Music Behavior (general upload + sequential default)
  - [x] F19-A — `MusicManager.startPlayback(tracks:)` builds `AVQueuePlayer` queue with `actionAtEnd = .advanceToNextMedia`; queue-level loop after last track (NOT per-track loop)
  - [x] F19-B — `jumpToTrack(i)` rebuilds queue from index `i` and continues to end → loops to track 0
  - [x] F19-C — Per-workout Repeat-One toggle (default OFF) wraps current track in `AVPlayerLooper`; toggle off restores queue
  - [x] F19-D-v2 — Import video files from Music Settings and convert them to headless MP3 with SwiftMP3
  - [x] F19-E-v2 — Explicit whole-library vs specific per-workout playlist selection persists in `WorkoutManifest`
  - [ ] F19-D — `FloatingControlsBar` playlist popover + Repeat-One button
  - [ ] F19-E — Settings music library stays global; remove any per-workout upload hint
  - [ ] Verified: tracks advance sequentially; mid-workout jump continues from there; Repeat-One loops current; pause/resume works; macOS + iOS builds succeed

- [ ] F18 — macOS Polish (window clip, box artifacts, settings crash)
  - [x] F18-A — Sidebar background fills full column with `Theme.background.ignoresSafeArea()` (no color clip)
  - [ ] F18-B — Remove `GroupBox`/bordered containers around navigation links in `AnalyticsView`, `WorkoutPlayerView`, etc.
  - [x] F18-C — Settings sheet safe dismiss on macOS (⌘W + cancel); no crash; sheet does not overlap title strip
  - [ ] F18-D — iOS layout unchanged after macOS fixes
  - [ ] Verified: sidebar background full-bleed; no border boxes behind navigation links; settings opens/closes cleanly on macOS; iOS unchanged; macOS + iOS builds succeed; core tests pass

- [ ] F17 — Minimalist Text Cleanup
  - [ ] F17-A — Audit every view for subtitle/explanatory text; classify keep / shorten / remove
  - [ ] F17-B — Home dashboard: drop "Your day is still open" / "Move how you feel" subtitle; keep greeting + one short chip
  - [ ] F17-C — DatabaseView "Tap + to add a folder, note, or exercise." removed; toolbar "+" alone
  - [ ] F17-D — Page detail "This page is empty. Tap Edit to add a guide, media, links, and more." removed
  - [ ] F17-E — `SettingsView` per-row subtitles removed; keep accessibility labels for VoiceOver
  - [ ] F17-F — WorkoutListView empty subtitle removed; "Create Workout" CTA only
  - [ ] F17-G — Empty-state paragraphs trimmed to ≤1 short sentence
  - [ ] F17-H — Record minimalist-text rule in `STYLES.md`
  - [ ] Verified: no explanatory subtitle line on Home; settings rows title-only; voice-over still speaks descriptive labels; macOS + iOS builds succeed

---

## Cycle 11 — Outdoor Activity Tracking
- [x] Outdoor core model and file-backed Activities persistence
  - [x] Run & Walk and Bike manifests, route JSONL, pause intervals, laps, and recovery state
  - [x] GPX 1.1 and CSV export services
  - [x] Core persistence, malformed-line, schema, and export tests
- [x] iOS outdoor recorder
  - [x] Stopped map entry, Start-time permission request, background location configuration
  - [x] Manual pause, 20-second auto-pause/resume thresholds, laps, target cue, explicit Finish
  - [x] Save/Discard summary with route map and GPX/CSV sharing
- [x] App integration
  - [x] Home Run & Walk / Workout / Bike action row
  - [x] Workouts + outdoor starts, Profile viewer, merged History, Analytics outdoor summary/heatmap
  - [x] Full backup/import of outdoor manifests and route JSONL with duplicate skipping
  - [x] macOS viewer-only Profile and no recorder controls
  - [x] Verified: core tests, macOS build, iOS Simulator build
- [x] MapLibre route planning extension
  - [x] MapLibre renderer replaces MapKit for live, summary, and Profile route maps
  - [x] Flat 2D Liberty street style with extrusion layers removed, deep zoom enabled, and one-time location centering without camera lock
  - [x] Offline tile packs, metadata, settings entry point, and storage fallback
  - [x] PlannedRoute JSON persistence, schema compatibility, route picker, dual-layer rendering
  - [x] Basic closest-point route snap with progress and off-route status
  - [x] Planned-route recovery, summaries, exports, backup/import, and iOS build verification

## Cycle 12 — Slot Navigation
- [x] F24 — Native iOS slot navigation
  - [x] F24-A — Replace iOS TabView bar with draggable slot reel over real TimeMaster pages
  - [x] F24-B — Align emoji positions to the same fixed arc geometry used by the visible nav surface
  - [x] F24-C — Remove red tint from the slot navigation surface and keep page-owned colors intact
  - [x] F24-D — Add page swipes, projected snap, edge rubber-band, accessibility actions, and Reduce Motion behavior
  - [x] F24-E - Restore first-version emoji anchors while retaining drag expansion; replace the full-band surface with an opaque-enough neutral glass arc and soft depth shadow
  - [x] F24-F - Extend the filled arc path through the measured iOS bottom safe-area inset without a fade or extra padding; preserve resting anchors and neutral glass behavior
  - [x] F24-G - Keep every expanded drag-state slot above the glass arc with a minimum positive z-index
- [x] F24-H - Use the same bottom slot reel on macOS with a taller arc and keyboard arrows / `1`–`9` destination shortcuts
  - [x] macOS-only bar height and keyboard focus path leave the iOS 126-point layout unchanged
  - [x] macOS settings presentation and native-glass availability fall back to supported sheet/material APIs
- [x] F24-I - Lower the iOS arc crest, enlarge slot emojis and labels slightly, and add the neutral gradient, inner glow, and shared-curve top outline
- [x] F24-J - Use page-specific slot emojis, keep Home centered on initial mobile/iOS state, and preserve right/left directional page transitions
- [x] F24-K - Put AI Coach and Profile left of centered Home, keep semantic destination IDs stable for macOS number keys, lower the macOS arc crest into the taller bar, and keep the macOS shadow on the same curve
- [x] F24-L - Use public iOS 26 `.glassEffect` on the arc over the existing dark `Theme.surface` base with a restrained dark tint; keep `.regularMaterial` on earlier iOS versions
- [x] F24-M — Add explicit full, inline, and hidden navigation presentations; keep AI Chat’s composer above a compact inline rail and add a lower-corner hidden-rail reveal gesture
- [x] F24-N — Stabilize AI Coach’s root inline presentation preference and animate full/inline rail insertion and exit from the shared bottom edge
- [x] F24-O — Make the compact AI Coach rail draggable with projected release selection, one-to-one tracking, soft translation limits, and shared slot spring settling
- [x] F24-P — Reserve bottom space above the compact rail so the AI Coach composer and approval card never render behind navigation
- [x] F24-Q — Synchronize destination presentation with selection so leaving AI Coach always restores the full arc during page transitions
- [x] Verified: iOS 26.5 and iOS 18.6 Simulator builds succeed; both refreshed iOS app bundles installed and launched; the adaptive AI Coach inline-transition fix builds for iOS and macOS; Home remains centered and the arc stays dark with restrained native glass; manual AI Coach transition, drag, and directional page-transition review remains for human verification

## Cycle 13 — Music Library Update
- [x] F25 — Native Music Library / Settings screen
  - [x] Provider-neutral music library model, persisted ordered destinations, local-file adoption, and provider adapter boundaries
  - [x] Compact black Music screen with Uploads, General, Type/Mine workout panes, native iOS 18 glass fallback, provider brand assets, local import, local search, select/add, move/duplicate transfer, player, guide, and accessibility motion/transparency handling
  - [x] Music opens as a full-screen destination with an explicit close control; top controls no longer overlap Uploads; Search runs its fixed-frame provider-logo sweep
  - [x] Reflowed the full-screen Music panes so focused Workout fills the remaining screen height, Uploads keeps every source card visible, and typed transferable drag/drop supports ordered intra-list and cross-destination drops
  - [x] iPhone 16 iOS 18.6 Simulator build installed and launched; external Spotify, YouTube Music, SoundCloud, Dropbox, and Google Drive credentials remain required for their official integrations

## Cycle 14 — Private Liquid Glass Controls
- [x] F26 — Private Liquid Glass Controls
  - [x] Pin the known-good LiquidGlassKit renderer to the iOS application target
  - [x] Use the private renderer for iOS versions before 26 and native public Liquid Glass on iOS 26+
  - [x] Apply circular private glass to icon-only primary toolbar actions across the app
  - [x] Apply the same circular surface to Music settings controls
  - [x] Build iOS and macOS targets; launch the iOS 18.6 Simulator app and review the Home toolbar
  - [x] Ready for human verification; private renderer remains unsuitable for App Store submission

## Cycle 15 — Home Dashboard Redesign

- [x] F27 — Home Dashboard Redesign
  - [x] F27-A — Adaptive infinite widget canvas
  - [x] F27-B — Today scheduled workout instances and Quick Start
  - [x] F27-C — Existing-feature widget catalog and picker
  - [x] F27-D — macOS/iOS edit mode, local persistence, accessibility
  - [x] Support content-aware compact 0.5:2 half-width two-row, square 1:1, and wide 1:2 widget footprints with saved shape changes
  - [x] Show true-content picker previews with explicit Add actions
  - [x] Add dashed widget boundaries, drag-only insertion slots, and whole-base drag reordering
  - [x] Preserve legacy footprint values while exposing shape selection in the widget menu

## Cycle 16 — Home Widget Edit Corrections

- [x] F27 — Correct compact Greeting to 0.5:2 half-width two-row geometry
- [x] F27-A — Hide insertion slots until active drag begins
- [x] F27-D — Add direct per-widget options and shape controls in edit mode
- [x] F27-D — Preserve full-base drag behavior without blocking edit controls

## Cycle 17 — Home Surface and Motion Corrections

- [x] F27 — Render Greeting as a background-free full-width text strip
- [x] F27-C — Render Activity Shortcuts as circular Workout, Run & Walk, and Bike controls
- [x] F27-C — Add iOS device-motion tilt with a level fallback when motion data is unavailable
- [x] F27 — Keep card surfaces for action-heavy modules only; preserve Quick Start surface
- [x] F27 — Update Home redesign documentation and run iOS/macOS builds plus iPhone Home smoke check

## Cycle 18 — Home Drag and Add Picker Correction

- [x] F27-A — Replace system drag-only behavior with direct full-base drag reordering
- [x] F27-A — Pause canvas scrolling during an active widget drag and show live insertion feedback
- [x] F27-A — Restore smooth edit-mode widget bases inspired by the previous Home surfaces
- [x] F27-C — Redesign the Add Widget sheet as grouped preview bases with overlapping circular plus actions
- [x] F27-C — Keep the picker open after each add so multiple widgets can be selected before Done
- [x] F27 — Update product documentation and validate iOS/macOS builds

## Cycle 19 — Workout Library Surface

- [x] F15 — Responsive workout library cards and connected summary
  - [x] Add live weekly sessions, training seconds, streak, and weekly-goal counters
  - [x] Add search, All/Today scope, workout-type filtering, scheduled status, and resume state
  - [x] Connect create, start, duplicate, pin, delete, and resume actions to existing stores
  - [x] Add live workout-detail counters for sections, sets, duration, and completed sessions

## Cycle 20 — Home Gesture and Surface Corrections

- [x] F27-A — Keep Home canvas scrolling available throughout edit mode
- [x] F27-A — Require long press before a widget drag begins and keep the full widget base as the drag target
- [x] F27-A — Remove the edit-mode drag-handle icon
- [x] F27 — Restore normal module spacing and quiet bases for progress and analytics modules
- [x] F27 — Update Home product documentation

## Cycle 21 — AI Coach Inline Rail Correction

- [x] Restore AI Coach chat content and composer above the compact inline rail
- [x] Make inline rail dragging track one-to-one and select the projected destination reliably
- [x] Synchronize rail selection with page presentation so AI Coach exits restore the full navigation arc
- [x] Resolve the WorkoutList history-entry shadow that blocked the application build
- [x] Build iOS and macOS targets and launch the corrected iOS AI Coach flow; manual drag review remains for human verification

## Cycle 22 — Blueprint Alignment and Adaptive Widgets

- [x] Home and workout visual alignment
  - [x] Use category-aware workout cards with compact cover mosaics, duration, exercise/set counts, schedule status, and resume state
  - [x] Persist workout cover style and custom cover image choices through app and TimeMasterCore manifests
  - [x] Keep stretch cards focused on stretch count while rep-based categories expose set and exercise counts
- [x] Rich system widgets
  - [x] Add a WidgetKit extension target with shared App Group data
  - [x] Add configurable Quick Start, Today, and Progress widget content modes
  - [x] Support small, medium, and large widget families with real workout, schedule, streak, and goal data
  - [x] Preserve old widget payloads with backward-compatible decoding
- [x] Verification
  - [x] Run core tests and build iOS app, widget extension, and macOS app targets
  - [x] Launch the iOS simulator Home flow; final gesture and visual review remain ready for human verification

## Cycle 23 — F28 Better Maps and Route Recording

- [ ] F28 — Complete iPhone outdoor recording remake
  - [x] Preserve pre-F28 implementation on remote archive branch
  - [x] Approve COLOSSAL impact, migration, and product decisions
  - [ ] RF28-A — Document old-to-new outdoor migration
  - [x] Open authoritative route-recording HTML prototype
  - [x] Read every HTML implementation comment completely
  - [x] Run prototype and exercise every implemented state
  - [ ] Map pine states into reusable native Swift components
  - [ ] F28-B — Route Pine System
    - [ ] Keep interactive map as permanent independent background
    - [ ] Implement route pine compact medium expanded MAX geometry
    - [ ] Implement continuous drag resizing with native springs
    - [ ] Implement compact-to-zero dismissal for closable feature pines
    - [ ] Use native iOS 26 Liquid Glass bases
    - [ ] Match iOS 16–25 private glass geometry exactly
    - [x] Use public frosted blur for iOS 16–18 map surfaces
    - [x] Add gooey map-mode expansion animation for iOS 16–18
    - [ ] Reproduce the complete Start state exactly
    - [x] Keep Start and mode controls stable during pane resizing
    - [x] Enlarge and center the Start action cluster responsively
    - [ ] Implement Type with official native wheel picker
    - [ ] Separate previewed Type from committed workout Type
  - [ ] F28-C — Recording Engine
    - [ ] Morph Start pine into live workout in-place
    - [ ] Connect time speed distance to recording service
    - [ ] Keep speed and distance fully offline
    - [ ] Build hybrid Core Location altimeter elevation pipeline
    - [ ] Pause and resume without resetting workout state
    - [x] Keep live workout indicators and actions aligned through detents
    - [ ] Repair interrupted activity recovery across process relaunch
    - [ ] Preserve legacy Run & Walk while adding Run and Walk
  - [ ] F28-D — Map Platform
    - [ ] Connect map-side controls through real service boundaries
    - [x] Keep weather display-only and noninteractive
    - [ ] Preserve deferred offline-area-selection service contract
    - [x] Implement categorized base-map and overlay controls
    - [x] Connect approved production map providers and attribution
    - [x] Rebuild map settings as contextual rows
    - [x] Disable incompatible map layers for Terrain and Satellite
    - [ ] Implement Explore Terrain Satellite 3D Transit Traffic Cycling Dark Direction
    - [x] Reduce iOS 18 map-pan rendering and glass capture overhead
    - [x] Fit map to city scale from the offline-map control
    - [x] Compact map modes into a horizontal two-row picker
    - [x] Separate rounded map quick controls and weather surfaces
    - [x] Hide native map footer controls behind the route pane
    - [x] Place route notifications at the safe-area top
    - [x] Put the quick-pane close action in the top-right corner
    - [x] Apply an orange route accent, blue water, and restrained green landscape
    - [x] Replace the dimmed dark overlay with a direct dark map palette
    - [x] Densify the Map pane and remove redundant base and overlay summaries
    - [x] Package custom map glyphs before overriding the provider font stack
    - [x] Keep the live workout session alive when the map is dismissed
    - [x] Show live speed and distance in the main app
    - [x] Add a Home map opener for starting outdoor workouts
  - [ ] F28-E — Music Workout Editor
    - [ ] Connect Music Editor to existing Settings music system
    - [ ] Implement content-driven Music pine sizing
    - [ ] Use native wheels for music section selection
    - [ ] Implement predictable track reorder and folder intent
    - [ ] Keep cross-section imports session-only per workout
    - [ ] Implement persistent fixed-height compact player pine
    - [ ] Return every Music Edit action to same editor
    - [x] Clarified: route Run/Bike/Walk modes stay outside Music Editor
      - [x] Drive editor sections from Advanced Music Settings
      - [x] Limit tray sources to workout types containing music
      - [x] Keep tray search inline with an explicit Search action
      - [x] Adapt editor content to the available pane height
    - [x] Allow Music pane to expand to content-fit and seventy percent of usable height
  - [ ] F28-F — Finish Establish and Library
    - [ ] Morph live pine into Finish state in-place
    - [ ] Bind Finish statistics to finalized real activity
    - [ ] Record played music history with finalized workout
    - [ ] Reject activities below three metres accepted movement
    - [ ] Implement Establish then return pine to Start
    - [ ] Resume from Finish without losing workout state
    - [ ] Render Library inside the same route pine
    - [ ] Keep Starred independent from Library filters
    - [ ] Implement Library workout type filters and sorting
    - [ ] Show persisted workout-type badges on route cards
    - [ ] Render real route geometry in cards and details
    - [ ] Implement editable established-workout detail state
    - [ ] Preserve public metadata when changing to Private
    - [ ] Require confirmation before workout deletion
    - [ ] Require hold confirmation for significant workout deletion
    - [ ] Post Public activities to the local Profile only
    - [ ] Add reusable user-created activity tags
    - [ ] Add GPX and FIT Share/Export
  - [ ] F28-G — Settings Privacy and Recovery
    - [ ] Bind quick Settings to persisted preferences
    - [ ] Keep all unfinished feature interiors intentionally empty
    - [ ] Add configurable endpoint privacy with 200-metre default
    - [ ] Connect Apple WeatherKit and cached unavailable states
    - [ ] Migrate existing finished activities as Private Library entries
    - [ ] Extend backup and import for complete route data
  - [ ] F28 verification
    - [ ] Test every pine with live sibling panes
    - [ ] Test state preservation across all focus changes
    - [ ] Test compact medium expanded and MAX presentations
    - [ ] Verify no workflow state becomes page navigation
    - [ ] Compare native workflow against HTML effectively one-to-one
    - [ ] Verify iOS 16 iOS 18 and iOS 26 builds
    - [ ] Exercise Start live pause Music Finish Establish Library Profile
    - [ ] Hand every F28 child to human for verification
    - [x] Size route buttons so labels stay inside their controls

  - [ ] Pre-ride safety verification requested for a 50 km Bike ride on iOS 16.1
    - [ ] Test background recording and recovery after termination
      - [x] Preserve recorded data without inventing distance across termination and finished-session gaps
    - [ ] Test complete UI including music panel accessibility
      - [x] Place speed units below their values and constrain compact and expanded metric layouts
      - [x] Separate GPS status from the route drag handle with a dedicated status row
      - [x] Restore Music above its compact minimum and expand for search and picker controls without overlapping recording actions
      - [x] Keep recording-error recovery controls scrollable instead of overlaying live actions
      - [x] Respect imperial units in the live widget and distinguish finished rides awaiting establishment
      - [ ] User visual and interaction review; AI UI testing stopped at the user's request
      - [x] Extend maximum recording mode to the phone edges while keeping controls inside the safe area
      - [x] Increase the default base from 30% to 35% and its minimum beside a feature pane from 22% to 28%
      - [x] Hide the close and exit controls in both expanded and maximum modes
    - [ ] Test user tracking and GPS failure handling
      - [x] Keep accepting valid fixes after switching to Precise accuracy; clear stale speed and expose lost or inaccurate GPS
      - [x] Run all 15 app-hosted ride safety regressions on iOS 18.6, including the synthetic 50 km ride
      - [x] Reset short discarded sessions so a different next activity can start
    - [x] Test ride distance speed and duration measurements with a 50 km, 5,001-point synthetic ride, pause boundaries, finish, establishment, and reload
    - [ ] Test ride saving persistence and relaunch recovery
      - [x] Preserve the last valid manifest on failed updates and use atomic file replacement
      - [x] Preserve the next GPS fix after an interrupted JSONL append
      - [x] Preserve fractional GPS timestamps in storage and backup codecs
      - [x] Recover uncheckpointed elevation and retain finished rides until establishment
      - [x] Run all 16 outdoor storage tests, including failed writes, interrupted appends, and fractional timestamps
    - [ ] Test terrain hill elevation totals and 3D
      - [x] Count gradual climbs without counting stationary noise or barometer reanchoring as ascent
      - [ ] Implement actual terrain relief, 3D hills, and upcoming-climb height; current mode tilts the map and extrudes buildings only
    - [ ] Test all map options including location recentering
      - [x] Let explicit recentering restore follow mode after manual map movement
      - [ ] User checks map modes, recentering, and settings; automatic UI checks were stopped
    - [ ] Investigate additional ride safety and iOS 16.1 compatibility bugs
      - [x] Add required Motion permission text and background location indicator
      - [x] Add app-hosted safety regression target and fix platform plist and glyph-resource packaging
      - [x] Compile the final iPhone app with an iOS 16.0 minimum deployment target; physical iOS 16.1 runtime verification remains pending
      - [x] Package and validate an unsigned arm64 Release IPA for the user's sideloading test
    - [x] User reports the recording backend working end-to-end during a real ride; UI revisions requested below

  - [x] Field-ride UI revision — implemented, ready for human review
    - [x] Reserve safe header space around expansion controls in every pane
    - [x] Redesign Recent Rides using the existing orange and glass identity
    - [x] Add a reusable search bar with the type selector on its right
    - [x] Use anchored pop-up selectors for workout type and Private/Public
    - [x] Give duration, distance, and workout type a clear information hierarchy
    - [x] Make workout naming and saved-route renaming directly accessible
    - [x] Keep map controls available while viewing saved workouts
    - [x] Replace the layered Finish/Establish UI with one coherent Save flow
    - [x] Ask for workout mode before the first recording and confirm after cancellation
    - [x] Suppress confirmed mode prompts until the app has been away for one hour
    - [x] Allow changing a saved workout's type without changing recorded data
    - [x] Pass 19 app-hosted non-UI regressions and package the updated unsigned iPhone Release app; no automated UI tests run
    - [x] User reviewed the revised interface and reported search, grid, detail, and resizing mismatches

  - [x] Diagram-based outdoor UI corrections — implemented, ready for human review
    - [x] Match the library diagram, filter Starred during search, and omit an empty Starred row
    - [x] Build a reusable Spotlight-style search that expands from its button only when opened
    - [x] Use route-thumbnail grid cards with distance-only captions
    - [x] Match the route detail diagram with pencil editing and route-map preview/return
    - [x] Respect bottom boundaries and adapt action size and placement as panes resize
    - [x] Pass 20 app-hosted non-UI regressions and launch the updated iOS 18.6 iPhone 16 simulator app; no automated UI tests or interactions run
    - [x] User reviewed the UI and requested header, Start controls, Back navigation, and inline activity selection corrections

  - [x] Outdoor pane alignment and activity selection corrections — implemented, ready for human review
    - [x] Center Recent/Starred independently of toolbar widths and raise the header controls
    - [x] Place the expansion control at the bottom-right of the main pane
    - [x] Make library Back return to Start while keeping the map open
    - [x] Keep Type, Heart, and Music along the bottom of Start
    - [x] Place Route to the right of Start and open routes within the main pane
    - [x] Replace the modal mode prompt with a large inline activity carousel
    - [x] Show the committed activity icon and close the lower pane after acceptance
    - [x] Pass 20 focused non-UI regressions, build the synchronized sources, and launch the corrected iOS 18.6 iPhone 16 app; no automated UI interactions run
    - [ ] User reviews the corrected layout, carousel, and pane navigation

  - [x] Outdoor route previews and pane motion — implemented, ready for human review
    - [x] Show the most recent recorded route in the Library button, with the grid icon as its empty fallback
    - [x] Replace the right-hand Route symbol with the licensed Lucide route icon
    - [x] Replace the expansion button with an animated top-right resize grip
    - [x] Extend the Home pane to the physical viewport edges while preserving safe content insets
    - [x] Keep secondary pane content stable during opening and closing
    - [x] Add directional handle flex, drag highlighting, and Reduce Motion behavior
    - [x] User reported that the first candidate still closed poorly and stopped short of the viewport edges
    - [x] Continue the main drag directly through normal expansion into fullscreen
    - [x] Slide below the lower pane's minimum height and retain its content until dismissal finishes
    - [x] Pass 24 focused non-UI regressions and launch on iPhone 16 with iOS 18.6 without automated UI interactions
    - [ ] Human review of route previews, fullscreen dragging, and pane motion

  - [x] Outdoor fullscreen mode and free-height controls — implemented, ready for human review
    - [x] Replace the corner grip with stable expand/collapse symbols and reserve fullscreen entry for that corner control
    - [x] Keep fullscreen collapse taps enabled while disabling the corner resize gesture
    - [x] Remove the central drag handles from fullscreen
    - [x] Enlarge Home controls and fade labels in from sixty to sixty-eight percent of physical screen height, in floating and fullscreen layouts
    - [x] Apply the same height-based label rule to workout controls while retaining pause, finish, music, and bus-transfer behavior
    - [x] Integrate Library, Routes, Type, Heart, and Music into the lower seventy percent of fullscreen; preserve Heart's approved empty interior
    - [x] Reflow Home controls and live metrics into the upper region while a secondary section is open
    - [x] Keep the upper thirty-percent controls icon-only while a fullscreen secondary section is open
    - [x] Release the covered background map renderer and retain camera state without interrupting GPS recording or adding energy-saving copy
    - [x] Keep workout action buttons along the bottom at every pane height, with horizontal scrolling at accessibility text sizes
    - [x] Limit the central line handle to floating expansion without entering fullscreen
    - [x] Expand the floating background to ninety-five percent of the physical screen while preserving navigation and player space for content
    - [x] Preserve arbitrary released floating heights without snapping to preset detents
    - [x] Resize component geometry, metric placement, fonts, and labels continuously using the older stable layout as reference
    - [x] Keep Start and activity text attached to and contained inside the Start circle throughout resizing
    - [x] Fit Library and Routes captions at accessibility text sizes
    - [x] Move map utilities from vertical columns into non-overlapping horizontal rows below the notch along a smooth curved path
    - [x] Keep map utilities fully visible through ninety-five percent and fade them only between ninety-five percent and fullscreen
    - [x] Hide the large map attribution pill from ninety-percent expansion while retaining map credits and licence links in Settings
    - [x] Include eight existing Outdoor route files in the app and macOS Sources phases so current main builds
    - [x] Keep Nearby Routes location requests, permission changes, and location-error feedback working while the map is detached
    - [x] Pass thirty focused app-hosted checks per device and inspect eighteen read-only pane renders per device on iPhone 16 and SE with iOS 18.6, without automated UI interactions
    - [ ] Human review of free-height dragging, corner fullscreen/collapse, resizing, labels, integrated pages, large-text scrolling, and map return

  - [ ] Trip planning and bus-transfer accounting — implementation prepared; human review pending
    - [x] Add Make a Trip, nearby suggestions, custom suggestions, saved trips, and drafts
    - [x] Add editable ordered stops, current-location starts, place search, map picking, trip and leg preferences
    - [x] Add a bounded floating destination panel, following map controls, and connected Save, Draft, and Delete actions
    - [x] Add road-snapped blue route editing, hidden shaping points, surrounding route anchors, undo, cancellation, and stale-request protection
    - [x] Add legal cycling and running profiles, elevation-aware running goals, and real POI-based route generation with distance tolerance
    - [x] Add configurable GraphHopper, Photon, and Overpass services with explicit privacy and availability disclosures
    - [x] Add a local GraphHopper launcher and seven routing profiles; exercise real Monaco routes and import Vancouver coverage
    - [x] Add user-marked bus transfers as road estimates, with active distance primary and total distance including bus
    - [x] Add explicit Board bus and Resume riding controls, recovery, immutable recorded-plan snapshots, and separate transport exports
    - [x] Keep legacy GPX routes, unfinished workouts, trip drafts, and backup imports compatible
    - [x] Pass 26 focused app-hosted checks and 18 core checks; independently decode FIT, GPX, and CSV exports
    - [x] Build the latest planner and relaunch it on the iOS 18.6 iPhone 16 at the user's request
    - [x] Complete inline trip-editor and road-drag verification on the existing map
    - [x] Native offline cutover and icon-first Pine editor — implementation handed off; human review pending
      - [x] Embed the pinned Valhalla engine for iOS 16+ with HTTP and remote time-zone downloads disabled
      - [x] Prepare and bundle Vancouver Core with routing, local vector maps, places, addresses, road surfaces, and elevation
      - [x] Import, cancel, replace, and remove versioned area ZIPs without losing saved trips or drafts
      - [x] Replace Photon and Overpass runtime queries with the installed local place index
      - [x] Generate connected nearby and custom loops with per-trip and per-leg preferences and real terrain goals
      - [x] Retire GraphHopper launchers, service URL fields, localhost workarounds, and network fallback
      - [x] Keep custom-trip editing on the existing map while sliding out the lower pane and repositioning controls
      - [x] Reuse Pine glass actions with icon-first controls, concise primary labels, and accessible touch targets
      - [x] Preserve shaping, undo, cancellation, recovery, saved trips, drafts, and active-versus-total bus accounting
      - [x] Exercise real offline routes, search, suggestions, area installation, and draft recovery
      - [x] Build, run focused regressions, publish the complete cutover, and hand it to the human
      - [ ] Human review of offline coverage, route choices, planner transitions, and icon-first controls
    - [x] Routes sketch and planned-trip corrections — implementation prepared; human review pending
      - [x] Recreate Make trip, Nearby, Custom, Saved, and centered Drafts shortcuts from the user's sketch
      - [x] Generate automatic native offline road recommendations from the current location
      - [x] Show Nearby and Starred as horizontal map cards and Yours as a vertical two-column grid
      - [x] Show each route's actual map, estimated time, prominent distance, and activity
      - [x] Reuse the workout Library search and ordering controls; search hides the shortcuts and covers Nearby, Yours, and Starred
      - [x] Persist route stars without promoting incomplete drafts or breaking existing saved-route files
      - [x] Open selected roads in a draggable, resizable Pine preview over the same map and clear the preview when returning to Routes
      - [x] Show the road name, activity circle, large distance, estimated time, and elevation gain in the preview
      - [x] Retain editable stop fields, dotted destination markers, the full-width dashed Add destination action, and adjacent routing controls
      - [x] Show richer road, elevation, and effort details; render bus legs yellow on the map
      - [x] Generate a branded Planned Trip image with the actual map and support native sharing and Photos saving
      - [x] Connect preview Start to the existing recorder and Delete to persisted route removal
      - [x] Exercise the complete Routes, preview, editing, sharing, Photos, and recording flow and run focused regressions
      - [ ] Human review of the Routes sketch layout, nearby road quality, preview resizing, trip actions, and image export
    - [ ] Human review of trip planning, suggestion quality, route editing, and bus recording

## Cycle 24 — Video Editor UX & Platform Parity

- [x] macOS video editor timeline UX
  - [x] Clicking the timeline moves the playhead directly without dragging it
  - [x] Clicking timeline segments selects them
  - [x] The `X` key splits the selected timeline segment at the playhead
- [x] Video editor media tray grouping
  - [x] Every captured still and clip is its own draggable media element
  - [x] Dragging one media element onto another groups their media for saving
  - [x] Grouped media stays within the twenty-item page limit
- [x] macOS save destination popover compact sizing
- [x] iOS video editor adaptation
  - [x] Timeline playhead scrubs by touch and selects the touched segment
  - [x] Split action cuts the selected segment at the current playhead
  - [x] Media tray captures each still or clip as an independent card
  - [x] Video media saves to the page-backed database with existing/new destinations

- [ ] iOS Photos or Files source choice with owned temporary video copies
- [ ] Live video preview seeking, scrub resume, replay, and dismissal pause on iOS and macOS
- [ ] Editor workspace hierarchy with filmstrip, transport, capture tools, and connected media tray
- [ ] Keep database parent references consistent when removing failed imports
- [ ] Reload and exercise the editor on the existing iOS 18 simulator
- [ ] Human review of the updated iOS and macOS editor
---

## Cycle 25 — Home Widget Direct Manipulation

**Requested with user: 2026-09-27. Implementation handed off; human review pending.**

- [x] Move the actual Home widget under the finger with live neighboring layout and edge scrolling
- [x] Drop newly added widgets at the top after dismissing the picker
- [x] Resize supported widgets continuously with corner grips and Small, Medium, and Large snap sizes
- [x] Pack adjacent Small widgets side by side and preserve saved widget identities, configuration, order, and sizes
- [x] Simplify Today and other widget content with centered bold headings and concise empty states
- [x] Restore scrolling after cancelled or interrupted gestures and keep the final widgets reachable above navigation
- [x] Reset interrupted navigation rail gestures and disable page-swipe competition while editing Home
- [x] Exercise dragging, resizing, insertion, persistence, interruption, edge scrolling, larger text, and Reduce Motion on iPhone 16 with iOS 18.6
- [x] Build iOS and macOS in an isolated working copy using committed app-entry files without restoring the user's local deletions
- [ ] Human review of Home dragging, resizing, insertion, and widget appearance
- [ ] Human review of Home scrolling and navigation rail responsiveness

---

## Cycle 26 — Workout Library Chrome Alignment

**Requested with user: 2026-09-28. Implementation handed off; human review pending.**

- [x] Share one collapsing page chrome between the Database and Workouts pages
- [x] Move the Workouts corner actions — Search, Settings, Add — into the chrome as database-style glass squares that fold into compact circles while scrolling
- [x] Keep the tracking indicators static: dark squares, expanded to the content borders
- [x] Remove the "Your training library" heading and the navigation bar title; the page is labeled by the navigation rail
- [x] Slim the weekly goal card into one persistent goal row with a thin progress line, hidden while no goal is set
- [x] Match the workout group filter chips to the database chip style
- [x] Keep the search field, resume state, and workout cards in the scrolling content under the pinned chrome
- [ ] Human review of the Workouts page actions, collapse, tracking tiles, goal row, and filter chips

---

## Cycle 27 — Carousel Navigation and Workouts Title

**Requested with user: 2026-09-28. Implementation handed off; human review pending.**

- [x] Adopt the SwiftComponentLibrary CarouselNavigation component as the app's navigation, keeping its geometry, gestures, editor and accessibility with TimeMaster's palette, copy and destinations
- [x] Give the arc one plain hairline rim; the glass, specular gradient and sweep treatment is gone
- [x] Long-press the arc to edit: the page dims and blurs, "+" slots appear at both ends, and the catalog offers all seven app pages, with pages already on the bar drawn dimmed
- [x] Drag icons to reorder, drag one above the bar to remove it, and tap the dimmed background to finish
- [x] Persist the arrangement per device under `tm.navigation.order.v1`, keeping destination ids stable
- [x] Keep AI Coach inline, Map hidden behind its upward-swipe reveal, and macOS arrow and number selection
- [x] Fix editor item taps — the catalog and configurable items — by lowering the item drag gesture below the tap
- [x] Investigate the page-switch stutter: the bar alone holds 60 fps with no dropped frames; the remaining hitch is the destination page's own first render
- [x] Workouts chrome: title centred while the actions are expanded and travelling to the leading edge as they collapse, with the stats row pinned under the title, above the weekly goal and the filter tabs
- [ ] Human review of the navigation bar, its editor, and the Workouts chrome

Cycle 26 removed the Workouts page title; the user asked for it back, so the title returns as described above.

Note for the next build: the working tree's `OutdoorTripLibraryView`, `OutdoorTripPlannerView` and `OutdoorRouteRecordingView` do not compile as they stand (a missing `TimeMasterCore` import and a changed call site); the throwaway build workspace used their committed versions.

---

## Cycle 28 — Navigation Add Layer

**Requested with user: 2026-09-29. Implementation handed off; human review pending.**

- [x] Put an Add control in the menu editor header, so the catalog is reachable without dragging the reel to its ends — the two "+" slots sit before the first and after the last page, which is off screen once the bar holds seven pages
- [x] Mark a catalog page that is already on the bar with a checkmark instead of the same green plus used for addable pages
- [x] Lift already-added catalog pages from 0.4 to 0.55 opacity and give them their own accessibility value
- [ ] Human review of the editor's add layer

The app has seven top-level pages and every one of them is on the bar by default, so the catalog is empty of addable pages until a page is removed. Promoting further screens — History, the music library, settings — to destinations is a product decision, not part of this cycle.

---

## Cycle 29 — Database and Workout Editor Polish

**Requested by user: 2026-10-04. Initial handoff; the fixed workout title/actions were rejected and corrected in Cycle 30. Human review remains pending.**

- [x] Put database attachments in a horizontal thumbnail strip below the cover, retaining the full-screen media viewer
- [x] Keep the cover below the navigation bar and remove the overlapping top fade
- [x] Rework database rows into a thumbnail, readable title and metadata, one navigation target, and a separate hierarchy disclosure
- [x] Start Database controls compact, reveal them with a top pull, and collapse them when scrolling down
- [x] Apply the same compact-first controls to Workouts
- [x] Apply the same top-pull controls to the workout editor's More, Add, and Browse actions
- [x] Keep workout sections collapsed initially; adding a set expands its section and requests scrolling to that set
- [x] Animate section and rest disclosure, row insertion, and removal with stable row identities and Reduce Motion support
- [x] Keep only the workout summary pinned while the title and actions scroll away; compact it while scrolling and restore its expanded layout at the top (corrected in Cycle 30)
- [x] Keep Start Workout inside the existing carousel navigation content bounds
- [x] Build the task-only iOS Simulator snapshot and render Database, attachment detail, Workouts, and the workout editor on the already-running iPhone 16
- [ ] Human review of the changed code, attachment browsing, pull-to-expand/collapse, set insertion, pinned-summary motion, and Reduce Motion behavior

Checks used the committed app with only this task's source changes in an isolated workspace because the main working tree already contained unrelated edits and deleted app entry points. No UI tests, automated taps or swipes, new simulator, or fixture data were used in the completed checks. The existing database contains one attachment, so multi-attachment scrolling and interaction timing remain for human review. Product DOCKS.md files remain unchanged pending acceptance.

---

## Cycle 30 — Scrolling Workout Header and Morphing Navigation

**Requested by user: 2026-10-04. Implementation handed off for human review; not human-verified.**

- [x] Move the workout title and action controls into the normal scrolling list instead of a fixed top panel
- [x] Use a native sticky section header for the workout summary, compact while scrolled and expanded at the top
- [x] Keep one global navigation surface and the same icons while morphing between the existing arc and a flat, icon-only slim row
- [x] Expand slim navigation on touch and fold it when interacting with page content; preserve carousel interactions, long-press editing, and Reduce Motion support
- [x] Request slim navigation in the workout editor and keep Start Workout directly above the navigation content boundary in both layouts
- [x] Include the two portable database back-toolbar placements already present in the working copy so the committed app also builds for macOS
- [x] Build the task-only production sources for iOS Simulator and macOS, and render the changed states on the already-running iPhone 16
- [ ] Human review of the code, scrolling and return-to-top behavior, touch-driven morphing and interruption, navigation selection/editing, and Reduce Motion behavior

The focused iPhone renders covered the editor at the top and scrolled down, its slim and expanded navigation layouts, and the normal Home arc. Builds passed with existing warnings. Temporary render hooks were removed before rebuilding and installing the clean app. No UI tests, automated taps or swipes, fixture data, or new simulator were used. Gesture timing remains for human review. Checks used an isolated task-only snapshot; unrelated working-tree edits and deletions were preserved. Product DOCKS.md files remain unchanged pending acceptance.

---

## Cycle 31 — Weekly Schedule and Settings Destinations

**Implementation handoff: 2026-10-05. Requested by the user; human review pending.**

- [x] Add Schedule to the navigation bar and preserve each existing custom navigation order
- [x] Make Settings a navigation destination and route the existing Home, Workouts, and settings-command shortcuts to it instead of separate sheets
- [x] Build the Monday–Sunday timeline with an outlined Today, daily workout and minute totals, connected library workouts, and the shared duration picker
- [x] Save reusable Plans with names and icons, equip them from a chosen week onward, and preserve previous weeks when the current Plan changes
- [x] Put Vacation in the Plans chooser, empty vacation weeks, freeze streak progression, and resume by choosing a Plan
- [x] Offer a remembered 1–7-day streak challenge on every Schedule entry without an onboarding flow
- [x] Share animated difficulty-specific flames between the challenge chooser and weekly header, including the dark seven-day treatment
- [x] Match completed in-app workouts to scheduled occurrences without counting partial sessions or reusing one session for duplicate occurrences
- [x] Allow manual completion and correction for current and past workouts without allowing future completion
- [x] Log outside-app workouts from Today with only a required title and optional start time, duration, description, and exercise count
- [x] Reuse the analytics calendar with selected-week outlines, daily activity counts, and navigation back to the chosen week
- [x] Navigate weeks with accessible buttons and pull-and-hold; cancel short pulls and early releases, move once per hold, and rearm after release
- [x] Keep the bottom of the timeline reachable above the navigation bar and adapt the week header at large accessibility text sizes
- [x] Persist Plans, weekly selections, challenges, custom logs, and completion overrides through the existing configuration store
- [x] Run 11 focused scheduling model checks and the real-store completion/reload scenario; exercise the connected Schedule and Settings flow in an isolated iOS Simulator app and build iOS and macOS
- [ ] Human review of Schedule layout, Plan editing and recurrence, Vacation/resume, challenge choices, flame styling and motion, and calendar navigation
- [ ] Human review of automatic/manual completion, custom logging, persistence, large text, and pull-and-hold behavior
- [ ] Human review of Settings as a destination and the migrated Home, Workouts, and settings-command shortcuts

Native checks used a task-only snapshot with committed app-entry files because the working tree contains unrelated edits and deleted app entry points. The final native flow covered Plan creation, title-only and optional-field custom logs, completion correction, next-week recurrence, calendar selection, Vacation/resume, Settings, challenge re-entry, and relaunch persistence. Separate native checks covered pull cancellation, one-week-per-hold behavior, repeated pulls, and large-text navigation. macOS was build-checked; macOS interaction review remains with the human. Product DOCKS.md files remain unchanged pending acceptance.

### Schedule blueprint correction — 2026-10-18

Requested by the user after reviewing the Schedule page. Implementation is ready for human review; this does not record human approval.

- [x] Replace challenge slogans and explanatory paragraphs with the title, weekday choices, and concise icon-led rule points
- [x] Use the shared orange-glass confirmation and sheet toolbar buttons
- [x] Make every day header expand and collapse independently, including empty days; open Today by default
- [x] Align the timeline with the supplied blueprint: compact week/date header, outlined day and metric boxes, connected workout rows, and an icon-only add row
- [x] Reuse the Database and Workouts expanding header controls for Calendar, Plans, and Streak without removing pull-and-hold week navigation
- [x] Adapt challenge choices and workout rows for accessibility text sizes and expose day expansion state to accessibility
- [x] Populate an isolated Schedule QA simulator app with sample library workouts, without inserting sample records into the real app
- [ ] Human review of the simplified challenge sheet, blueprint-aligned timeline, empty/populated day expansion, and shared button behavior

Two native smoke scenarios passed on iPhone 16 with iOS 18.6, covering challenge acceptance and empty selection, day expansion/collapse, adding from an empty day, custom logging, relaunch persistence, header expansion/collapse, pull-and-hold week navigation, and accessibility-size layouts. iOS and macOS builds passed using a task-only snapshot with committed app-entry files, preserving unrelated working-tree edits and deletions. macOS interaction review remains pending. Sample workouts remain available in the isolated Schedule QA simulator app; no sample-data hooks or temporary smoke scripts are included in production sources.

### Calendar and card polish — 2026-10-18

Requested by the user; implementation is ready for human review, not human-verified.

- [x] Keep the Analytics calendar shared with Schedule; align its content to the top, make both month and year views scrollable, and provide a usable macOS sheet size
- [x] Replace duplicate period navigation and explanatory copy with one month/year navigation row, selected-week highlights, daily counts, and shared orange controls
- [x] Open Activity from a calendar corner button using the existing Analytics heatmap and history; provide tappable dates with month markers and return to the same calendar position
- [x] Include established outdoor activity in calendar counts and day details alongside recorded sessions and manually completed Schedule entries
- [x] Apply layered charcoal surfaces, softer borders, warm open-day highlights, completion accents, inset metrics, and a restrained add control to Schedule cards
- [x] Animate day opening and closing with a spring, fading rows, stable seven-day layout, and no spatial animation under Reduce Motion
- [x] Bound Schedule toolbar hit regions and adapt calendar glyphs, date labels, and day-detail statistics for accessibility text sizes
- [ ] Human review of calendar positioning, Activity navigation, card styling, and opening/closing motion on iOS and macOS

Two focused native scenarios passed on iPhone 16 with iOS 18.6: month/year navigation, returning from Activity and day details, selecting a Schedule week, repeated populated-day expansion/collapse, empty-day adding, and maximum accessibility text with system Reduce Motion enabled. The existing custom sample log appeared in day details. The day-reveal frame sequence was inspected. Final iOS and macOS builds passed in an isolated snapshot with committed app-entry files; unrelated working-tree edits and deletions were preserved. macOS interaction review remains pending. The simulator's Reduce Motion preference was restored. Temporary verification sources are not part of production; the updated Schedule QA app retains its separate sample data.

### Activity heatmap refinement — 2026-10-18

- [x] Reduce the Activity sheet's time-range heading and date-number typography without changing the grid or tap targets
- [x] Increase corner rounding on both the interactive Activity squares and compact Analytics heatmap squares
- [ ] Human review of the smaller heatmap labels and rounder cells

The iOS build and focused native smoke passed in the isolated Schedule QA app. The rendered heatmap was inspected; opening a visible date's details and returning to Calendar passed. Changes are ready for human review; no calendar behavior was changed.

---

## Cycle 32 — Advanced Workout Music Configuration

**Requested by the user; implementation ready for human review, not human-verified.**

- [x] Open music configuration from the workout header or an intentional right-edge swipe, slide the existing editor above it with a visible edge, and prevent the global page swipe from stealing that gesture
- [x] Add free-timed primary and background lanes, duration-sized drop previews, movable placements, and the fallback region beyond the planned workout end
- [x] Resize only from the bottom, restore trimmed duration up to the source length, and snap to exercise boundaries only after repeated nearby resize corrections
- [x] Share the Settings library and persisted imports with the tray, retain local-file duration metadata, create folders in Settings, and group music through track-on-track drops
- [x] Edit folder track order independently for each timeline placement without changing the shared folder
- [x] Give primary music priority, pause the interrupted background playhead, resume it within its remaining placement window, and fade playback transitions
- [x] Connect live music selection, repeat, shared volume, return to the workout timeline, and explicit silence to the actual player
- [x] Leave exhausted fallback music silent and offer assigned music or repeat during a long or between-section rest without automatically starting it
- [x] Persist the optional timeline through workout files, app mappings, CLI input/output, and resume checkpoints while preserving legacy playlists when no timeline is configured
- [x] Remove cross-workout configuration copying after the user's interface correction, including the obsolete picker, copy API, and dedicated regression
- [x] Add long-press replacement that preserves lane, start, and trim, plus removal and timing/order editing
- [x] Pass the retained focused timeline regressions and a real CLI persistence roundtrip; exercise native audio interruption, pause/restore, manual override, and fallback exhaustion
- [x] Exercise editor reveal and cancellation, drag grouping and placement, trimming, replacement, placement-local ordering, Settings folder creation, removal, and explicit repeat/silence on the already-running iPhone 16 with iOS 18.6
- [x] Build the final production iOS and macOS targets, remove the isolated smoke app, and install and launch the final production app on that same simulator
- [x] Expose populated Settings groups beyond the current workout through the right-hand library selector, with an accessible current-group label and stored artwork or item-specific icons
- [x] Import three generated playable test tracks and a playlist into the actual iPhone 16 iOS 18.6 Settings library; verify General/HIIT filtering and persistence after installing the clean production app
- [x] Preserve the previously resolved SwiftMP3 revision explicitly after its upstream version tag changed, and build the sidebar changes for iOS and macOS
- [x] Remove the redundant Music heading, copy controls, and unused top space; extend the timeline while retaining an intentional return to the workout editor
- [x] Use circular sidebar covers, a symbol-only library selector, search directly below it, and an import control at the bottom
- [x] Open a native in-app player on a sidebar tap, with playback position, transport, volume, and unavailable-source feedback; do not add a timeline placement on tap
- [x] Show cover artwork and one title on drag previews and timeline placements; adapt short clips so the bottom trim handle does not overlap the title
- [x] Slide bottom navigation away during the music reveal, free its reserved space, and restore it when returning to the workout editor
- [x] Support downward navigation dismissal and intentional restoration through a separate bottom handle without activating Start Workout underneath
- [x] Replace the workout's gesture-dismissable zoom transition with normal navigation and an explicit back control so editing swipes do not exit the workout
- [x] Keep the workout title and action controls in one adaptive horizontal row
- [x] Build the corrected iOS and macOS targets, pass nine retained timeline regressions, and exercise native search, preview playback, navigation gestures, track and playlist drops, persistence after relaunch, and bottom trimming on the existing simulator
- [x] Separate sidebar library/search actions and the bottom import action from music covers with visible dividers and distinct, unframed control symbols
- [x] Place Back and zoom in a leading floating toolbar over the timeline, using Liquid Glass on iOS 26, translucent system material on older iOS, and an opaque surface with Reduce Transparency
- [x] Use an artwork/title/duration drag preview, continuous-time drop feedback, and restrained lane and placement transitions that respect Reduce Motion
- [x] Offer Duplicate below when extending beyond the full source length; create a separate placement in the same lane exactly at the preceding clip's end
- [x] Display clip duration and update it live while trimming or restoring length, including floating duration feedback for short clips
- [x] Restore timeline zoom-in and zoom-out with scale feedback and adaptive time-grid intervals without changing saved timing
- [x] Restore the workout header's existing orange-glass controls and scroll-driven expansion behavior
- [x] Replace workout-card and cover-mosaic type-color backgrounds with the app's neutral surfaces and separators
- [x] Enlarge the workout header title and reduce compact visual controls proportionally while preserving their touch targets and single-row layout
- [x] Build the repair changes for iOS and macOS; exercise native drag placement and lane movement, live trimming, full-length duplication, zoom, floating Back, and restored header expansion on the existing simulator
- [ ] User drag test: move a test track and Test playlist from the populated right-hand sidebar into the two timeline lanes
- [ ] Human review of the corrected sidebar, floating toolbar, drag feel, preview player, single-row expanding workout header, neutral workout cards, navigation gestures, timeline placement/trimming/snapping, live durations, duplication, folders, replacement, and imports
- [ ] Human review of audible fade quality, primary/background transitions, live choices, continuation prompts, resume behavior, and macOS interaction

Checks used an isolated task-only snapshot with committed app-entry files because the working tree contains unrelated edits and deleted entry points. The native fixture used real production views, stores, local audio files, and playback; its app and data were removed afterward. No new simulator was created, and unrelated working-tree changes were preserved. External-provider items still require their existing provider integration or local playable audio; this work does not bypass unavailable provider credentials. Product DOCKS.md files remain unchanged pending acceptance.

The interface correction checks used the final production app with the existing shared sample library. Temporary drag placements were removed through the UI; the user's existing Recovery placement was preserved. The corrected music sidebar remains open for human review. No new simulator or permanent test fixture was added. macOS compiled; its native interactions still require human review.

The styling-repair smoke used the same iPhone 16 with iOS 18.6. Temporary Flow placements and their duplicate were removed through the UI, restoring the user's Recovery timeline exactly. The corrected sidebar remains open for review. The native iOS 26 Liquid Glass appearance and macOS interactions were not exercised; both platform targets compiled.

### Live workout integration and control corrections — 2026-10-18

- [x] Preserve the populated sidebar, generated artwork, native pinch zoom, and floating timeline toolbar refinements
- [x] Open the actual playing timeline from the workout music control, with playback controls below and a slide-out library that supports live placement
- [x] Use compact floating music controls with artwork, title, stop/resume, and timeline access; collapse them into a corner circle on downward swipe and restore them on tap
- [x] Show Next only for the active playlist placement, respecting its trim; do not skip separately scheduled tracks
- [x] Open active-workout management from a corner control and reuse the builder's expandable exercises, sets, and rests, with right-side progress rails and start markers
- [x] Keep the database browser and builder editing actions available during a workout, and reconcile saved edits into the active session rather than ignoring changes to the same workout ID
- [x] Open the full attachment page and editor from workout rows, with actual photo/video thumbnails in a horizontal strip at the top instead of hero covers or page-cover cards
- [x] Show a plain attachment-page title, open photos and videos in the media viewer, and retain attachment editing
- [x] Replace direct sidebar import with the simplified shared Settings import flow, four import options, Search, and the collected-music list
- [x] Restore exact configuration selection from another workout as an independent copy, superseding the earlier removal requested in this cycle
- [x] Ask where collected imports belong before leaving: General, a workout type, or only this workout
- [x] Preserve workout-only library memberships across reloads and expose those destinations in Settings, including explicit transfer into General
- [x] Present active workouts full-screen from editor, Home, Schedule, workout list, and resume entry points, with explicit exit controls and swipe dismissal disabled
- [x] Enlarge the four compact workout-header controls to 48 points while retaining their adaptive expanding layout
- [x] Replace the header's per-button legacy Metal capture surfaces with system materials on older iOS, retain native glass where available, and publish scroll state only at meaningful thresholds
- [x] Make the active-workout widget compact, separate workout and music actions with a divider, and use a stacked layout only at accessibility text sizes
- [x] Allow dragging that widget within visible bounds; preserve normalized placement through size changes and provide accessibility movement actions
- [x] Route remaining toolbar actions, including Done and Save, through the shared toolbar styles and isolate their backgrounds on newer OS versions
- [x] Build the final iOS and macOS source snapshot, pass the nine timeline regressions, and exercise widget bounds and header state thresholds without a simulator
- [x] Stop simulator testing at the user's request, remove the isolated test app, shut down the pre-existing iPhone 17 Pro, and remove owned temporary workout/page fixtures while preserving unrelated data and the original resume checkpoint
- [ ] Human review of the live timeline, compact/collapsed music controls, playlist-only Next, active editing and progress, attachment browsing/editing, configuration copying, and import destinations
- [ ] Human review of the larger header controls, draggable compact widget, accessibility layout, and independent toolbar button shapes on the user's OS

Before the user stopped simulator testing, native scenarios exercised real audio, playlist trim boundaries, single-track non-skipping, live timeline replacement, pause/silence/resume, import membership persistence, progress expansion, and actual photo/video viewing. The final widget, header-performance, and toolbar changes received code-only checks afterward. The widget geometry smoke covered interior movement, every edge clamp, rotation, and zero-travel bounds. The header smoke covered threshold boundaries and hysteresis; 2,000 sampled offsets produced three distinct state transitions. These are not frame-rate measurements or human approval.

Both final platform builds passed in the isolated owned-change snapshot, using the committed app entry points. The checked-in project also includes the new geometry source in both app targets. Existing deprecation warnings remain. No iOS 27 compatibility claim is made from the installed SDK, and the final newer-OS toolbar appearance still needs human review. No further simulator interaction is planned; any future simulator verification is restricted to iOS 18 by the user's direction. Product DOCKS.md updates remain deferred until acceptance.

### Independent music sidebar and workout-page surface corrections — 2026-10-18

- [x] Give the configuration and live-timeline sidebar its own full-height rounded translucent system-blur base, remove its leading divider, and retain an opaque Reduce Transparency fallback
- [x] Remove the workout header's decorative divider and suppress the header's automatic list-section separators
- [x] Extend the workout page color behind the status bar by placing the safe-area background outside the sliding content's clip, without changing header actions
- [x] Build both platform targets and exercise the corrected header, sidebar, source picker, and library search on the existing iPhone 16 running iOS 18.6
- [ ] Human review of the independent sidebar's translucent background and opaque accessibility fallback
- [ ] Human review of the continuous top-safe-area color and separator-free workout header

iOS and macOS Debug builds passed in the isolated owned-change source snapshot. The corrected primary app was installed in place on the existing iOS 18.6 simulator. Native interaction exercised opening the sidebar, its source picker, filtering the existing library, and closing search. Rendered status-bar and page-background samples both matched the page color, and the existing workout file remained byte-for-byte unchanged. The opaque accessibility fallback and macOS appearance still need human review. Product DOCKS.md updates remain deferred until acceptance.

---

## Cycle 33 — One-Handed Actions and Directional Page Navigation

**Requested by the user; implementation ready for code review, not human-verified.**

- [x] Add an angled leftward reveal for an action shelf at the swipe height, with a faded curved base, overflow scrolling, cancellation, and dismissal
- [x] Reuse the existing orange controls and real actions on Home, AI Coach, Analytics, Profile, Settings, Database, exercise/category details, History, Workouts, Schedule, and the workout editor
- [x] Move original action controls out of the way while the shelf is revealed, preserve menu-backed actions, and provide accessible reveal/dismiss and reel adjustment
- [x] Exclude Maps and preserve the workout music edge gesture and modal presentation ownership
- [x] Add distinct reveal, threshold, settle, selection, and dismissal haptics, plus feedback when the navigation menu changes pages
- [x] Replace Home's toolbar buttons with the shared scroll-expanding orange controls, including its Add Widget and Done editing states
- [x] Remove leftward page switching; rightward edge swipes can only move to the previous page, with cancellation on reversal and no wrap from the first page
- [x] Pass eight retained gesture-boundary regressions and build the final merged iOS Simulator and macOS targets
- [ ] Human acceptance of the code changes; interaction feel and physical-device haptics are not marked verified

The final builds include the concurrent committed workout-player changes while preserving unrelated working-tree edits and deleted app-entry files. The package-resolution stall was traced to Keychain authorization for a public binary dependency; the build used Xcode's documented non-Keychain package authorization option. Existing deprecation and concurrency warnings remain.

Native probing and screenshots stopped at the user's request. The final Home and directional-navigation revisions received code-only checks. An attempted installation could not proceed because the previously running iPhone 16 was shut down; device enumeration showed no booted simulators, so no additional simulator was started. The temporary Reachability QA app remains on that shut-down simulator; no user app data was removed. Product DOCKS.md updates remain deferred until acceptance.

### Maps bottom pane and temporary navigation overlay — 2026-10-19

- [x] Dock the Maps main pane at the bottom without reserving space for the hidden menu; keep its content, sibling panes, and compact music player clear of the safe area
- [x] Keep the full navigation menu over Maps for two idle seconds after navigating there, then slide it downward; pause dismissal during menu interaction or editing and restart the grace period after release
- [x] Reveal the navigation menu above the Maps pane with an upward swipe from the bottom edge, without leaving Maps or treating ordinary pane scrolling as a reveal
- [x] Build iOS Simulator and macOS, pass 13 focused navigation regressions and three pane geometry regressions, and run a headless native navigation-layout smoke
- [ ] Human acceptance of Maps pane placement, bottom-edge reveal, menu overlay timing, and the slide-down transition

Both platform builds passed in a task-only source snapshot. The native smoke measured the real navigation container with a full-height Maps content area and zero menu reserve, while Home retained its normal 96-point reserve. The pane geometry cases ran unchanged against the production calculation extracted from its iOS-only wrapper. No simulator interactions, screenshots, or physical-device gesture checks were performed. Final animation feel and device appearance remain for human review; existing build warnings remain. Product DOCKS.md updates await acceptance.

---

## Cycle 34 — Unified Database, Workout, and AI Surfaces

**Requested by the user; implementation ready for code review, not human-verified.**

- [x] Give opening chevrons a defined inset-button appearance while retaining the existing navigation links and real hierarchy-expansion buttons
- [x] Apply the shared charcoal card surface and soft border to database grid/list cards and workout cards, statistics, and the weekly goal
- [x] Unify database/workout selectors and related controls, with orange selection accents, explicit accessibility labels, and minimum 44-point control targets
- [x] Improve the AI conversation header, message layout, empty state, session rows, and composer without replacing the existing AI service or persistence
- [x] Connect suggested AI prompts to the editable draft and place reviewable tool approvals above the composer rather than over the conversation
- [x] Preserve Home's source files and existing shared style implementations; the new control styles are opt-in
- [x] Build the isolated task-only iOS Simulator and macOS targets and run eight headless native control-layout checks
- [ ] Human acceptance of these code changes; visual appearance and interaction feel are not marked verified

Both platform builds passed using the committed app entry points, preserving unrelated working-tree changes. The headless macOS smoke instantiated the actual selector, opening-handle, and inset-control views and checked their layout at two requested text-size environments. macOS kept the same measured control sizes, so this is not evidence of iOS accessibility-size rendering. No simulator interactions, screenshots, live AI requests, or device haptic checks were performed. Existing build warnings remain. Product DOCKS.md updates remain deferred until acceptance.

### Minimal surfaces and original glass controls — 2026-10-18

- [x] Replace the new outlined-gradient selectors with solid orange selected fills and quiet neutral unselected surfaces
- [x] Flatten Database, Workouts, and AI cards; remove nested workout metric boxes and AI prompt boxes while retaining their real actions
- [x] Give the workout editor calm dark section/set/rest surfaces and restrained orange actions while retaining its existing hierarchy, header controls, progress cues, editing, drag/reorder, and music entry
- [x] Remove Schedule's redundant viewport clamp and allow the shared primary scroll surface to render behind the curved navigation menu, retaining its reserved bottom clearance and actual arc
- [x] Remove decorative page/header lines from Home, Schedule, Database, Workouts, Analytics, the workout picker/browser, and the music library, including their unused separator height
- [x] Restore the existing private-glass implementation to expandable page and workout-header buttons, keeping Reduce Transparency and unavailable-renderer fallbacks
- [x] Build iOS Simulator and macOS and run a headless native smoke for selected/unselected control sizes, expanded/collapsed glass controls, arc coverage, and the actual unclipped scroll viewport
- [ ] Human acceptance of the revised styling, editor balance, curved menu underlap, and restored glass appearance

The isolated task-only iOS and macOS builds passed. The native smoke measured 44-point selectors, 108-point expanded and 48-point compact glass controls, correct transparent-above-arc and bottom-safe-area geometry, and a real scroll viewport with both scroll and clip views unclipped. macOS hosted the smoke in an unshown window; no screenshots or simulator interactions were used. This verifies layout and layer configuration, not final iOS appearance, interaction feel, or private-glass frame rate. Existing build warnings remain. Original Home content/card styling and semantic workout rails and timeline guides remain unchanged. Product documentation awaits acceptance.

### Expanding titles, floating Maps pane, and custom-workout fields — 2026-10-19

- [x] Grow Home's title from a stable top edge and move it toward the center as its normal or Add/Done controls expand
- [x] Apply the same measured title transition to Workouts, Database, Schedule, and the workout editor; keep long names within two lines and move compact controls below titles when needed
- [x] Restore Maps' floating bottom safe-area/player gap without restoring the hidden navigation menu's layout reserve; keep true MAX edge-to-edge
- [x] Give every main-pane content state the recovered usable space, remove clearance for invisible map controls, scale the compact content minimum with text size, and allow short Start content to scroll
- [x] Replace the custom-workout sheet's stock grouped fields with flat dark fields, persistent labels, orange focus/toggles, keyboard dismissal, and the existing save, optional time/duration, repeat, and validation behavior
- [x] Use a shared modest corner radius for standard selection, inset, toolbar, and expanding-header controls while retaining orange glass, disabled states, and native touch targets
- [x] Build iOS Simulator and macOS, pass 17 focused pane/navigation regressions, and run 50 headless native header layouts plus four actual custom-form layouts
- [ ] Human acceptance of Home and all expanding titles, Maps floating clearance and content sizing across every pane view, custom-workout fields, and less-rounded buttons

This supersedes the earlier docked Maps placement, not its two-idle-second navigation overlay or bottom-edge reveal. Checks used the task-only source snapshot with committed app entry points, preserving unrelated edits and deletions. Native headers stayed top-anchored, grew, centered, and avoided their controls at endpoints and intermediate progress, including narrow widths and long names. Custom-form checks covered empty and optional-time/duration configurations; macOS expanded the narrow duration configuration to its native 352-point minimum. macOS did not enlarge measured fonts under the requested accessibility text environments, so iOS accessibility-size appearance is not claimed. No screenshots, simulator interactions, save actions, or physical-device gesture checks were performed. Existing build warnings remain; product DOCKS.md updates await acceptance.

### Straight navigation default and original Home controls — 2026-10-19

- [x] Start Home and every normal destination with the straight menu, rather than an arch; keep expansion transient during menu interaction or editing and collapse again on release
- [x] Persist a top or bottom menu position in the existing editor and mirror the arc, reels, editor/catalog placement, outward dismissal, and restore affordance
- [x] Constrain the real page viewport to the menu's occupied height so Ranked actions, multiple bottom rows, and the live-workout status widget keep usable clearance
- [x] Preserve Maps' zero menu reserve, temporary two-idle-second overlay, and bottom-edge reveal
- [x] Restore the pre-change circular/capsule button shapes and Home's original small-title/control arrangement, retaining minimum 44-point touch areas and bounded expanding-control labels
- [x] Pass 20 focused navigation regressions and 126 headless native layout/state checks across both menu edges and three viewport sizes
- [ ] Human acceptance of the straight default, original Home controls, page clearance, top/bottom placement, and animation/gesture feel

The original-button request supersedes the pending Maps-style restyle and the earlier less-rounded/Home-title changes above; other pages retain their measured headers. Both iOS Simulator and macOS builds passed for these corrections. The native smoke covered Home's restored header at expanded, intermediate, and compact sizes, real Ranked actions, dense content rows, global collapse, the editor/catalog, saved position, and hide/restore. It used an unshown macOS window and the current OS Reduce Motion setting without changing accessibility preferences. The checked iOS app was installed and launched in place on the existing iPhone 16 simulator. No screenshots or simulator gestures were used. Final iOS appearance, accessibility-size rendering, and motion feel remain for human review; product DOCKS.md updates await acceptance.

### Maps-style controls and obstruction-aware arched navigation — 2026-10-19

- [x] Use one Maps-style glass renderer for action controls, with native supported-system glass, older-system material, a white rim, Reduce Transparency fallback, disabled feedback, and minimum touch targets
- [x] Keep icon-only controls circular and give wide or text actions rounded-rectangle bases instead of capsules across the shared styles and their page consumers
- [x] Use the deeper neon-orange accent #FF6A00 consistently for action controls while preserving destructive and other semantic colors
- [x] Increase the painted Done bases to the shared 44-point toolbar, 52-point wide-action, and 60-point completion sizes, center their labels, and preserve configured minimum height under compression
- [x] Default normal destinations to the arch and compact only for measured navigation-edge obstruction; protect visible primary scroll actions, ignore ordinary or entirely offscreen scroll rows and unrelated inner clipping, and keep the fallback stable through its own reflow
- [x] Observe clearance at the stable navigation root, re-evaluate after relevant page, viewport, text-size, placement, or control changes, and restore the arch when protected controls disappear
- [x] Preserve saved top/bottom placement, interaction/editor expansion, Maps' zero reserve, two-idle-second overlay, and existing bottom-edge reveal
- [x] Remove the competing private glass renderer and unused LiquidGlassKit dependency from both Xcode targets, package resolution, and the project generator
- [x] Build iOS Simulator and macOS, pass 27 focused navigation regressions, and run 37 headless native control/clearance checks against the actual compiled app module
- [ ] Human acceptance of the Maps-style surfaces, circular icons, rectangular actions, deeper orange, taller Done bases, and obstruction-only menu compaction at both edges

This request supersedes the straight-default and original circle/capsule treatment above; Home's information arrangement is not redesigned. Native checks exercised both menu edges, fixed and partly clipped scroll actions, offscreen and inner-scroll exclusions, stable compaction and restoration, Maps visibility/reserve, viewport/text-environment changes, 44/52/60-point control geometry, compressed tall bases, centered Done labels, and the runtime orange value. Checks used an unshown macOS window, the current OS Reduce Motion setting, and isolated preferences; no screenshots, simulator gestures, or accessibility-preference changes were used. The iOS 16 scroll-view measurement fallback compiled but was not exercised on an iOS 16 runtime. Final iOS appearance, accessibility-size rendering, and motion feel remain for human review. Unrelated local Ranked/profile work, other edits, and deleted app entry points or feature documents are preserved outside this change. Product-document updates await human acceptance; no next prompt is needed for this slice.

---

## Cycle 35 — Floating Widget Snapping and Media Comments

**Requested by the user on 2026-10-18; implementation ready for code review, not human-verified.**

- [x] Give floating workout and music controls a translucent native Gaussian-blurred material base, with an opaque Reduce Transparency fallback
- [x] Let both widgets follow a drag and snap to the nearest allowed top/bottom corner, preserving safe-area/navigation clearance and keeping the music widget below the measured player header
- [x] Prevent dragging from firing the widget's buttons; retain explicit music minimization, compact-widget movement, expansion, and accessibility movement actions
- [x] Persist one editable comment per Database image/video filename, preserving old manifests, reordered attachments, unrelated page fields, and other attachments' comments
- [x] Add a compact Telegram-style growing native comment editor with live minimal-Markdown rendering, preserved line breaks, web-link insertion, clearing, unsaved-change confirmation, and save-error handling
- [x] Show saved captions beneath the selected media in Database, workout previews, and live-workout attachment viewers, with comment indicators on thumbnails and bounded scrolling for long captions
- [x] Pass iOS Simulator and macOS builds and three isolated storage regressions covering reload/reorder, removal/clearing/stale attachments, and old-manifest decoding
- [x] Exercise real photo/video editing, Return-key line breaks, link insertion, persistence across app reload, caption rendering in the live workout, and opening the expected web destination on iPhone 16 with iOS 18.6
- [x] Exercise both widgets' top/bottom snapping, non-triggering drag releases, and compact music movement/expansion; run the actual placement helper against corner, clamp, resize, and zero-travel boundaries
- [x] Remove the temporary page, video, workout, browser tab, and test trash entries; preserve original page/workout file hashes and confirm the original resume checkpoint is offered after relaunch
- [ ] Human acceptance of the blurred surfaces, snapping feel, attachment-comment scope, editor, and workout caption presentation

The focused runtime check caught and fixed Return dismissing the original text field, a drag also triggering its button, and unnecessarily reserved caption-footer space. Builds used an isolated committed-source worktree plus only this task's changes, preserving unrelated working-tree edits and deleted app entry points. macOS received a build check, not an interactive UI check. Physical-device behavior and accessibility-setting variants were not exercised. Existing deprecation/concurrency warnings remain. Product DOCKS.md updates await acceptance; no next implementation prompt is needed for this request.

### Exercise how-to UX demo — 2026-10-19

- [x] Create `UX Demo - Exercise How-To` in the existing iPhone 16 simulator, with six linked exercise pages grouped under `UX Demo Exercises`: Bodyweight Squat, Push-Up, Walking Lunge, Glute Bridge, Forearm Plank, and Dead Bug
- [x] Give each exercise a randomly selected cover pose, two saved local reference photos, concise form cues, step-by-step guidance, and independent setup/movement photo comments
- [x] Check all six workout/page links, twelve local photos and their comments, and persisted guides; preserve every pre-existing workout, page, and history file
- [ ] Exercise the demo's how-to preview in the iPhone app after CoreSimulator UI recovery
- [ ] Human review of the demo workout and exercise-preview UX

The demo was created through the real TimeMasterCore storage APIs, without app source changes or replacing the existing resume checkpoint. It is saved in this simulator's app data, not distributed to another device. App launch and accessibility inspection became unavailable during the preview check; simulator restart attempts did not restore usable UI, and the device was not erased. The preview interaction is not marked verified. Exercise instructions and twelve photos come from the public-domain [free-exercise-db](https://github.com/yuhonas/free-exercise-db), released under [The Unlicense](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE.md).

---

## Cycle 36 — Ranked Battle Lobby and Sculptural Athlete

**Requested by the user on 2026-10-19; ready for human code and visual review, not human-verified.**

- [x] Replace the exercise-picker landing screen with a character-led battle lobby and a prominent orange Battle or Practice action
- [x] Move battle-mode covers, movement families, and individual movement selection into a connected loadout sheet with saved local selections
- [x] Open a distinct arena preview from the lobby and retain working Profile, Settings, rank-collection, close, and return actions
- [x] Add the Core family with forearm plank, high plank, left side plank, and right side plank, using hold-time rules instead of rep-count rules
- [x] Add independently editable overall and movement-specific local Elo display levels, preserving existing profile identity, posts, cosmetics, backup preferences, and independent left/right plank levels
- [x] Reject invalid saved levels without overwriting their original storage and preserve existing navigation order and the user's later removal of Ranked
- [x] Generate the lobby hero, two mode covers, fourteen movement illustrations, and six geometric tier badges with Fgen
- [x] Replace every bear character with an approachable ivory-marble athlete, fluted lower-face mask, black clothing, and orange accents
- [x] Apply the latest reference's completely bald, smooth rounded head throughout the hero, both mode covers, and every movement illustration
- [x] Build the exact publication-tree iOS Simulator and macOS targets and pass five existing ranked persistence, backup, validation, and navigation regressions
- [x] Exercise the real native lobby, Core loadout, hold-time arena, solo practice, profile Elo save and reload, independent side-plank levels, and profile-to-Core return
- [ ] Human acceptance of the bald masked athlete, artwork consistency, battle-lobby hierarchy, loadout, arena preview, Core choices, and editable local Elo levels

The native interaction smoke used the production SwiftUI views and stores in an isolated macOS host; it also rendered phone-sized, larger-text, and desktop-sized layouts. iOS received a build check, not a successful interactive simulator check: the earlier CoreSimulator test run timed out. Both final app targets were built from the same scoped publication tree, including the checked-in Xcode project and committed app entry points. Existing deprecation and concurrency warnings remain.

This is the requested UI-only Ranked slice. Matchmaking, camera-based rep counting, plank validation, competitive rating calculation, and online leaderboards are not connected; the arena states that it is a preview and awards no Elo. The editable values are local display levels, not verified competitive ratings. Unrelated source edits, deleted app entry points, and concurrent Profile styling remain untouched in the working tree. Product DOCKS.md updates await human acceptance; no next implementation prompt is needed for this slice.

### Ranked polish, shared buttons, and generated navigation icon — 2026-10-19

- [x] Keep the lobby action and preview notice above the shared navigation, with a scrolling fallback for larger accessibility text
- [x] Refine the lobby identity, movement loadout, selected mode and family feedback, and adaptive arena panels without changing the bald athlete artwork or preview-only battle scope
- [x] Improve the rank collection hierarchy, overall-level summary, tier cards, and bottom edit action
- [x] Keep all six Elo presets visible without horizontal scrolling and retain clear, fine-tune, unsaved-change, save-error, and read-only behavior
- [x] Replace the Ranked-only action style and circular Settings/Close treatments with the existing shared action, toolbar, and selection styles; use Profile's rasterization-safe shared primary style inside its collapsing content
- [x] Generate a new shield-and-double-chevron menu icon with Fgen, register its transparent template asset, and migrate normal, catalog, lifted, and source-choice rendering to typed system-or-asset icons
- [x] Build the scoped iOS Simulator and macOS app targets and pass all five existing Ranked profile, backup, invalid-level, and navigation regressions
- [x] Exercise native lobby, loadout, arena, collection, editor, Profile Ranked action, shared buttons, larger-text scrolling, and the new icon's selected, unselected, editing, and catalog states
- [ ] Human acceptance of the polished Ranked layouts, shared button appearance, larger-text behavior, and generated menu icon

Both app targets built from the scoped publication source, preserving unrelated edits and deleted app entry points. The five existing regression cases ran unchanged against the production profile/ranked models, persistence, and navigation model declarations in an isolated macOS fixture. Native iPhone 16 Pro review used an isolated app identity on iOS 18.6, leaving the production app's data untouched. Existing build warnings remain. The updated Ranked screen is open for human review; competitive scoring, camera tracking, matchmaking, and online leaderboards remain outside this UI-only slice. Product DOCKS.md updates await acceptance; no next implementation prompt is needed.

### Complete Ranked — Real Tracking and Production Completion Handoff

**Incomplete. The user's latest direction requires real camera/movement tracking and the complete working competitive feature, not another UI-only pass. Earlier UI-only exclusions are superseded for the continuation. The font messages were explicitly withdrawn from this task.**

- [x] Connect an initial illustrated setup, search, opponent-ready, countdown, duel, provisional-result, and match-details flow, with an in-memory recent-round list; this is not real tracking or competition
- [x] Register the new model and native screens in both app targets and replace the obsolete standalone arena
- [x] Build the then-current iOS Simulator and macOS source in a disposable copy, recovering the already-deleted app bootstrap only in that copy
- [x] Exercise the native iPhone 16 happy path, running timer, result/details/Close, recent-round row, one slot consumed at Go, and no additional slot consumed on pre-Go cancellation using isolated app data
- [x] Write the user-requested comprehensive continuation prompt: `prompts/ranked/Ranked-phase-2-production-completion.md`
- [x] Implement real camera capture, permissions, usable framing, calibration, lifecycle, and pose processing
  - [x] Implement actual per-variation repetition validation, including stance, full range, paused/tempo phases, and no counting from elapsed time
  - [x] Implement longest valid continuous-hold scoring for each Core movement, including independent left and right side planks
  - [ ] Implement and evaluate advanced movement tracking, inverted poses, visible-assistance handling, and honest insufficient-evidence behavior
    - [x] Implement inverted-pose fallback, hand-contact/support estimates and explicit unavailability of advanced rated matches when assistance cannot be verified
    - [ ] Evaluate real athlete recordings on physical devices, including advanced support/assistance and camera accuracy before enabling advanced competition
- [x] Implement real account/session integration and authoritative persisted competitive data
  - [x] Implement exercise-specific skill-based matchmaking, real cancellation/readiness, synchronized countdown, live opponent state, and reconnect/forfeit handling
  - [x] Implement real result verification, exactly-once finalization, and server-owned exercise-specific Elo
  - [x] Enforce separate push-up/squat ten-match rolling four-hour allowances across variations and devices
  - [x] Implement actual exercise leaderboards, earned rank collection, persistent recent matches, and match details
  - [x] Migrate local editable-level callers and backups safely; never promote manually chosen values into earned Elo
- [x] Finish the visual-first native UI, compact normal-phone duel HUD, real camera guidance, and matching artwork for the four advanced additions
- [x] Remove simulated scores/opponents/results, preview-state controls, sample standings, obsolete demo models, and test-UI notices through the real production cutover
- [ ] Exercise real camera input and two authenticated participants, persistence/recovery/security boundaries, remaining native states, and relevant regressions; deploy the real service when authorized
  - [x] Exercise server authorization, evidence boundaries, exact-once ratings, family allowances and pagination with twenty focused regressions
  - [x] Complete a real-time sixty-second two-account HTTP round using derived-vector fixtures, then restart the service and recover the persisted sessions, result, rating and history
  - [x] Exercise the actual iPhone lobby and Practice setup, honest camera-unavailable state with disabled Start, real account creation and sign-in, secure Keychain restore after relaunch and sign-out
  - [x] Run the fifteen focused native tracking, legacy-profile preservation and existing Profile regressions
  - [x] Build both arm64 native targets and exercise ordinary and accessibility-sized HUD components with persisted service results, an inactive camera and reachable feedback
  - [ ] Complete physical-camera rounds with two real athletes, including movement accuracy, native Duel recovery, assistance limitations and iOS/macOS camera/focus/lifecycle behavior
  - [ ] Deploy to an authorized persistent HTTPS service and set the native build's Ranked service address
- [ ] Human review and acceptance of the complete Ranked feature

The Phase 2 cutover replaces the earlier demo paths with AVFoundation/Vision tracking, an authenticated FastAPI/SQLite service, server-owned match state and ratings, real paginated competition data, and four generated movement assets. Service evidence is derived joint data, never images or video. Advanced diamond, handstand and planche competition is explicitly unavailable until recording-based hand/support validation is established; on-device Practice is an estimate, not a claim of assistance-proof tracking.

The service's twenty focused regressions pass. A separate real-time two-account HTTP scenario completed the shared sixty-second round with derived-vector fixtures, identical final results, exactly one Elo update and one history entry per participant, and the correct family allowances; those results survived an actual service restart. The final iPhone run passes all fifteen permanent regressions and two disposable native smokes. Real registration/sign-in, Keychain-backed relaunch recovery and sign-out were exercised against the local service. Simulator ad-hoc signing is now configured for the app's Keychain entitlement instead of relying on unsigned execution.

Both native targets build for arm64 from the current working source in a disposable copy, with the historical app bootstrap recovered only there; the already-deleted live app entry points and unrelated font/Profile work remain untouched. macOS startup opened an isolated native window, but Apple Events automation was not authorized, so new macOS Ranked interaction, camera, focus and lifecycle behavior is not claimed. The ordinary HUD and accessibility reflow were rendered using real persisted result values with the camera inactive, not a fake production match.

Camera accuracy, hidden-assistance detection and full physical-camera competition are still unproved. Joint evidence is motion validation, not proof against a modified client or replay. Advanced rated movements remain unavailable. Public deployment still requires an authorized persistent HTTPS host/domain and native build URL; Docker/Compose configuration validates, but a container build and public TLS deployment were not exercised because the Docker engine is stopped and no host authorization exists. Physical-device recordings remain unavailable. Product DOCKS updates and human acceptance remain pending; this is a code-review handoff, not a complete-production or human-approval claim.

### Solo camera rounds, local sign-in, and earned identity

- [x] Add a double-clickable local Ranked service launcher with persistent accounts and match data; connect Debug Simulator and macOS builds to loopback without weakening physical-device or Release HTTPS requirements
- [x] Connect keyboard submission and account switching to real authentication, clearing previous-account ratings before refreshing the new identity
- [x] Save completed, ended-early, and interrupted sixty-second Practice rounds with exact movement, validated score, duration, date, account ownership, and tracking-rule version
- [x] Drain queued camera tracking before finalizing the score, serialize overlapping finish paths, skip pre-Go cancellations, and preserve unsaved results for retry
- [x] Expose account-isolated Practice history and round details; keep solo rounds separate from competitive Elo and match allowances
- [x] Display the selected movement's earned Elo above the signed-in account name in the lobby and preserve Profile's real exact-movement earned-rating binding
- [x] Pass eighteen permanent native tracking, persistence, and Profile regressions plus two disposable derived-pose scenarios covering a real-time sixty-second round and unexpected repeated dismissal
- [x] Exercise actual native sign-in with keyboard Return, Keychain-backed relaunch recovery, Profile earned Elo, Elo-above-name ordering, Practice camera-unavailable gating, saved-history details, sign-out, and guest-history isolation
- [x] Complete a separate real-time two-account service round and verify exactly-once earned Elo for the native account review
- [ ] Human review of login, solo rounds, saved history, and earned Elo presentation
- [ ] Complete physical-camera push-up rounds and evaluate real-athlete accuracy; deploy an authorized persistent HTTPS endpoint before physical-iPhone sign-in

The local service runs through `start_ranked_server.command` on loopback port 8765 and stores its database outside the repository. The native real-time fixture scenario exercised the production clock, tracker, controller, and persistence: a completed round, pre-Go cancellation, repeated exit, and an interrupted round. A second smoke preserved both validated fixture reps through unexpected repeated dismissal and saved exactly one interrupted result. Neither scenario exercised camera images. The eighteen permanent cases passed again after integration with current main; both disposable smokes passed separately and were removed from source.

Native account review used a separate Simulator and app identity with isolated documents and Keychain. Its displayed 1,020 Elo came from a real sixty-second service match with explicitly labeled derived-pose fixture accounts, not a fabricated production rank. A separate local history fixture exercised saved-result rendering only. The current iOS and macOS source built in disposable copies; already-deleted app entry points were recovered only there. Unrelated Profile, font, shared-control, and navigation work remains preserved. Product DOCKS updates await human acceptance. Physical camera accuracy and public iPhone connectivity are not claimed.

### Sport Elo crest and interaction-first native UI

- [x] Replace the right-hand Ranks indicator with an epic sport-specific earned-Elo crest; remove the standalone Elo row and put the username below the badges
- [x] Keep exact-movement account ratings, Profile-entry restoration, sign-in access, and local profile identity intact
- [x] Use the app's shared icon controls for Profile verification, collectibles, compose, settings, edit and actions; replace the text menu with a themed action grid
- [x] Generate the epic crest with fgen and compose it with the exact movement artwork and live native Elo
- [x] Refine Profile name and Elo typography with soft vertical ink fades, deliberate spacing, a smaller tracked handle and unit, and a non-overlapping collapse crossfade; keep the existing font family and Reduce Motion behavior
- [x] Replace prose-led Ranked lobby, loadout, camera setup, search, ready, countdown, live HUD, results, ratings, standings and history surfaces with icon interactions, numeric values and units
- [x] Preserve private account entry, real camera permission/calibration, service-owned matches and Elo, exercise separation, recovery, and readable on-demand safety/error details
- [x] Exercise the actual redesigned native surfaces and focused regressions
- [ ] Human review of the epic Elo badge, native controls, menus and interaction-first Ranked

The standalone Profile Elo row and prose-heavy presentation were rejected by the user. The correction replaces the existing Ranks side indicator rather than adding a third indicator. Unplaced accounts display no invented score. Public sign-in still requires the authorized HTTPS deployment tracked above. Solo Practice stays local and unrated; real push-up accuracy still requires the physical-device validation tracked above.

The final integration run passed eighteen existing tracking, Practice-persistence, legacy-rating, navigation, and Profile regressions plus two disposable native interaction smokes. The isolated iPhone 16 run exercised the Profile action grid, keyboard sign-in, earned-Elo crest, exact-movement Profile-to-Ranked navigation and restoration, rules, standings, separate Practice history, server allowance, movement selection, and camera-unavailable setup with Start disabled. Ordinary and largest-accessibility Profile rendering were inspected, including non-overlapping expanded and collapsed name/crest geometry. The displayed 1,020 Elo and 9/10 push-up allowance came from a real server-owned forfeit using explicitly labeled derived-pose calibration fixtures, not physical camera input or invented production ratings.

Both arm64 native targets compiled from the committed baseline plus this scoped UI work in a disposable copy. The already-deleted app entry points were recovered only in that copy; unrelated live edits and production account data remain untouched. macOS received a build check, not an interaction check. Physical-camera accuracy, full native live-duel recovery, advanced rated verification, and public HTTPS deployment remain subject to the limits and pending work above. Product documentation and human acceptance remain pending.

### Rust server cutover and shared tracking selectors

- [x] Replace the real Ranked Python runtime with a Rust/Axum/Tokio executable, preserving the native `/v1` contract, SQLite records, existing scrypt passwords, sessions, evidence retries, scoring, Elo, allowances, history, and privacy
- [x] Keep SQLite work on one bounded database worker and expensive password hashing off networking threads; use fixed joint storage, cached queries, and active-match/evidence-retention indexes without changing the joint-only batched transfer format
- [x] Migrate the persistent local service on loopback port 8765 to Rust without inserting review accounts or changing existing account, session, rating, match, participant, evidence, or allowance records; retain a private pre-cutover SQLite backup
- [x] Replace the Python launcher and container runtime, require explicitly trusted HTTPS proxy headers behind the private Caddy network, and remove obsolete Python modules and dependency manifests
- [x] Preserve account-free, server-independent native Practice and expose pure Rust pose assessment/tracking for a later camera-only API; do not add a test-only server or speculative serverless endpoint
- [x] Apply TimeMaster's shared selection/action styles to movement tiles, family choices, mode choices, and the lobby selector entry, preserving selected-state checkmarks, accessible names, and persisted selections
- [x] Pass 31 Rust behavior regressions, strict Clippy checks, the release build, deployment-configuration validation, and a real-time two-account HTTP round followed by actual process restart and session rotation
- [x] Build the iOS Simulator app and exercise all three movement families, mode changes, saved selection after relaunch, guest Practice with the server stopped, disabled Start with no camera, real native sign-in against Rust, earned-data decoding, Keychain recovery, and sign-out
- [ ] Human review of the Rust service cutover, deployment changes, camera-only boundary, and themed selectors

The Rust service supersedes the FastAPI runtime described in the earlier Phase 2 handoff. Its macOS arm64 release executable measured approximately 3.1 MB; the final local process measured about 38 MiB resident memory after startup. A separate keep-alive loop measured a roughly 0.20 ms median and 0.27 ms 95th-percentile state response on this machine. These are local smoke measurements, not production load or cross-platform benchmarks. Password hashing intentionally retains the existing memory-hard scrypt policy.

The real-time service round used derived-joint fixtures, not camera images: 631 frames per athlete, a 2–1 result, ratings of 1,020 and 980, and one push-up allowance charged per participant. The finalized result, history, ratings, allowances, existing sessions, and refresh-token rotation survived a process restart. Native review used a separate Simulator with isolated app data; no review account was added to the existing persistent database. That database passed integrity checks and retained its original records through the cutover.

The iOS build used a disposable copy with the user's deleted app entry points recovered only there. Existing native warnings remain; this slice does not claim a new macOS UI run or a successful rerun of the interrupted native test runner. Physical-camera accuracy, advanced competitive verification, container execution, public HTTPS deployment, and human acceptance remain pending as recorded above. The later camera-only/serverless API is intentionally not implemented yet. No next prompt is needed for this requested slice; product DOCKS updates await human acceptance.

### Ranked labels and conventional sign-in — 2026-10-20

**User direction:** keep the approved visual layout, explain the icons and movement artwork with concise visible text, make sign-in conventional, add explicitly unavailable Apple and Google sign-in placeholders, and use bolder primary labels with smaller supporting text.

- [x] Add visible action labels, movement names and setup cues, mode and family names, scoring units, rank names, status explanations, and readable recovery messages across Ranked without redesigning the artwork or shared controls
- [x] Use a labeled primary sign-in button, persistent login/password labels, create-account selection, and clearly disabled Apple/Google placeholders; preserve the real account, privacy, secure-session, keyboard, and sign-out paths
- [x] Apply the existing bold Inter hierarchy to headings, movement names, field labels, and primary actions, with smaller secondary captions and guidance
- [x] Build the scoped iOS Simulator and macOS targets and exercise actual selection, icon guidance, login, recovery, and larger-text layouts with isolated app data and a separate real Rust service
- [ ] Human review of the added explanations, sign-in form, provider placeholders, and typography

Apple and Google are requested visual placeholders, not connected authentication providers. The Google mark uses the unmodified [official Google sign-in asset](https://developers.google.com/identity/branding-guidelines); the Apple mark uses the native system symbol. Existing account/password authentication remains the functional path. Physical-camera accuracy, advanced rated verification, and authorized public HTTPS deployment remain separate pending requirements above.

Engineering checks used a disposable copy of the committed app baseline plus the scoped changes, isolated Simulator data, and a separate temporary Rust database. Both native targets compiled. iPhone smoke checks exercised movement/mode selection, named guidance/ranks/history/leaderboard controls, camera-unavailable recovery, real account creation, rejected-password recovery without clearing the login, sign-out/sign-in, secure-session restoration across relaunch, and large-text forms. The final large-text test reported one pass and zero failures, but Xcode did not finish runner shutdown and its command timed out. macOS was build-checked, not interactively camera-tested. Existing compiler/toolchain warnings remain. No production data was changed. Human review is pending; product DOCKS remain unchanged until acceptance, and no next prompt is needed.

---

## Cycle 37 — Direct EverStore Profile, Collectibles, Verification, and Settings Import

**User direction: copy the original components, then change only TimeMaster fonts, button/theme styling, required local data bindings, and native platform boundaries. The earlier rewritten UI was rejected. Human visual approval comes before further functional testing.**

- [x] Import the original Profile cover, avatar/header geometry, collapsing scaffold, achievement shield, tabs, and controls while retaining the requested local-profile additions and existing Ranked integration
- [x] Import the original collectible shop, carousels, artwork, search, collection, and expanding detail presentation with real local save/apply/reset actions and no blockchain, transactions, prices, or ownership claims
- [x] Import the original verification progress, qualification, plan, benefit, preview, and celebration components; keep the difficult free milestone and label paid-tier appearances as local Preview only
- [x] Import the original Settings navigation, rows, sections, profile settings, and privacy presentation while preserving every existing TimeMaster setting and real destination
- [x] Stop functional testing of the rejected UI and remove only the temporary profile data and three profile photos created during the earlier smoke
- [x] Remove the imported circling button-highlight animation while preserving the static button design and normal press feedback
- [x] Keep exactly two Profile side indicators total: one achievement placeholder with overflow inside the same shield, and the existing local Elo summary as compact plain text; remove the separate Elo row
- [x] Present the actual imported Profile, collectible, verification, and Settings screens for human visual approval
- [ ] Human acceptance of the imported Profile UI
- [ ] Human acceptance of the imported collectible UI
- [ ] Human acceptance of the imported verification UI
- [ ] Human acceptance of the imported Settings UI
- [ ] Resume focused functional checks only after the user approves the UI

Product DOCKS.md changes remain deferred until the user accepts the resulting behavior. Compilation and opening the screens for review do not constitute human approval. Existing workouts, history, database media, preferences, resume data, unrelated source edits, and the newly published Ranked feature are preserved.

The direct-import iOS review build compiles and the actual Profile, collectible shop, verification progress and plan previews, and Settings screens have been opened for visual review. The circling button-rim renderer is removed. No further functional tests were run after the visual-approval gate; functional checks and the direct-import macOS check remain pending.

The latest Profile correction is displayed with one side indicator on each side of the avatar. The left indicator retains access to all eight achievement placeholders without an extra overflow shield. The right indicator shows the real local Elo value, or Unplaced when none is set, and retains the existing Ranked navigation.

---

## Cycle 38 — Resume Workout Page

**Requested by the user on 2026-10-19; implementation ready for human review, not human-verified.**

- [x] Replace the sparse full-height prompt with a compact, expandable native sheet using the shared typography, surfaces, and button styles
- [x] Show the real workout name, saved elapsed time, section and set position, phase, exercise name, and checkpoint date
- [x] Keep the checkpoint when closing the sheet or cancelling discard; require explicit confirmation before removing saved progress
- [x] Preserve the checkpoint through sheet dismissal so Resume restores the actual player position and pause state instead of reopening the warm-up picker
- [x] Keep the existing three-minute partial-history rule and explain and disable Resume when the workout is unavailable
- [x] Build the integrated iOS Simulator and macOS targets and exercise exact paused restoration, close, cancellation, confirmed discard, the three-minute history boundary, larger-text scrolling, long titles, and unavailable workouts
- [x] Reload the latest integrated main app with the original saved workout and preserve existing documents and checkpoint data
- [ ] Human acceptance of the Resume Workout layout, shared controls, saved-session details, confirmation, and restored player state

The native smoke used an isolated app-data copy to avoid consuming the original saved session. It reproduced the previous checkpoint-clearing race, then restored the saved section, set, remaining time, elapsed time, phase, and pause state after the fix. A 22-second discard did not create history; a 180-second discard created one partial entry and did not reappear on cold relaunch. The latest integrated main app is open on the new sheet with the original 22-second checkpoint and all 283 existing document files unchanged; the temporary smoke app and its data were removed. macOS received a build check, not an interactive UI check. Existing build warnings remain. Product DOCKS.md changes await human acceptance; no next implementation prompt is needed.

---

## Ribbon Font Specimen — 2026-10-19

**Standalone typography experiment requested by the user; the current generated alphabet was rejected for visible bumps and its overall font design.**

### Batch 1 — Original Five Letters

- [x] Preserve the supplied PNG unchanged in `genesis/REFERENCE/ribbon-font/source.png`
- [x] Trace the original A M N V W and a m n v w silhouettes without redesigning them, retaining their shared scale, lowercase proportions, and internal holes
- [x] Generate installable TTF and cubic-outline OTF files plus a WOFF2 webfont, with only the supplied ten letters and space
- [x] Create `junk/ribbon-font/index.html` with editable words, mama/wanna/Anna/VAN/MAN/AW examples, case controls, size and spacing sliders, fit, guides, inversion, original-image comparison, and font downloads
- [x] Exercise the actual HTML over HTTP and directly from disk, including mobile widths, unsupported and empty input, keyboard-operated sliders, long-text containment, original-image loading, and all three font-file URLs
- [x] Compare both outline formats against all ten source silhouettes; each exceeds 98% pixel overlap and differs only within one original pixel at contour edges
- [ ] Human review of the extracted letterforms, word spacing, and HTML specimen

The reproducible extractor is `junk/ribbon-font/build_font.py`. The reference is byte-identical to the supplied PNG. The browser loaded the actual WOFF2 with no page errors; the preview has no page-wide overflow at 320, 390, and 1440 pixels. Existing app fonts and unrelated working-tree changes are untouched. No app integration or additional letters are included. Product DOCKS.md changes await human acceptance; no next implementation prompt is needed for this request.

### Batch 2 — Three Additional Sheets

- [x] Add F G H I J and f g h i j from the unchanged `source-fghij.png` reference, retaining both detached dots and the g/j descenders
- [x] Add K L O P Q and k l o p q from the unchanged `source-klopq.png` reference, retaining counters, the Q tail, and the p/q descenders
- [x] Add B C D E R and b c d e r from the unchanged `source-bcder.png` reference, retaining all original counters and terminal shapes
- [x] Extend the extractor to combine detached components by sheet column, normalize each sheet with one uniform scale, align non-descending baselines, and reserve enough line-metric depth for the new descenders
- [x] Rebuild TTF, OTF, and WOFF2 version 1.100 with forty supplied letterforms and space; preserve the first batch's outline geometry and spacing exactly
- [x] Update the HTML with twelve word examples, all forty glyphs, accurate supported-input handling, all four original-image comparisons, and a versioned webfont URL
- [x] Exercise the actual HTTP and direct-file previews, every word preset, both case actions, supported and rejected input, native empty-input deletion, keyboard size/spacing, fit, guides, inversion, source loading, and font-file URLs
- [x] Check 320-, 390-, 768-, and 1440-pixel layouts without page or word-card overflow; observe no JavaScript page errors
- [x] Compare all forty glyphs in both outline formats against independent source-image crops, retaining every original component and hole with more than 98% silhouette overlap and contour differences within one source pixel
- [ ] Human review of the three new glyph batches, inter-sheet scale and baseline alignment, descenders, spacing, and expanded HTML specimen

The font now contains A through R plus V and W, in both cases, and space. S T U X Y Z, their lowercase forms, numbers, and punctuation remain unavailable rather than synthesized or substituted. All three new reference copies are byte-identical to the supplied PNGs. Existing app typography is unchanged. Product DOCKS.md changes await human acceptance; no next implementation prompt is needed for this batch.

### Batch 3 — Complete Uppercase and Lowercase Alphabet

- [x] Preserve the final supplied sheet unchanged in `genesis/REFERENCE/ribbon-font/source-stuxyz.png`
- [x] Add S T U X Y Z and s t u x y z using one uniform sheet scale, retaining the original terminals, lowercase t ascender, and lowercase y descender
- [x] Rebuild TTF, cubic-outline OTF, and WOFF2 version 1.200 with all fifty-two ASCII letterforms and space; preserve the previous forty outlines and their spacing exactly
- [x] Open the HTML specimen with TimeMaster in the custom font, add style/STUDY/future/fuzzy/lazy examples, and include mixed-case and all-capital sentences that each contain every letter
- [x] Show the complete uppercase and lowercase alphabet, include the fifth original-image comparison, and retain accurate unsupported-character handling without synthesized numbers, punctuation, or accents
- [x] Exercise the actual HTTP and direct-file previews, all fifteen word/app-name/sentence presets, both case actions, supported and rejected input, native empty-input deletion, keyboard size/spacing, fit, guides, inversion, source loading, and font-file URLs
- [x] Check 320-, 390-, 701-, 768-, and 1440-pixel layouts without page, word-card, or alphabet-cell overflow; observe no JavaScript page errors
- [x] Compare all fifty-two glyphs in both outline formats with independent source crops, preserving every original component and hole with more than 98% silhouette overlap and contour differences within one source pixel
- [ ] Human review of the final twelve glyphs, complete alphabet, TimeMaster wordmark appearance, sentence samples, and spacing

The supplied A–Z and a–z alphabet is now represented in the font. Space is supported; numbers, punctuation, accented letters, and other scripts are not included. The final reference is byte-identical to the supplied PNG, and existing app typography remains unchanged. Product DOCKS.md changes await human acceptance; no next implementation prompt is needed for this batch.

### Batch 4 — Individual M-Based Letter Studies

The user rejected the stylistic mismatch between the separate alphabet sheets, identified the original M as the design master, and explicitly requested one letter per Fgen generation. The first review batch is ten capitals and ten lowercase letters, A–J and a–j; no font rebuild is part of this review batch. The earlier one-image alphabet attempt is discarded.

- [x] Measure the original M's 275 × 175 pixel bounds, 1.571 width-to-height ratio, approximately 22% median interior stroke, and approximately 61° main rising diagonal; preserve the untouched source row and an isolated, proportionally enlarged M reference
- [x] Generate uppercase A–J as individual PNGs with a separate Fgen call per letter and the same original M reference; refine A to retain the original open crossbar
- [x] Generate lowercase a–j as individual PNGs with a separate Fgen call per letter and the same original M reference
- [x] Retain all twenty raw Fgen images and individual prompts, remove gray halos and stray edge pixels from the review PNGs, and preserve the generated bowls, open terminals, and separate i/j dots without stretching or rescaling the letters
- [x] Create `junk/ribbon-font/individual-review.html` with the twenty PNGs, measured master geometry, larger side-by-side M comparisons, keyboard paging, native modal focus isolation, cleaned PNG downloads, and raw-image links
- [x] Link the earlier font preview to the new letter review while leaving all existing TTF, OTF, and WOFF2 bytes unchanged
- [x] Exercise all twenty HTTP image comparisons and raw-image links, native PNG downloading, direct-file loading and navigation, Escape/focus restoration, 320/390/700/768/1440-pixel layouts, and 200% text at 320 pixels; fix modal caption overflow and observe no page errors
- [ ] Human acceptance of the individual letter studies' style continuity, smoothness, stroke weight, and proportions before any font rebuild

The backend returned twenty 1254 × 1254 images despite the requested 1024-square target. Both raw and cleaned versions are retained in `genesis/REFERENCE/ribbon-font/individual-m/`, alongside the untouched source row, the M reference, measured geometry, and every per-letter prompt. The generated D has an open bottom in both versions and remains a human-review decision. Existing app typography and installable font files are unchanged; product DOCKS.md updates and further letter generation await the user's review. No next implementation prompt is needed for this review batch.

#### Word-Combination Hub

- [x] Put a live word composer at the top of `junk/ribbon-font/individual-review.html`, using the twenty actual M-based PNGs rather than mixing in the earlier alphabet; preserve each image's proportions and original vertical placement while cropping empty side margins
- [x] Add editable phrases, uppercase/lowercase actions, eight supported presets, size and letter-spacing sliders, fit, shared-grid guides, explicit unsupported-character feedback, and empty-input handling
- [x] Export repeatable image crop and shared-grid measurements to `genesis/REFERENCE/ribbon-font/individual-m/preview-metrics.js` from the existing individual-letter generation pipeline; support both HTTP and direct-file opening without changing PNGs or font files
- [x] Link the previous font preview directly to the new composition hub and individual-letter inspection sections
- [x] Exercise all eight presets and all twenty images, native typing/case/deletion, unsupported-input recovery, keyboard size/spacing, negative spacing, fit, guides, modal paging/Escape, direct-file navigation, 320/390/768/1440-pixel layouts, 200% text at 320 pixels, and contained long-text scrolling; observe no page errors on HTTP or direct-file pages
- [ ] Human review of the new word combinations, original image alignment, stroke continuity, and spacing before any font rebuild

The composer is an image-based review surface, not a replacement installable font. It supports only A–J, a–j, and spaces from the new batch. Existing app typography, original images, and all earlier TTF, OTF, and WOFF2 files remain unchanged. No next implementation prompt is needed for this hub.

### Batch 5 — Complete M-Based Alphabet and Correct Lowercase Height

The user asked to continue the remaining letters and reported that lowercase forms look almost as tall as capitals. Complete the new alphabet without mixing in the older font. Generate the new uppercase and lowercase raw images as independent batches, then normalize and connect them through the existing shared pipeline. Reuse the original M rather than generating a replacement.

- [x] Complete K–Z with fifteen separate uppercase Fgen generations and the original M source
- [x] Generate k–z with sixteen separate lowercase Fgen calls, using the same original M and explicit shorter-body proportions
- [x] Normalize all review PNGs to a shared 560-pixel capital height, 406-pixel lowercase body, common baseline, proper ascenders and descenders, and separate i/j dots; use uniform scaling without stretching and preserve every raw image
- [x] Connect all fifty-two PNGs to the word hub and individual comparisons, open with TimeMaster, add case-pair and full-alphabet examples, and add a dashed x-height guide
- [x] Exercise the actual complete-alphabet HTTP and direct-file hub, measured case proportions, controls, comparisons, unsupported and empty input, and responsive layouts; commit and push the scoped work
- [ ] Human review of the remaining letter shapes, corrected lowercase proportions, baseline alignment, and word spacing before any installable font rebuild

All fifty-two review PNGs are connected. N, P, and w were regenerated to correct their letter anatomy; the rejected candidates and their submitted prompts are preserved separately. The original M is pixel-identical to the master reference. Looped descenders align by their outer bowls, and y by its upper fork; natural tails receive taller canvases instead of being clipped or compressed. Focused checks exercised all ten word presets, case switching, unsupported-input recovery, empty and space-only text, keyboard size and negative spacing, guides, fit, comparisons, wraparound, Escape, long-text containment, direct-file opening, 320/390/768/1440-pixel layouts, and 200% text at 320 pixels. No page errors were observed. The earlier TTF, OTF, and WOFF2 bytes remain unchanged. This is ready for human review, not an approved typeface; no next prompt is needed for this slice.

### Batch 6 — Ribbon Style Corrections for l and j

The user identified lowercase l and j as outside the original M’s style. Replace their generic near-upright rounded stems and oversized bottom hooks with M-derived oblique ribbons, controlled taper, compact terminal turns, and softly flattened cuts. Keep the existing case heights and baseline placement; preserve the rest of the alphabet and the original M.

- [x] Regenerate lowercase l separately from the original M, using its approximately 61-degree rising direction and restrained rightward terminal
- [x] Regenerate lowercase j separately from the original M, using the same oblique stroke character, a compact leftward descender terminal, and a separate compact dot
- [x] Preserve both rejected raw images, submitted prompts, and normalized previews; update only the two canonical glyphs and their shared composition metrics
- [x] Add focused l/j word examples, exercise the corrected glyphs in the actual HTTP and direct-file hub, and publish the scoped changes
- [ ] Human review of the corrected l and j shapes, word rhythm, dot, and terminal treatment

Both replacements were generated separately with the unchanged original M as their sole image reference. Their measured rising strokes are approximately 63 degrees, replacing the earlier near-upright stems. Case heights, baseline placement, and j’s two separate components are retained. The other fifty normalized letter images and the earlier installable font files remain byte-unchanged. The hub includes jolly and little examples. Focused HTTP and direct-file checks exercised both examples, corrected-image comparisons, keyboard navigation, the raw j link, Escape, desktop and mobile layouts, and 200% text at 320 pixels; no page errors were observed. The rejected raw images, submitted prompts, and normalized previews are retained for comparison. Both letters are ready for human review; no next prompt is needed for this correction.

### Batch 7 — Strict Right-Leaning Ribbon Family

The user rejected the inconsistent direction, crooked stems and handwritten waviness in the preceding alphabet. Keep the original M as the sole image reference and preserve B, D, E and the other fitting forms. Structural stems must be straight and share a forward-right lean; playful movement belongs in controlled bowls, joins and restrained terminal sweeps, not wavy shafts or cursive flourishes.

The user rejected this pass as too strict and reported that its strokes do not match the original M. It is not accepted. Batch 8 supersedes the remaining plan; rejected raw images, exact prompts and intermediate normalized previews are preserved rather than treated as a finished family.

- [ ] Preserve the original M and the sixteen fitting forms ABCDEFGKMOR and acelo without altering their normalized pixels
- [ ] Regenerate uppercase H, I, J, L, N, P, Q, S, T, U, V, W, X, Y and Z individually from the original M
- [ ] Regenerate lowercase b, d, f, g, h, i, j, k, m, n, p, q, r, s, t, u, v, w, x, y and z individually from the original M
  - [ ] Make t’s shaft and crossbar straight, forward-leaning and restrained
  - [ ] Make j’s shaft straight with a compact below-baseline terminal and separate dot on the extended stem axis
  - [ ] Make i’s shaft straight with its separate dot on the same forward-rising axis
- [ ] Replace the shared prompt’s prohibition of straight stems with one disciplined rightward structural direction, retaining restrained M-like ribbon joins and terminals
- [ ] Preserve the thirty-six previous raw images, submitted prompts and normalized previews; retain all new raw generations and exact prompts
- [ ] Normalize the revised alphabet with the existing case heights, shared baseline, unclipped contours and separated i/j dots; correct dot positioning without warping the source shapes
- [ ] Connect the revised alphabet to the HTML hub, add tilt and just right examples, and exercise actual words, comparisons and mobile layouts
- [ ] Commit and push the scoped revision and open the updated HTML for human review
- [ ] Human acceptance of the complete family’s direction, straight stems, restrained playfulness, letter anatomy and word rhythm

### Batch 8 — Measured Ribbon Weight and Individual Letter Verification

The user requires the agent to calculate and send a separate Fgen brief for every letter, then personally inspect every individual glyph. The prior uniform-bar pass lost the M’s ribbon character. Direct measurements distinguish the broad rising profile from the narrow returning stroke; a single average thickness is not an adequate family rule. Preserve the original M, distinguish measured source facts from inferred letter-width targets, and keep human acceptance pending.

**User review — 2026-10-20: rejected.** The user reports that letters remain bumpy and dislikes the font as a whole. The raster warping and component-compositing approach did not establish smooth, intentional contour construction. The prior geometry and browser checks are engineering history, not evidence of acceptable letter design. Preserve this attempt as rejected reference. The user subsequently chose to keep the original M; Batch 9 replaces the other letters with deliberately drawn Bézier outlines rather than more raster patches.

- [x] Measure the original M’s primary/return stroke profiles, axis, taper, local crests, inside turns and terminals
- [x] Store individual calculations and anatomical briefs for all twenty-six capitals and twenty-six lowercase letters
- [x] Send the calculations and distinct prompt to Fgen for each non-M letter; retain every actual raw output and submitted prompt
- [x] Inspect and correct each letter personally against the original M, its weight profile and its Latin anatomy
  - [x] A
  - [x] B
  - [x] C
  - [x] D
  - [x] E
  - [x] F
  - [x] G
  - [x] H
  - [x] I
  - [x] J
  - [x] K
  - [x] L
  - [x] M — original pixels retained, not regenerated
  - [x] N
  - [x] O
  - [x] P
  - [x] Q
  - [x] R
  - [x] S
  - [x] T
  - [x] U
  - [x] V
  - [x] W
  - [x] X
  - [x] Y
  - [x] Z
  - [x] a
  - [x] b
  - [x] c
  - [x] d
  - [x] e
  - [x] f
  - [x] g
  - [x] h
  - [x] i
  - [x] j
  - [x] k
  - [x] l
  - [x] m
  - [x] n
  - [x] o
  - [x] p
  - [x] q
  - [x] r
  - [x] s
  - [x] t
  - [x] u
  - [x] v
  - [x] w
  - [x] x
  - [x] y
  - [x] z
- [x] Preserve case-aware sizing, baseline alignment, detached i/j dots, open counters and unclipped shapes; check normalizer regressions
- [x] Exercise mixed-case words, all-letter examples, comparisons and actual desktop/mobile HTML rendering
- [x] Commit and push the scoped revision and open the HTML for human review
- [ ] Human acceptance of the individually reviewed family, weight contrast, ribbon character and word rhythm

The measured M’s broad rising profile is 131.5–159.5 pixels and its narrower return is 75.9–78.2 pixels on the 560-pixel capital-height grid. `glyph-calculations.json` separates those measured facts from each letter’s optical width and anatomy targets. All fifty-one non-M letters have a retained individual Fgen saved event, raw output, and submitted brief; the original M is pixel-identical to its preserved reference. Rejected strict, noisy, and malformed candidates remain under the reference’s raw history rather than being presented as accepted work.

Every capital and lowercase letter was personally inspected beside M. `glyph-inspection.json` records a distinct visual note and final geometry for each letter. The repeatable `correct_outlines.py` pass reconstructs n/l/h/m and b/d/k/p/q/r/y from retained generated contours, correcting primary weight, forward direction, connected bowls, repeated stems, and compact descender depth. It does not modify raw Fgen outputs. I/i/j/T/t receive measured shaft correction in the existing normalizer. The repaired PNGs are byte-identical on a repeated contour-correction run.

Four focused regression tests passed for dot placement, fork-body alignment, measured taper, and connected closed p/q bowls. All fifty-two final PNGs passed component, counter, case-frame, and no-clipping checks. The actual HTTP hub exercised all fifteen presets, both case actions, unsupported-input recovery, native empty-input deletion, Q/y comparisons, arrow paging and Escape. HTTP layouts at 320, 390, 768 and 1440 pixels had no page overflow or broken images; direct-file opening also worked. No browser page errors were observed. Calculations and individual inspection notes are linked from the hub. The earlier installable TTF/OTF/WOFF2 files and app typography remain unchanged. These checks did not establish contour smoothness or aesthetic quality. The user rejected this pass for visible bumps and the overall design; it is not accepted.

### Batch 9 — Original M with Deliberately Drawn Bézier Letters

The user chose “Keep the original M” after rejecting the bumpy generated alphabet. The replacement preserves the untouched M source and uses filled, closed Bézier contours for the other letters. Broad rising ribbons, narrower returns, clean inner turns, restrained terminals, proper Latin anatomy and smaller lowercase bodies remain the design constraints. Font compilation and contour checks do not establish aesthetic acceptance; human review remains required.

- [x] Draw twenty-five replacement capitals as deliberate Bézier contours; trace the original M without redesigning it
- [x] Draw twenty-six replacement lowercase letters with full-weight strokes, proper case heights, compact descenders and detached i/j dots
- [x] Compile actual TTF, cubic OTF and WOFF2 fonts from the same outlines
- [x] Replace PNG word assembly in the active HTML with actual-font text, exact vector letter comparisons and working font downloads
- [x] Personally inspect every capital and lowercase outline against M and inspect actual mixed-case words
- [x] Exercise font rendering, counters, detached dots, contour joins, editable words, controls, comparison navigation and desktop/mobile/direct-file layouts
- [x] Commit and push the connected replacement and hand every implemented item to the user for review
- [ ] Human acceptance of the replacement alphabet’s letter design, smoothness, weight, spacing and word rhythm

The replacement lives in `junk/ribbon-font/individual-review.html`. Its word composer renders native font text using an embedded WOFF2; the fifty-two SVG comparisons and downloadable TTF/OTF/WOFF2 files come from the same outlined family. The untouched original M source retains its recorded fingerprint; its actual TTF silhouette overlaps the native-size source by 99.544 percent. Its optical advance keeps every M/letter pair at least 24 units apart at zero tracking.

The focused cubic-join regression test passes. All fifty-two letters render with the intended connected silhouettes, closed counters and detached i/j dots in both TTF and OTF. The actual browser exercised all fifteen presets, case conversion, unsupported-input preservation and recovery, native empty-input deletion, keyboard size/spacing adjustments, fit, guides and comparison arrow/Escape navigation. HTTP layouts at 320, 390, 768 and 1440 pixels had no document overflow or broken images; direct-file opening also rendered the native font. All three download URLs returned the exact compiled files, and neither browser run recorded page errors. The app typography and rejected reference attempts remain unchanged. The replacement is ready for human review, not human-approved; no further implementation prompt is needed for this slice.

### Batch 10 — Five Raw Fgen Letters from the Original M

The user requested another direct image-generation trial instead of code-drawn letters: generate five letters one at a time, referencing the original M, and show the results before changing the font. A, B, S, a and m were each sent in a separate sequential Fgen call with only the original M reference canvas attached. No generated letter, vector reconstruction or geometry guide was supplied as an additional reference.

- [x] Generate uppercase A independently from the original M reference
- [x] Generate uppercase B independently from the original M reference
- [x] Generate uppercase S independently from the original M reference
- [x] Generate lowercase a independently from the original M reference
- [x] Generate lowercase m independently from the original M reference
- [x] Retain all five untouched PNGs, exact submitted prompts, saved events, dimensions and file fingerprints
- [x] Show the original M and the five results together without contour repair, thresholding, warping, vector replacement or retry-based selection
- [x] Commit and push the five-letter trial and hand the individual samples to the user for review
- [ ] Human review of the five generated letters and their fit with the original M

All five Fgen calls reported successful saved images. Each actual output is 1254 by 1254 pixels. The raw samples, `comparison.png` and `generation.json` live in `genesis/REFERENCE/ribbon-font/fgen-five-original-M/`. The comparison uniformly resizes the complete image canvases for display only. B and m have transparency, which is composited over black in the comparison; the saved raw PNG bytes remain unchanged. The initial generation trial left the original M, compiled fonts and HTML unchanged; the subsequent website integration below adds the requested Fgen tester without changing the font files. Generation succeeded, but style, weight, proportions and any decision to continue with the family still require the user's review. No next implementation prompt is needed for this five-letter trial.

#### Website Integration — Fgen Tab

The user requested the five generated samples in the website's Fgen tab for word testing. `junk/ribbon-font/individual-review.html` now has separate Vector and Fgen tabs. The Fgen tester uses the actual A, B, S, a and m PNGs plus the original M, crops only the surrounding canvas for layout, scales each image uniformly to the shared case heights and aligns the letters to a baseline. It does not redraw contours or substitute vector glyphs for unavailable letters. This is a PNG review surface, not another compiled font.

- [x] Connect the five original-M Fgen samples and original M to an editable Fgen word tester
- [x] Add eight sample combinations, capital-height and spacing sliders, Fit word and Guides controls, with independent tab settings
- [x] Preserve the complete native-vector tester and comparisons, add keyboard tab switching, and link directly to Fgen from the earlier website
- [x] Exercise direct-file and HTTP opening, presets, unsupported-input preservation and recovery, empty deletion, keyboard controls, tab state, responsive layouts and missing-image handling

The actual browser exercised all eight Fgen presets, native input deletion, unsupported-letter preservation and recovery, sizing, spacing, fit, guides and keyboard tab navigation. HTTP layouts at 320, 390, 768 and 1440 pixels had no document overflow or broken images. An 80-letter word remained inside the horizontal preview scroller at minimum size. Blocking one Fgen PNG produced an actionable error without disabling the Vector tester; reloading after asset recovery restored Fgen. The existing index page opens Fgen directly, and direct-file opening also renders the saved PNG words. Successful HTTP and direct-file runs recorded no page errors. The integration is ready for human review; letter design and family acceptance remain pending above. No next implementation prompt is needed.

### Batch 11 — Next Ten Fgen Capitals from the Original M

The user requested ten more letters generated the same way, one at a time with every output checked. The next missing capitals are C, D, E, F, G, H, I, J, K and L. Every call uses only the original M reference canvas. Raw PNGs and exact prompts, saved events, dimensions, fingerprints and individual inspection notes are retained in `genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/`. Inspection checks letter anatomy, connected shapes, counters, extra marks and clipping; it does not replace human design approval.

- [x] Generate and individually inspect uppercase C from the original M
- [x] Generate and individually inspect uppercase D from the original M
- [x] Generate and individually inspect uppercase E from the original M
- [x] Generate and individually inspect uppercase F from the original M
- [x] Generate and individually inspect uppercase G from the original M
- [x] Generate and individually inspect uppercase H from the original M
- [x] Generate and individually inspect uppercase I from the original M
- [x] Generate and individually inspect uppercase J from the original M
- [x] Generate and individually inspect uppercase K from the original M
- [x] Generate and individually inspect uppercase L from the original M
- [x] Add all ten raw PNGs and their word combinations to the existing Fgen tester
- [x] Exercise the expanded Fgen tester and hand the letters and changed files to the user for review
- [ ] Human acceptance of the ten new letter designs and their consistency with the original M

All ten selected outputs are 1254 by 1254 pixels and were inspected separately before proceeding. The first L read as a Greek lambda, so it was rejected and retained unchanged; a second independent call using only the original M produced the Latin L used for review. Both L PNGs, prompts, saved events and inspection decisions remain recorded. I's top and bottom bars are more conventional than the more organic letters and still need human family-consistency review. The existing five samples, original M and compiled font files remain unchanged. This batch extends the image-based review rather than replacing the installed font.

The expanded Fgen tab in `junk/ribbon-font/individual-review.html` now uses all fifteen generated PNGs plus the original M, with fourteen presets including CAMEL, MAGIC, FLASH, JACK, BADGE, the new ten letters and every available glyph. Direct-file opening rendered the new letters, and the actual HTTP browser exercised every preset, typed words, unsupported-input preservation and recovery, native empty deletion, keyboard size and spacing controls, independent Vector/Fgen drafts, and native-vector comparisons. Layouts at 320, 390, 768 and 1440 pixels had no document overflow, broken images or stretched word-preview images; all sixteen available glyphs stayed inside the horizontal scroller on mobile. Blocking the new L image reported the asset failure without disabling Vector, and reloading after asset recovery restored Fgen. Successful direct-file, HTTP and responsive runs recorded no page errors. The earlier five PNGs and original M retain their recorded fingerprints. The new comparison and generation record are retained alongside all raw outputs, including the rejected L. The website integration and ten generated letters are ready for human verification; family consistency and design acceptance remain pending. No next implementation prompt is needed for this slice.

### Batch 12 — Ten More Fgen Capitals from the Original M

The user requested the next batch using the same original-M-only, one-letter-at-a-time process. The next ten missing capitals are N, O, P, Q, R, T, U, V, W and X; S is already available. Generate each separately, inspect its letter anatomy, connected shape, counters, extra marks and clipping before starting the next, and preserve every raw output and any rejected attempt. Save the exact prompts, generation events, dimensions, fingerprints and inspection decisions in `genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/`. Extend the existing PNG-based Fgen tester without changing the original M, earlier glyphs, compiled fonts or app typography.

The user also requested closer letter spacing. All three previews now start at -0.040 em and allow adjustment down to -0.200 em, with the existing positive range and keyboard controls preserved. At the same 240-pixel capital height, CAMEL narrowed from 1624.125 pixels at the previous Fgen default to 1469.9375 pixels at the new default; the new minimum reached 1195.609375 pixels instead of the old minimum's 1469.9375 pixels. The actual browser exercised overlapping PNGs with the existing screen blending, native-vector minimum spacing, the earlier font preview, fit controls, independent tab state and mobile opening without page errors. Letter contours and font files are unchanged; the tighter default and adjustable overlap are ready for human verification.

- [x] Tighten default letter spacing and extend the negative-spacing range in the Vector, Fgen and earlier font previews
- [x] Generate and individually inspect uppercase N from the original M
- [x] Generate and individually inspect uppercase O from the original M
- [x] Generate and individually inspect uppercase P from the original M
- [x] Generate and individually inspect uppercase Q from the original M
- [x] Generate and individually inspect uppercase R from the original M
- [x] Generate and individually inspect uppercase T from the original M
- [x] Generate and individually inspect uppercase U from the original M
- [x] Generate and individually inspect uppercase V from the original M
- [x] Generate and individually inspect uppercase W from the original M
- [x] Generate and individually inspect uppercase X from the original M
- [x] Add all ten raw PNGs and their word combinations to the existing Fgen tester
- [x] Exercise the expanded Fgen tester and hand the letters and changed files to the user for review
- [ ] Human acceptance of the ten new letter designs and their consistency with the original M

All ten new capitals were generated sequentially from the original M, inspected individually and retained as untouched 1254-by-1254 PNGs. O, P, Q and R each have one closed counter; the other six have none, and every letter has one main connected shape. Two Q calls returned no image; both failure records are preserved, and the first actual saved Q is used unchanged. W is more regular and balanced than the asymmetric M, so its family character remains a human-review point. Exact prompts, generation events, dimensions, fingerprints and individual inspections are retained with the raw-canvas comparison in `genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/`.

The Fgen tester now displays all twenty-five generated samples plus the original M, with A–X, a, m and spaces available. It opens on TIME MASTER and includes twenty-three word presets, including WORKOUT, QUICK, RIBBON, NEXT, POWER, MOVE, WAVE and the latest ten letters. Q's bowl shares the other capitals' height and baseline while its tail extends naturally below. Actual direct-file and HTTP browser checks covered all presets, unsupported-input preservation and recovery, native empty deletion, keyboard controls, independent Vector/Fgen drafts, guides, fit, four responsive widths and horizontal scrolling through an eighty-letter word. Blocking the new X reported the missing-image state without disabling Vector; restoring the asset and reloading recovered Fgen. Successful runs recorded no page errors, broken or stretched preview images, or document overflow. The original M and all fifteen earlier selected PNGs retain their recorded fingerprints. The app and compiled font files were not changed by this work. The new letters and connected tester are ready for human verification; design acceptance remains pending, and no next prompt is needed for this batch.

### Batch 13 — Hybrid S Alternatives — 2026-10-21

The user rejected the rounded S refinement, then the thin and heavier angular attempts, and requested a combination of the older S and the angular direction. The original M remains the primary style master: broad ribbons, softened asymmetric turns and rounded-flat terminals. The middle connection should be narrower without making the whole letter thin or turning it into a lightning-bolt symbol.

- [x] Identify the remaining Fgen letters: uppercase Y and Z, and lowercase b–l and n–z
- [x] Preserve the rejected rounded S, three angular S attempts, the user's construction sketch, exact generation records and rejection decisions
- [x] Generate and individually inspect S1, the balanced older-and-angular blend
- [x] Generate and individually inspect S2, the softer older-and-angular blend
- [x] Generate and individually inspect S3, the more structured older-and-angular blend
- [x] Create an equal-cap-height comparison of the original M and all three alternatives without changing their source PNGs
- [x] Connect the three S choices and their word previews without choosing a replacement for the user
- [x] Exercise the comparison and word controls, publish the owned changes and hand every item to the user for review
- [x] User accepts the initial generated S rather than the later S refinements

The three new alternatives are retained as untouched 1254-by-1254 PNGs in `genesis/REFERENCE/ribbon-font/fgen-s-hybrid-original-M/`. Their generation record names the original M, older S and heavy angular S as the reference inputs. Each new S has one connected shape and no enclosed counter. Earlier attempts and the user's sketch remain in the separate strict-S and sketch-S reference folders. The connected tester keeps the older S as its default and offers all three blends as temporary preview choices; only S changes, without overwriting the entered word or manual size and spacing. MASS, SAME, SMASH and SWISS presets and the equal-height M comparison are available. No replacement or font-file change has been accepted.

Focused JavaScript and actual direct-file/HTTP browser checks passed for all four S choices, the new presets and full available alphabet, unsupported-input preservation, native empty deletion, radio-arrow navigation, independent Vector/Fgen drafts, reload consistency, four responsive widths and closest-spacing horizontal scrolling through eighty S glyphs. Blocking the new S3 image produced the missing-image state without disabling the working Vector preview; restoring the asset and reloading recovered S3. Successful file and HTTP runs reported no page errors, and the responsive runs had no document overflow or broken or stretched images. All ten recorded raw/reference PNG fingerprints match. The app and compiled fonts remain unchanged. Each generated option and changed file is ready for human verification; final S selection and human acceptance remain pending. No next implementation prompt is needed for this slice.

On 2026-10-21 the user accepted the initial S from `genesis/REFERENCE/ribbon-font/fgen-five-original-M/uppercase-S.png`. That decision supersedes the pending S-selection status at the original handoff above. The three hybrid options and rejected attempts remain preserved as history, not selected replacements.

### Batch 14 — Accepted Initial S and Ribbon I Refinement — 2026-10-21

The user keeps the exact initial generated S and reports that uppercase I does not fit the family when TIME is spaced out. The existing I has rigid, matching horizontal caps unlike the flowing T, M and E. Refine the I itself rather than hiding it with tighter tracking; preserve the original M and all other selected glyph shapes.

- [x] Record the user's acceptance of the initial S without changing its image
- [x] Inspect the supplied TIME example and reproduce the current I at +0.160 em spacing in the actual tester
- [x] Generate and individually inspect a refined I using the original M as the primary style master, preserving the old I and exact generation provenance
- [x] Connect the refined I to the PNG tester, retain the accepted S and add I-focused word combinations
- [x] Exercise normal, wide and closest letter spacing, input and keyboard controls, responsive layouts and missing-image recovery
- [x] Publish the owned changes and hand every changed item to the user for human verification
- [x] Human acceptance of the refined I and its fit with the original M

The first I redraw retained the old slab-serif construction and was rejected before integration. The selected second output is one broad forward-rising ribbon with a rounded crest and compact rounded-flat foot, generated using only the original M image. Both raw outputs, the supplied TIME image, exact prompts, reference fingerprints, saved events and the equal-cap-height M/old-I/new-I comparison are retained in `genesis/REFERENCE/ribbon-font/fgen-i-refinement-original-M/`. The connected tester preserves the accepted initial S and uses the new I in TIME, MIMI, MINI, INITIAL and other supported words. Direct-file and HTTP smoke checks exercised normal, +0.160 em and −0.200 em spacing, native empty-input deletion and recovery, unsupported-input preservation, keyboard controls, independent Vector/Fgen drafts, guides and four responsive widths. Blocking the refined I image produced the missing-image state without disabling Vector; restoring the image and reloading recovered TIME. The raw I fingerprint is unchanged. On 2026-10-21 the user accepted the refined I and requested the remaining uppercase and lowercase alphabet.

### Batch 15 — Complete Uppercase and Lowercase Fgen Alphabet — 2026-10-21

The user accepted the refined I and requested all remaining capitals and small letters. Keep the original M, approved initial S, approved refined I and existing selected letters unchanged. Generate Y, Z and the twenty-four missing lowercase letters one at a time from the original M, inspect each saved image before generating the next, preserve every raw output and exact generation record, and connect the complete A–Z / a–z set to the existing PNG tester. Lowercase bodies share an x-height; ascenders, dots and descenders retain their actual letter anatomy rather than being flattened to the body height.

- [x] Generate and individually inspect uppercase Y from the original M
- [x] Generate and individually inspect uppercase Z from the original M
- [x] Generate and individually inspect lowercase b from the original M
- [x] Generate and individually inspect lowercase c from the original M
- [x] Generate and individually inspect lowercase d from the original M
- [x] Generate and individually inspect lowercase e from the original M
- [x] Generate and individually inspect lowercase f from the original M
- [x] Generate and individually inspect lowercase g from the original M
- [x] Generate and individually inspect lowercase h from the original M
- [x] Generate and individually inspect lowercase i from the original M
- [x] Generate and individually inspect lowercase j from the original M
- [x] Generate and individually inspect lowercase k from the original M
- [x] Generate and individually inspect lowercase l from the original M
- [x] Generate and individually inspect lowercase n from the original M
- [x] Generate and individually inspect lowercase o from the original M
- [x] Generate and individually inspect lowercase p from the original M
- [x] Generate and individually inspect lowercase q from the original M
- [x] Generate and individually inspect lowercase r from the original M
- [x] Generate and individually inspect lowercase s from the original M
- [x] Generate and individually inspect lowercase t from the original M
- [x] Generate and individually inspect lowercase u from the original M
- [x] Generate and individually inspect lowercase v from the original M
- [x] Generate and individually inspect lowercase w from the original M
- [x] Generate and individually inspect lowercase x from the original M
- [x] Generate and individually inspect lowercase y from the original M
- [x] Generate and individually inspect lowercase z from the original M
- [x] Connect the full fifty-two-letter alphabet, case-height metrics, complete galleries and mixed-case word examples to the tester
- [x] Exercise the complete alphabet, word controls, keyboard editing, responsive scrolling and missing-image recovery
- [x] Publish the owned changes and hand every new letter and changed file to the user for human verification
- [ ] Human acceptance of the completed uppercase and lowercase alphabet

The complete fifty-two-letter PNG alphabet is connected in `junk/ribbon-font/individual-review.html#fgen`, with uppercase and lowercase galleries, thirty-seven word presets, mixed-case text and the full Aa–Zz sequence. The original M, accepted initial S, accepted refined I and earlier selected letters are preserved. Every new output was inspected individually before the next generation. Earlier u and x outputs with halos or incorrect anatomy and the no-image l/u calls remain in the generation record; the tester uses the clean third u and second x without modifying their pixels.

Direct-file and HTTP browser smoke runs exercised all presets, complete alphabet input, unsupported-character preservation, native empty deletion and recovery, keyboard range controls and tab navigation, independent Vector/Fgen drafts, shared case-body heights and natural ascenders, dots and descenders. At 320, 390, 768 and 1440 pixels, all fifty-two letters remained reachable at maximum size and closest spacing without page overflow, vertical clipping, broken images or stretched PNGs; an eighty-character lowercase word also remained reachable at minimum size. A real HTTP 404 for lowercase j displayed the Fgen missing-image state while leaving Vector enabled, and restoring the asset and reloading recovered the full tester. JavaScript syntax passed, successful file/HTTP runs reported no page errors, and all thirty saved/reference PNG fingerprints matched. The app and compiled font files remain unchanged. Every new letter and changed file is ready for human verification; design acceptance remains pending. No next implementation prompt is needed for this slice.



### Batch 16 — Ribbon Accent Font and Everyday Typography Pairing — 2026-10-21

Historical Batch 16 direction: the selected ribbon alphabet was an occasional secondary title face with compact spacing in the font files. Inter Black was accepted for bold titles and prominent numeric indicators while the small-text companion was still under review. Batch 17 supersedes the accent/completion application and records the accepted Manrope selection.

- [x] Research licensed heavy heading candidates and record the user’s choice of the existing Inter Black
- [x] Lock the active specimen’s bold/title face to Inter Black rather than continuing to offer competing title choices
- [x] Render the large Duration, Sets and Rest indicators in genuine Inter Black 900 independently of the small-text selector
- [x] Research and locally supply Source Sans 3 Regular, IBM Plex Sans Regular, Manrope Regular and the existing Inter Regular for small-text comparison
- [x] Consolidate the fifty-two selected PNG sources and trace them into installable Tmax Ribbon TTF, OTF and WOFF2 without replacing the accepted letter designs
- [x] Bake compact side bearings and conservative pair kerning into the ribbon font, keeping word spaces distinct and external tracking at zero
- [x] Provide an offline interactive typography specimen with real candidate fonts, 12/14/16 px reading comparisons, font downloads, supported-character feedback and zero-tracking kerning comparison
- [x] Register the ribbon font on iOS and macOS, expose an opt-in accent-title role and apply it to the workout-completion title while preserving everyday app typography
- [x] Exercise font rendering and spacing, the browser comparison, source PNG review and native workout completion
- [x] Publish the owned implementation and hand every item and changed file to the user for human verification
- [x] Human selection of Manrope Regular as the small-text companion

The generated ribbon alphabet covers A–Z, a–z and spaces only. The previous Source Sans 3 recommendation and opt-in completion/accent role are historical, not the current product direction. Review of the renamed TimeMaster face and its app-wide page-title application is tracked in Batch 17.

### Batch 17 — App-Wide TimeMaster, Manrope and Genuine Inter Typography — 2026-10-22

User direction: apply the selected fonts across every native app page using agents. Rename the original custom font TimeMaster and credit cookbambuk. Reserve it for actual top-of-page and navigation titles, whose first letter is capitalized for display. Manrope Regular supplies readable body and small supporting text; Inter Black supplies other headings, emphasis and prominent numbers; Inter Black Italic must be a genuine supplied italic face.

- [x] Bundle licensed Manrope Regular and genuine matching Inter Black Italic for both native app targets
- [x] Rename the custom font family and outputs to TimeMaster while preserving every accepted glyph and the built-in spacing
- [x] Credit cookbambuk in the custom TimeMaster font’s copyright and proprietary metadata without changing upstream Inter or Manrope rights
- [x] Apply shared page-title-only styling, initial capitalization, unsupported-character preservation and readable dynamic text roles
- [x] Migrate workout lists, workout detail, editing, music timelines, player, resume and completion surfaces
- [x] Migrate the exercise database, notes, comments, markdown, pickers, import and native video editors
- [x] Migrate profile, posts, collectibles, achievements, Ranked and shared account surfaces
- [x] Migrate settings, music, backup, forms, AI Coach and genuine formatted-text emphasis
- [x] Migrate Outdoor maps, planning, trip details, recording, playback, offline and finish surfaces
- [x] Migrate Home widgets, analytics, history, schedules, plans, challenges and related editors
- [x] Update the local typography review to the accepted font roles and renamed downloadable assets
- [x] Run focused native builds and actual native/font-preview smoke scenarios, preserving unrelated ongoing work
- [x] Commit and push the owned migration and hand every implemented item and changed file to the user for human verification
- [ ] Human acceptance of the app-wide typography and renamed TimeMaster face

The published typography source at c07c5a5 built for arm64 iOS Simulator and arm64 macOS after integration with the concurrent startup changes. The generic iOS Simulator build also requested x86_64, which the existing routing binary does not contain; the supported arm64 build passed. CoreText registered all four production faces and confirmed genuine Inter Black Italic, the TimeMaster family name, cookbambuk copyright and cap-height-matched fallback. The compiler preserved sixty source fingerprints and generated 1,781 kerning pairs. The real browser loaded the local faces and downloads at desktop and phone widths without horizontal overflow.

The isolated iPhone app exercised Home, Settings, Tmax Account, Analytics, the empty database and page creation, including an accessibility text-size variant. A saved mixed-case Unicode title displayed an initial capital with visible digit, punctuation and accented-character fallback while its stored title remained unchanged. The actual notes view rendered Manrope body text, Inter Black headings and genuine italic emphasis. macOS launched a real app window, but accessibility access was unavailable and window capture failed, so no macOS visual-review claim is made. Existing native build warnings remain; human acceptance is pending.

## Tmax Rebrand and Loading — 2026-10-19

User-requested visible rebrand and connected loading system. The repository and folder remain Time-Master; bundle IDs, deep links, storage locations, saved data, and user-authored AI prompts retain their existing compatibility.

- [x] Apply Tmax to iOS, macOS, widget, Settings, notifications, exported files, privacy descriptions, and built-in AI identity
- [x] Preserve the supplied white M source, trace its actual silhouette, and apply the same mark to app icons and About
- [x] Connect startup to real asynchronous migration and store preparation with seven actual preparation phases
- [x] Add 68 offline fitness and resilience quotes, distinguish original Tmax training notes from sourced quotations, avoid adjacent repeats across launches, and rotate quotes during longer startup waits
- [x] Provide custom determinate and indeterminate progress, compact branded activity indicators, short-wait flash suppression, Reduce Motion support, background pausing, and loading accessibility labels
- [x] Connect AI response, tool execution, and approval states to honest feedback; remove duplicate loading UI and clear tool activity after failures without delaying AI text
- [x] Apply shared loading feedback to existing asynchronous database, media, import, player, outdoor, profile, ranked, and settings operations while retaining real training/data progress
- [x] Build the initial macOS and arm64 iOS Simulator targets and exercise startup preparation, quote selection, and actual AI waiting/tool/approval/error transitions with isolated data
- [x] Use a separate normal orange circular spinner throughout shared loading states; keep the native launch screen plain black
- [x] Use the established Inter fonts throughout the loading scene and compact loading labels
- [x] Fade quotes in on first appearance and after each quote change, respecting Reduce Motion
- [x] Recompose startup around the supplied animated M logo, circular spinner, real status, and quote
- [x] Restore the logo's repeating stroke-drawing animation above the separate spinner, using the supplied silhouette and a completed static logo for Reduce Motion
- [x] Present quotes in bold Inter with typographic quotation marks and a separate attribution while retaining their fade-in animation
- [x] Thicken the circular spinner's orange stroke across shared loading states
- [x] Keep the real startup loading scene visible for at least five seconds without delaying AI responses or other page loading
- [x] Give Discard session the normal button font, a trash icon, and readable destructive styling while retaining explicit confirmation
- [x] Make shared expanding-header action pairs fill the available content width and make expanded page titles grow slightly and move to the center; use the same header on Home
- [x] Exercise the final startup timing, quote fade, resume actions, and normal/editing expanded Home headers only on iPhone 16 Pro
- [ ] Human review of the Tmax identity, official logo drawing animation, bold circular loader, bold quoted Inter typography, quote fades, Discard session button, expanding headers, and connected page-loading behavior

Engineering checks do not constitute human acceptance. Product DOCKS.md updates await the user's review. Final runtime checks use only iPhone 16 Pro with iOS 18.6; all three focused scenarios passed. The restored logo and final bold quote/spinner corrections were then rebuilt and exercised through the drawing cycle, repeat, and Home handoff on that same simulator. No next implementation prompt is needed for this slice.

### Startup Loader and White Reveal — 2026-10-22

- [x] Move the circular loader and preparation status beneath the logo and quote, near the bottom safe area, while retaining scrollable small-screen and large-text layout
- [x] Remove the visible quote attribution line, including the Tmax Training notes label
- [x] Rotate quotes every seven seconds with a smooth upward slide and fade, retaining the reduced-motion dissolve and pausing changes in the background or during the exit
- [x] Complete the animated M, accelerate it toward the viewer, render a full-screen white cover, and fade the cover out to reveal the prepared app
- [x] Wait for actual store and account preparation; defer navigation, pending links, and resume/recovery presentation until the opening transition finishes
- [x] Build the scoped iOS app, exercise two seven-second quote changes in a disposable longer-loading build, then restore the existing five-second minimum and exercise the production whiteout, resume dismissal, and page navigation on the existing regular iPhone 16 with iOS 18.6
- [ ] Human review of the bottom loader placement, attribution-free sliding quotes, logo approach, whiteout, and app reveal

The handoff waits for animation completion on supported systems so the full-white frame cannot be skipped by overlapping fade timers. The final app retains the existing startup preparation and five-second minimum; the longer quote-check delay exists only in the disposable build. Builds used committed source plus the scoped startup changes, preserving the separate ongoing typography and other working-tree edits. Physical-device, iOS 16, reduced-motion, large-text, and macOS runtime variants were not exercised. Product documentation awaits human acceptance.

### Compact Startup Loader and Live Log Wheel — 2026-10-22

- [x] Reduce the startup spinner from 36 to 24 points and slow each revolution from 0.95 to 1.3 seconds without changing other loading indicators
- [x] Retain real preparation messages in order and present them as numbered logs in an alarm-picker-style wheel, with the current message centered, curved neighboring rows, and fading edges
- [x] Give new log rows a slower upward slide, expose only the current status to accessibility, and remove wheel motion under Reduce Motion
- [x] Build and exercise the compact spinner, live numbered history, existing whiteout/reveal, resume dismissal, and subsequent page navigation on the existing regular iPhone 16 with iOS 18.6
- [ ] Human review of the compact size, rotation speed, numbered log wheel, fading, and scroll feel

The numbers count actual preparation messages, not estimated percentages or simulated work. The wheel does not loop fabricated logs or delay startup to play its history. Quote timing, the existing minimum startup duration, and the logo-to-white opening remain unchanged. This follows the truthful progress principle in Apple's [Loading guidance](https://developer.apple.com/design/human-interface-guidelines/loading); the wheel's visual treatment is the user's requested design, not an Apple-required loading control. Checks used committed source plus the scoped changes, preserving ongoing typography and other edits. Physical-device, reduced-motion, large-text, and macOS runtime variants were not exercised.

### Dense Haptic Logs and Reverse Logo Loop — 2026-10-22

- [x] Tighten startup log spacing and expand the faded, curved wheel to show more neighboring recorded messages
- [x] Use genuine Inter Black Italic for every log and its count, retaining Dynamic Type and the complete current message for accessibility
- [x] Give every row a bold icon, using a filled check for preceding recorded phases and a bold activity glyph for the latest phase
- [x] Advance through real log rows individually and request one light mobile selection haptic per row, preserving spacing between ticks when preparation messages arrive together
- [x] Cancel queued feedback when the loading view is inactive or exiting, and avoid replaying startup history during later account-library switches
- [x] Make the M draw forward, erase along the same path in reverse, and immediately draw again without the old opacity fade or empty hold
- [x] Preserve the completed M, zoom-to-white handoff, seven-second quote interval, and existing preparation-based startup timing
- [x] Build and exercise the actual iPhone 16 iOS 18.6 startup, inspect dense italic/icon rows, observe ten ordered and nonduplicated haptic requests through real preparation and account loading, and exercise the clean reverse-draw build through whiteout, resume dismissal, and navigation
- [ ] Human review of log density, italic typography, bold symbols, physical-iPhone haptic feel, and the continuous M draw/erase loop

Haptic requests reuse the existing mobile selection-feedback renderer and follow the discrete-event pattern in Apple's [Playing haptics guidance](https://developer.apple.com/design/human-interface-guidelines/playing-haptics). A disposable runtime probe checked the real request sequence and was removed before the final build; the Simulator cannot establish physical vibration strength or feel. The rendered M completed, erased backward, and began another forward stroke without an empty dwell before its normal whiteout exit. Checks used committed source plus only the owned changes, preserving unrelated native-smoke and other working-tree edits. Physical-device, background-interruption, reduced-motion, large-text, and macOS runtime variants were not exercised. Product documentation awaits human acceptance.

### Smooth Log Wheel and Crisp Vector Exit — 2026-10-23

- [x] Smooth log-wheel retargeting with a critically damped spring and one continuous row distance controlling position, tilt, scale, and fading
- [x] Keep the M's round starting cap visible through the reverse-to-forward turnaround instead of letting the stroke become an empty mask
- [x] Render the drawing M directly as vector geometry and paint the enlarged departure M at viewport resolution, without enlarging a flattened drawing-group texture
- [x] Couple the rapid logo expansion to a continuous white bloom, then fade the same loading surface into the interactive app without swapping white cover layers
- [x] Preserve the renamed macOS product as Tmax.app and retain its TimeMaster-macOS build scheme and existing bundle identity
- [x] Build iOS and macOS, exercise two final uninstrumented iPhone 16 iOS 18.6 launches through full white and app reveal, retain visible ink through the reverse turnaround, and navigate to Analytics after closing the saved-workout prompt without discarding it
- [ ] Human review of wheel smoothness, the reverse turnaround, rapid vector expansion, and the white-to-app reveal

The enlarged native Canvas was also rendered at three-times display scale and compared with an independently rendered vector Shape; the visible edges remained native-pixel sharp. Log content, italic fonts, bold symbols, selection-haptic sequencing, seven-second quote timing, and preparation-based readiness remain unchanged. These are engineering checks, not human acceptance. Physical-device haptic feel, reduced-motion and background-interruption variants, and the complete macOS app runtime were not exercised; the installed Mac app was not replaced.

## Workout Metrics and Navigation Surface — 2026-10-20

User-requested selector, tracking-card, Analytics navigation, and menu-background corrections. Human review remains pending.

- [x] Fill only selected workout-type chips orange and leave inactive chips unfilled
- [x] Enlarge the three Workouts metric icons
- [x] Remove visible metric captions while preserving accessible labels and values
- [x] Make Sessions, Training Time, and Day Streak cards open their corresponding Analytics sections
- [x] Add weekly Sessions and Training Time charts and a direct destination for the existing streak tracker
- [x] Share weekly totals between Workouts and Analytics, including elapsed time for partial sessions
- [x] Bound per-type streak traversal and stop at missed training days so recorded history cannot freeze Analytics
- [x] Keep navigation content full-size with safe-area clearance and remove the container's rectangular background; retain only the curved menu surface
- [x] Build, install, and launch the current working-tree app on regular iPhone 16 with iOS 18.6
- [x] Exercise selected and inactive chips, all three empty and populated metric routes, and Home content continuing behind the menu curve on iPhone 16 with iOS 18.6
- [ ] Human review of selector states, enlarged caption-free cards, tracker destinations and totals, populated Analytics responsiveness, and the menu background

The populated runtime check used two sessions in the current week: a ten-minute completed workout and a three-minute partial workout. Workouts and Analytics both showed two sessions and thirteen minutes; a previous-week entry stayed outside those totals. All three destinations remained responsive. A separate calendar smoke covered empty weeks, multiple sessions per day, future exclusion, Monday/Sunday week boundaries, and DST. The requested simulator retained its existing data and saved workout; populated-data checks used a disposable same-model iOS 18.6 simulator. Product DOCKS.md updates await human acceptance. No next implementation prompt is needed.

---

## Cycle 39 — F29 Physique Duels Specification

**Requested by the user on 2026-10-21: document a new native page with AI physique analysis, separate physique-only Elo, complete UI states, reporting, and nudity rules that permit nonsexual shirtless adult men. The user explicitly requires direct placement in features, with no incubation stage. Documentation only; app implementation is not authorized by this record.**

Product context: [features/F29-physique-duels/DOCKS.md](features/F29-physique-duels/DOCKS.md). F29-A through F29-E own page flow, AI metrics, independent competition, safety, and privacy/service behavior. The user's subsequent UI direction adds F29-F identity/badges and F29-G shared animated native components, with dedicated view contexts under F29-A and equal native iPhone/macOS scope. Numerical defaults remain proposals, not measured or human-accepted behavior. This cycle does not reorder earlier work or approve the Ranked foundation by implication.

- [x] Document F29 directly in the feature tree
  - [x] Write the parent product context and existing-app boundaries
  - [x] F29-A — Describe the dedicated page, guided capture, complete UI states, accessibility, and motion
  - [x] F29-B — Define AI inputs, visible-physique metrics, rubric, draw/invalid outcomes, and judging-version boundaries
  - [x] F29-C — Define physique-only Elo, matchmaking, allowances, records, standings, and result corrections
  - [x] F29-D — Define attire, contextual nudity moderation, reporting, blocking, human enforcement, and appeals
  - [x] F29-E — Define consent, protected media, retention/deletion, provider operation, costs, and unmeasured latency targets
  - [x] Register F29 in the feature catalog without restoring deleted legacy feature specifications
  - [x] Check local links, cross-area contracts, and the boundary between product documentation and implementation claims
- [ ] Human review of the Physique Duels specification and its proposed defaults
- [x] Place the complete specification directly in features as explicitly requested by the user
- [ ] F29 — Implement and connect the documented Physique Duels feature
  - [ ] Confirm human-reviewed account/navigation foundations, authorized persistent HTTPS service, model access, and operational moderation
  - [ ] F29-A — Build the native iPhone and macOS destination and connected capture-to-result flow
    - [ ] Preserve saved navigation, Profile shape, existing exercise privacy, and ordinary app access after declined consent
    - [ ] Connect account/age/consent, camera/redaction, readiness, timed poses, retakes, upload, recovery, and every unavailable/empty/error state
    - [ ] Connect result/media/history/safety routes, accessibility, focus, large text, and reduced-motion behavior
  - [ ] F29-B — Establish the real paired-image judge and its quality boundary
    - [ ] Evaluate current candidate models against consenting human-judged comparisons, repeatability, reversed player order, clothing coverage, skin tone, body type, devices, and lighting
    - [ ] Connect the fixed rubric and evidence checks without medical measurements, hidden anatomy, exposure bonuses, or forced winners
    - [ ] Preserve per-match model/rubric versions and neutral, validated final output; keep Elo disabled if the quality bar is not met
  - [ ] F29-C — Connect the authoritative physique-only competition domain
    - [ ] Isolate earned Elo, provisional placement, tiers, matchmaking, quotas, and competitive records from every exercise and local display level
    - [ ] Enforce exactly-once results, distinct draws/no-contests/forfeits, reconnect and cancellation rules, and honest paginated standings/history
    - [ ] Connect audited review corrections without double-applying Elo or inventing missing outcomes
  - [ ] F29-D — Connect safety and staffed review
    - [ ] Enforce the explicit shirtless-men exception, required opaque coverage, contextual moderation, and protected media before display
    - [ ] Connect per-item hide/report, reliable submission status, block exclusions, case status, score disputes, safety appeals, and proportionate enforcement
    - [ ] Resolve the remaining App Store objectification risk without disguising the core product or promising approval
  - [ ] F29-E — Connect privacy and service operation
    - [ ] Protect credentials, consent versions, redacted evidence, participant-only media access, account deletion, bounded retention, and justified report holds
    - [ ] Match privacy labels and disclosures to actual processor logging, retention, backup expiry, and any provider change
    - [ ] Measure whole-duel token costs and end-to-end typical/slow latency; keep five seconds a target rather than an invented benchmark
    - [ ] Exercise provider/permission/network failures, late results, account switching, deletion, expired media, and moderation outages without local fake ratings
  - [ ] Exercise complete physical-camera matches with two authenticated consenting adults and focused relevant checks
  - [ ] Human review and acceptance of every implemented F29 area before public rated use


### Native UI Direction and Dedicated Specialist Plan — 2026-10-21

The user requests a top timer, all public user badges above two large vertically stacked player panels, country-flag identity treatment, less visible prose, and deeply designed motion for the timer, icons, active background, results, and score counters. Native macOS is explicitly required alongside iPhone. This extension authorizes complete requirements and worker briefs; no production UI, backend, artwork generation, model-quality validation, measured performance, or human acceptance is claimed by planning it.

Dispatch and ownership: [F29 native UI orchestration](prompts/F29-physique-duels/F29-phase-2-native-ui-orchestration.md). The planned assignment covers twenty-five views and six advanced identity/component slices: GPT-6.1 Sol with max reasoning for ordinary views, and GPT-6 Astra with max reasoning for the battle stage and advanced components. This describes the requested assignment, not verified execution provenance. Available built-in specialists are recorded below; the ordinary-agent dispatcher does not expose per-task model or reasoning overrides. Coding-agent assignments do not change the in-app judge.

**Implementation authorization and scoped dispatch:** The user subsequently authorized actual native iPhone/macOS implementation and repeatedly requested dedicated, tightly scoped subagents. Earlier CLI attempts hit Codex quota, an expired OpenCode key and insufficient OpenRouter credit. Available built-in specialists produced source; the requested Sol/Astra/max provenance could not be enforced or verified through this dispatcher. Each view/component worker owns only its named Physique file family; camera and service workers have separately scoped Physique ownership. The integration owner alone registers navigation, shared models/store, native commands, target membership and necessary privacy wording. Existing pages and unrelated features are not redesigned. Implementation and focused engineering checks remain separate from human acceptance and unexercised physical or operational scenarios.

**Simulator restriction:** Reuse the existing iOS 18.6 iPhone 16 for all subsequent native checks, with parallel testing and device cloning disabled. View/component workers must not create simulator devices. The four temporary devices named Physique Native Smoke, TimeMaster Final Crest Review and the two OMPP Preview devices were removed at the user's request; existing standard devices and installed runtimes were preserved.

- [x] Document the approved vertical battle hierarchy, complete badge rails, concise copy rules, and native Mac scope in the parent and shared view contexts
- [x] F29-F — Specify optional country, truthful badge earning/corrections, top-rail composition, and accessible identity details
- [x] F29-G — Specify timer, panels/icons, background, counters, and native Mac shell with complete animation and interruption behavior
- [x] Write one dedicated deep-design product context and future implementation brief for each of the twenty-five custom views
- [x] Write one dedicated advanced-component brief for identity/badges and each of the five F29-G components
- [x] Register the UI hierarchy, preserve the supplied reference, validate every new link and model assignment, and publish only owned documentation changes
- [ ] Human review of the detailed UI composition, badge milestones, motion treatment, and per-view requirements
- [ ] Optional interactive battle-to-results mockup only if the user chooses it; no production dependency or implied mockup acceptance
- [x] Implement the shared native component foundation with real contracts; human review remains pending
  - [x] F29-F — Real public identity, optional self-declared country, earned badge facts, complete rails, and correction/removal behavior
  - [x] F29-G-a — Phase clocks, start/self-timer distinction, tactile digits, resumption, and authoritative deadlines
  - [x] F29-G-b — Large vertical player panels, clean camera/avatar states, original safe pose icons, and readable adaptive geometry
  - [x] F29-G-c — State-driven battle atmosphere with reduced-motion, inactive, energy, and thermal behavior
  - [x] F29-G-d — Validated numeric counters, signed Elo and once-only result/badge choreography without fake intermediate outcomes
  - [x] F29-G-e — Native Mac window/input/camera/privacy shell, current minimum-size support, and one active match across windows
- [x] Implement every connected native iPhone and macOS view with real shared contracts; human review remains pending
  - [x] F29-A-a — Lobby
  - [x] F29-A-b — Account entry and return to the intended Physique action
  - [x] F29-A-c — Eligibility and separate informed sharing consent
  - [x] F29-A-d — Rules and rubric
  - [x] F29-A-e — Local pose guide
  - [x] F29-A-f — Camera setup and real device/permission states
  - [x] F29-A-g — Match search and honest cancellation/no-opponent recovery
  - [x] F29-A-h — Ready room and synchronized start
  - [x] F29-A-i — Vertical battle stage and guided capture
  - [x] F29-A-j — Exact pose review, checks, replacement, and bounded retakes
  - [x] F29-A-k — Submission, waiting, judging, and authoritative recovery
  - [x] F29-A-l — Final result, earned rating, and safe next actions
  - [x] F29-A-m — Complete score breakdown and version/evidence meaning
  - [x] F29-A-n — Intentional protected pose gallery and per-image safety
  - [x] F29-A-o — Private match history and stable paging
  - [x] F29-A-p — Physique-only standings, ties, and listing/privacy states
  - [x] F29-A-q — Permitted player identity and badge summary
  - [x] F29-A-r — Safety hub, support, and explicit block management
  - [x] F29-A-s — Contextual report composer and real receipts
  - [x] F29-A-t — Private case center
  - [x] F29-A-u — Case details, decisions, and reviewed corrections
  - [x] F29-A-v — Explicit safety-appeal/outcome-dispute composer
  - [x] F29-A-w — Privacy, sharing, listing, and image removal
  - [x] F29-A-x — Existing global deletion entry and truthful deletion status
  - [x] F29-A-y — Complete badge collection and optional country controls
- [ ] Exercise the connected actual native iPhone surface, including full-size/large-text battle, finality, safety, privacy, and reduced settings
- [ ] Exercise the connected actual native Mac surface at minimum/laptop/full-screen sizes, with live resizing, keyboard/pointer, window lifecycle, and camera availability
- [ ] Exercise all-badge/long-name/missing-flag states and ensure clean judged images exclude all identity/timer/score UI chrome
- [ ] Human review of every implemented view/component and acceptance of both native platform experiences

### Presentation Redesign — 2026-10-22

The user rejected the initial native presentation as information-only and unpresentable. This explicitly authorizes replacing that presentation with an authored, animated sports arena while preserving real match, account, capture, safety and privacy behavior. Eight isolated presentation workers own only the timer/atmosphere, battle composition, player art, verdict, lobby, badges, private intermission, and shared F29 supporting surfaces. No worker owns the whole feature or unrelated pages.

- [x] Recompose the native battle with a dominant clock, complete identity/badge rails, large vertically stacked players and a deliberate arena/pose hierarchy
- [x] Replace generic timer, player, badge and background presentation with original sports artwork and state-driven, reduced-setting-safe motion
- [x] Build a choreographed final verdict, congratulations and earned-reward effects gated by actual fresh judged results, with truthful static history/correction alternatives
- [x] Art-direct the actual iPhone/Mac lobby and opaque camera-off intermission rather than presenting an information wall
- [x] Refine shared F29 supporting surfaces without altering other app pages or hiding important errors, consent or privacy consequences
- [x] Exercise redesigned public iPhone entry/rules/pose-guide routes at default and largest accessibility text, plus labelled native Mac component renders; full physical-match, window-lifecycle and human-review checks remain pending
- [ ] Human review and acceptance of the redesigned native presentation

Engineering handoff, not human acceptance: all twenty-five native routes and six shared component families are connected to the real account/store/capture/service interfaces. The Rust service passed all 63 tests, including 20 focused Physique tests. An isolated real HTTP run exercised public policy, anonymous rejection, registration, state, country mutation, idempotent retry/conflict, unavailable rated entry, gallery ownership and post-logout rejection; real responses also decoded through the native DTOs. No production opponent, judge result or rating fallback was introduced.

The redesigned native Mac components rendered at narrow and desktop widths, including long identity/all-badge/missing-country states, both vertical players, win/loss/draw/no-contest/forfeit/corrected verdicts, and active/checking/error/inactive privacy covers. Actual window content resized to 800×600 and 1100×768 on this display. A native timer render exposed duplicate fallback identities that crashed SwiftUI; the explicit fallback identities were removed. A labelled native motion run under controlled component energy state observed real interpolation and caught a cancellation defect; replacing the animated content on interruption stopped later interpolation and prevented replay. The Mac's system Low Power setting was not changed. The temporary fixture, launch hooks and component power override were removed; the clean native Mac target builds.

The clean iPhone target passed both permanent pose-guide regressions on the existing iPhone 16 / iOS 18.6: named native pose buttons, selected-state changes, and viewport containment at default and largest accessibility text. The tests navigate the actual redesigned lobby and rules to the local guide and dismiss the existing saved-workout prompt with “Not now”; no workout is discarded and no camera starts. Xcode's post-test diagnostic collector timed out, but the result bundle records two passed tests, zero failures and zero skips.

Remaining verification is explicit: full authenticated two-adult physical-camera matches, real provider quality/latency/cost, staffed moderation, broad reduced-setting and window-lifecycle coverage, VoiceOver and complete native Mac keyboard/pointer navigation have not been verified. The unattended Mac public-route AX attempt did not reach the Physique controls; global startup was still visible in one run and external AX/screen-capture permission was unavailable. Rated entry remains closed without the real configured judging, safety, disclosure, quality and operational prerequisites. Product DOCKS stay unchanged until the user accepts the resulting behavior.

### Recording-Friendly Battle Framing — 2026-10-22

The user wants screen recordings of gameplay to identify the app immediately. The battle content therefore starts with the existing Tmax logo and the app name in a dedicated fixed brand row, followed by the real timer and controls. Complete public badge rails remain above vertically stacked You and Opponent panels. Both player feeds become rounded squares seated on visible supporting bases, with a deliberate separate VS band between the participants. This replaces the earlier sharp landscape wells and timer-first presentation without adding recording or opponent-streaming functionality.

- [x] Place the existing Tmax mark and app name at the absolute top of battle content with dedicated branding space
- [x] Reframe both large vertical player feeds as rounded squares on visible supporting bases while preserving the entire aspect-fit source
- [x] Reserve clear balanced VS separation on native iPhone and Mac without changing capture, timer, privacy or match behavior
- [x] Exercise the actual updated native components, preserve the existing iPhone 16 simulator, and publish only this scoped UI revision
- [ ] Human review and acceptance of the recording-friendly battle framing

The native framing review ran on Mac and the existing iPhone 16 / iOS 18.6. It rendered the real shared components at 320-, 393-, 800- and 1100-point widths, plus enlarged accessibility text. Both supplied media areas measured equal width and height; the source-edge image retained all four corner labels inside the inset square. The actual static Tmax mark and app name precede the timer, and the branding remains outside participant scrolling. The wider two-layer bases and separate VS band were inspected in the native renders. No new simulator, camera session, recording feature or opponent stream was introduced. The temporary review screen and its launch entry were removed; human review and full authenticated camera-match verification remain separate.

Clean native Mac and iPhone Debug builds passed after removing the review screen. The clean app was installed over the existing iPhone 16 app without uninstalling it or deleting its data. This records scoped implementation and engineering checks, not human acceptance.

---

## Cycle 40 — Shared Account and Exercise Database Sync — 2026-10-21

Requested scope: one account on native iPhone and Mac; Rust-backed synchronization of the exercise hierarchy, guides and referenced photos/video; a device-wide local-only switch; account-independent ZIP export; free/personal cloud configuration without paid upgrades. This work does not authorize F29 implementation or imply acceptance of other pending features.

- [x] Implement the Rust managed-auth boundary, strict Supabase JWT validation, shared Ranked identity and explicit credential-proven legacy linkage
- [x] Implement persistent SQLite sync revisions, bounded atomic commits, durable retry receipts, tombstones, owner-isolated private chunks and recoverable account deletion
- [x] Implement the shared Swift sync engine with streaming chunk transfer, durable cursors, offline journals, conflict preservation and interrupted-transfer recovery
- [x] Implement per-account local exercise libraries, archived restoration, handoff barriers and rejection of delayed writes from an old account
- [x] Connect native account entry, signup/confirmation/resend, password reset/change, reconnect/switch, sign-out, deletion and truthful provider availability to the shared auth client
- [x] Store credentials and PKCE state in Keychain, restore sessions across launches and serialize token refresh
- [x] Add device-wide sync opt-out, cancellation before local-only status, foreground polling, manual sync and honest errors/transfer status
- [x] Preserve account-independent ZIP export and add streaming V2 exercise-tree/media backups, legacy asset collision remapping and unsafe ZIP rejection
- [x] Resolve legacy global-media references in displayed exercise pages after restore
- [x] Keep Settings and Backup controls reachable around the measured navigation surface and suppress menu interaction while entering account fields
- [x] Configure the dedicated free Supabase project, private four-MiB chunk bucket, native callback allowlist and confirmed-email password policy without enabling unconfigured social providers
- [x] Configure the machine-private local server environment and fail closed when managed-auth server credentials are absent
- [x] Back up the existing Ranked database, migrate it to schema two and start the configured persistent loopback Rust service
- [x] Exercise real Supabase password auth, Mac Keychain persistence/password updates, native sign-in/relaunch/switch/sign-out, private asset transfer in both directions, conflicts, tombstones, restart recovery, owner isolation and real cloud-account deletion
- [x] Exercise signed-in local-only mode with zero database-sync requests across a seventeen-second observation window and export a real exercise/media ZIP without an account
- [x] Run the focused Rust, Swift core and native checks and build the final native iOS and macOS projects
- [x] Remove both temporary cloud identities and their private stored objects, the disposable UI source and the owned smoke simulator
- [x] Remove the authorized obsolete TimeMaster/Xcode and other-project Rust build caches while retaining source, installed tools, recent targets and other projects' Xcode data
- [ ] Deploy the Rust service with persistent storage and an issued public HTTPS address, then configure the production account/sync endpoint and exercise hosted iPhone-to-Mac operation
- [ ] Configure and exercise Google sign-in with an authorized ordinary OAuth client and authenticated Google Cloud console access
- [ ] Configure and exercise Apple sign-in with the required Apple provider credentials
- [ ] Verify confirmation, resend and recovery email delivery with an authorized sender/account
- [ ] Human review of every account, library-isolation, sync, local-only, ZIP, migration and native UI change

Engineering checks: 43 Rust tests, 133 Swift core tests, five focused native tests and two disposable native UI scenarios passed. The running iPhone app sent a 4,204,135-byte asset to an independent Mac SDK library; valid PNG and playable H.264 MP4 files then reached the iPhone byte-for-byte. Account B saw none of account A's seven synced records. Actual cloud deletion removed both fixture Auth users and all objects in their namespaces and rejected their old tokens.

Verification limits: the Mac SDK exercised real authentication and sync, and the final native Mac build launched into its event loop, but no Mac application-window metadata was observable during the smoke attempt. Accessibility/automation and screen-recording permission are unavailable, so native Mac controls and visual behavior are not claimed verified. The local Linux-container build also remains unproved after Docker encountered disk I/O failures; Docker was stopped normally, without pruning the user's images.

The local schema migration retained both accounts, five session rows, two ratings, one match and 126 evidence records with their original keys/counts/digests. The unchanged twenty-four-hour retention policy cleared expired raw joint-frame bodies; the complete pre-migration SQLite backup is retained in the machine's Ranked Service Backups directory. No real local exercise library was used as a cloud fixture.

External gates remain real: Railway project creation returns “Deploys have been paused temporarily”; no project, persistent volume or public service URL has been issued. Google console browser authentication and ordinary OAuth credentials are unavailable; Apple credentials are unavailable. Supabase's free default sender is restricted, and custom email templates are rejected without custom SMTP or an upgrade. No paid plan, unrelated OAuth client, fake provider enablement or placeholder production hostname was used. Release service addresses remain unset rather than pretending deployment succeeded.

Human verification remains pending. Product DOCKS.md changes await acceptance. No testing-only or commit-only follow-up prompt is created.

---

## Cycle 41 — Tmax Email Workspace — 2026-10-22

Requested scope: prepare React Email and the existing Resend CLI for template development, use subagents to reproduce the app's actual style and original fonts, and keep the email visual-first with very little text. This slice does not authorize sending campaigns, changing the existing website integration, or enabling paid features.

- [x] Add an independent, pinned React Email/TypeScript workspace in `emails/` with local preview and HTML/plain-text export
- [x] Reproduce native dark surfaces, orange controls, rounded cards, spacing and typography from the current app source
- [x] Prepare the current native Manrope Regular, Inter Black, genuine Inter Black Italic, original logo artwork and upstream font licenses without duplicate tracked email binaries
- [x] Build the initial mark/wordmark reference with styling and font subagents; the later user-requested logo-only redesign below supersedes that presentation
- [x] Add explicit `tmax` profile readiness and login commands without falling back to the existing `default` Resend credentials
- [x] Exercise the desktop, 375px and 320px browser previews, original font/asset loading, local action, HTML/plain-text export, TypeScript and dependency audit
- [x] Replace the flat full-width orange strip with a compact native-style tinted-glass action, a defined light rim, an inset highlight, white Inter Black label and decorative arrow
- [x] Build the initial icon-led Train/Focus/Explore reference; the later illustration-led welcome redesign below replaces that reference composition
- [x] Prepare licensed Lucide PNG icons for email clients, retain their source SVGs and required ISC/Feather MIT attribution, and remove obsolete generated font aliases
- [x] Exercise keyboard focus, the live local link, images/gradient-off fallback, current native font loading and final desktop/mobile exports after integrating both subagents
- [ ] Create/authenticate a separate Tmax Resend team and save its team-scoped credential as CLI profile `tmax`
- [ ] Configure an authorized sending domain, sender/reply-to identity, hosted HTTPS brand assets, real postal address, production action links and working email-preference/unsubscribe routes before publishing or sending customer templates
- [ ] Human review of the minimal visual direction, native style mapping and template workspace

Local commands from the repository root: `npm --prefix emails ci`, `npm --prefix emails run dev`, `npm --prefix emails run typecheck`, `npm --prefix emails run export`, and `npm --prefix emails run resend:status`. Preview: `http://localhost:3002/preview/workspace-preview`. Exports: `emails/out/html` and `emails/out/text`; generated assets and outputs are ignored. Port 3001 belongs to an existing Docker listener and was left untouched.

Engineering checks passed after the button/icon refinement: strict TypeScript, real HTML/plain-text export and full npm audit with zero reported vulnerabilities. The actual browser loaded original Manrope 400, Inter 900 upright and italic, and TimeMaster 400, plus the logo and four PNG icons, with HTTP 200 responses. Canonical fonts/logo/licenses, preview and exported assets matched by SHA-256. Desktop, 320px and 375px layouts had no horizontal overflow. The compact action had an approximately 54px rendered height, an 18px radius, a visible keyboard focus outline and a working local-preview destination. Its white label measured 6.38:1 contrast on the solid native-tint composite and 5.63:1 at the brightest gradient stop. A browser-simulated image/gradient-off scenario retained readable capability labels and a working live-text action. No real-email-client rendering or delivery is claimed; no email was sent or published and no live resources were changed.

External configuration remains pending: the installed Resend CLI has no team-creation command, its only saved profile is the existing website's `default`, the browser relay is disconnected and the available managed dashboard session requires login. The explicit profile check exits with `Profile "tmax" not found` rather than using the website key. A dedicated team must be created/selected in an authenticated dashboard, then `npm --prefix emails run resend:login` must be run interactively with that team's credential. No secret belongs in source or chat.

The original fonts are available in supporting clients; Gmail/Outlook and other clients may ignore custom fonts and use the declared Arial/Helvetica fallbacks. Continuous SwiftUI corners and interactive materials cannot be reproduced exactly by email clients. The reference is local-only, not a customer-ready campaign. Human verification and product documentation acceptance remain pending; no follow-up prompt is needed for the reachable local setup.

### Complete Email Design Catalog — 2026-10-22

The user approved designing every family in the researched forty-family catalog and asked for the information header in `workspace-preview.tsx` first. This is design and preview authorization, not authorization to send, subscribe recipients, upload private activity or enable future product events.

- [x] Add the shared information header: original logo only on the left; email category and context on the right; responsive divider and current native typography
- [x] Preserve the visual-first hierarchy, concise useful copy, meaningful PNG icons and compact native-style tinted-glass action across all designs
- [x] Add shared symbols, facts, feature strips, statistics, progress, steps, notices and commercial footer composition without putting sample inputs into runtime defaults
- [x] Design all account and security families
  - [x] 01 — Confirm email: `account/01-confirm-email.tsx`
  - [x] 02 — Password recovery: `account/02-reset-password.tsx`
  - [x] 03 — Password changed: `account/03-password-changed.tsx`
  - [x] 04 — Ranked account linked: `account/04-ranked-account-linked.tsx`
  - [x] 05 — Deletion request received: `account/05-deletion-accepted.tsx`
  - [x] 05 — Deletion pending: `account/05-deletion-pending.tsx`
  - [x] 05 — Qualified deletion completion: `account/05-deletion-completed.tsx`
  - [x] 06 — Security notice: `account/06-security-notice.tsx`
  - [x] 06 — Privacy-policy notice: `account/06-privacy-policy-update.tsx`
  - [x] 06 — Service interruption: `account/06-service-interruption.tsx`
  - [x] 06 — Service recovery: `account/06-service-restored.tsx`
  - [x] 07 — Email address changed: `account/07-email-address-changed.tsx`
  - [x] 07 — Sign-in method added: `account/07-sign-in-method-added.tsx`
  - [x] 07 — Sign-in method removed: `account/07-sign-in-method-removed.tsx`
  - [x] 08 — New-device alert: `account/08-new-device-sign-in.tsx`
  - [x] 08 — Unusual-sign-in alert: `account/08-unusual-sign-in.tsx`
- [x] Design all subscription, welcome and education families
  - [x] 09 — Subscription confirmation: `welcome/09-subscription-confirmation.tsx`
  - [x] 10 — Welcome: `welcome/10-welcome.tsx`
  - [x] 11 — First workout: `welcome/11-first-workout.tsx`
  - [x] 12 — Exercise library: `welcome/12-exercise-library.tsx`
  - [x] 13 — Scheduling: `welcome/13-player-scheduling.tsx`
  - [x] 13 — Timer controls: `welcome/13-player-timer-controls.tsx`
  - [x] 13 — Music: `welcome/13-player-music.tsx`
  - [x] 13 — Interruption recovery: `welcome/13-player-interruption-recovery.tsx`
  - [x] 13 — Resume: `welcome/13-player-resume.tsx`
  - [x] 14 — Devices, exercise sync and ZIPs: `welcome/14-exercise-sync-local-zip.tsx`
  - [x] 15 — AI provider and approvals: `welcome/15-ai-coach-provider-approval.tsx`
  - [x] 16 — Outdoor planning, recording and saving: `welcome/16-outdoor-plan-record-save.tsx`
  - [x] 17 — Practice versus Ranked: `welcome/17-practice-versus-ranked.tsx`
- [x] Design all progress and retention families
  - [x] 18 — First complete session: `progress/18-first-completed-session.tsx`
  - [x] 18 — Session-count milestone: `progress/18-session-count-milestone.tsx`
  - [x] 19 — Weekly review: `progress/19-weekly-training-summary.tsx`
  - [x] 20 — Monthly review: `progress/20-monthly-review.tsx`
  - [x] 20 — Yearly review: `progress/20-yearly-review.tsx`
  - [x] 21 — Goal reached: `progress/21-goal-reached.tsx`
  - [x] 21 — Streak milestone: `progress/21-streak-milestone.tsx`
  - [x] 21 — Personal best: `progress/21-personal-best.tsx`
  - [x] 22 — Weekly agenda: `progress/22-weekly-agenda.tsx`
  - [x] 22 — Session reminder: `progress/22-upcoming-session-reminder.tsx`
  - [x] 23 — Saved session: `progress/23-saved-session-resume.tsx`
  - [x] 24 — Gentle return invitation: `progress/24-gentle-return-invitation.tsx`
- [x] Design all library, sync and backup families
  - [x] 25 — First completed sync: `library/25-first-library-sync-complete.tsx`
  - [x] 26 — Persistent failure: `library/26-persistent-sync-failure.tsx`
  - [x] 26 — Preserved conflict: `library/26-preserved-sync-conflict.tsx`
  - [x] 27 — ZIP reminder: `library/27-optional-zip-backup-reminder.tsx`
  - [x] 28 — Requested guide: `library/28-requested-guide-ready.tsx`
  - [x] 28 — Requested workout: `library/28-requested-workout-ready.tsx`
  - [x] 28 — Requested export: `library/28-requested-export-ready.tsx`
- [x] Design all Ranked families
  - [x] 29 — Final result: `ranked/29-final-match-result-ready.tsx`
  - [x] 30 — Placement: `ranked/30-placement-complete.tsx`
  - [x] 30 — Tier promotion: `ranked/30-tier-promotion.tsx`
  - [x] 30 — Earned record: `ranked/30-earned-record.tsx`
  - [x] 31 — Period summary: `ranked/31-periodic-ranked-summary.tsx`
- [x] Design all product, lesson and support families
  - [x] 32 — Release announcement: `product/32-release-announcement.tsx`
  - [x] 33 — Rest structure: `product/33-lesson-rest-structure.tsx`
  - [x] 33 — Library organization: `product/33-lesson-library-organization.tsx`
  - [x] 33 — Offline preparation: `product/33-lesson-offline-routes.tsx`
  - [x] 33 — Player workflow: `product/33-lesson-player-workflow.tsx`
  - [x] 34 — Beta: `product/34-beta-invitation.tsx`
  - [x] 34 — Feedback: `product/34-feedback-request.tsx`
  - [x] 34 — Research: `product/34-research-invitation.tsx`
  - [x] 35 — Support received: `support/35-support-received.tsx`
  - [x] 35 — Support response: `support/35-support-response.tsx`
  - [x] 35 — Support resolution: `support/35-support-resolution.tsx`
- [x] Design all discreet private-notification families
  - [x] 36 — Result availability: `private/36-result-available.tsx`
  - [x] 37 — Milestone availability: `private/37-earned-milestone-available.tsx`
  - [x] 38 — Report receipt: `private/38-report-receipt.tsx`
  - [x] 38 — Dispute receipt: `private/38-dispute-receipt.tsx`
  - [x] 38 — Appeal receipt: `private/38-appeal-receipt.tsx`
  - [x] 39 — Information requested: `private/39-information-requested.tsx`
  - [x] 39 — Decision available: `private/39-decision-available.tsx`
  - [x] 39 — Restriction update: `private/39-restriction-update.tsx`
  - [x] 39 — Correction settled: `private/39-correction-settled.tsx`
  - [x] 40 — Privacy request received: `private/40-privacy-request-received.tsx`
  - [x] 40 — Processing: `private/40-privacy-request-processing.tsx`
  - [x] 40 — Limited hold: `private/40-privacy-request-limited-hold.tsx`
  - [x] 40 — Qualified completion: `private/40-privacy-request-completed.tsx`
- [x] Export all seventy-seven customer-design variants and the workspace reference as HTML and plain text, preserving their grouped paths
- [x] Exercise all seventy-eight exported designs in a real browser at 320px and 960px, inspect representative visuals, and verify all seventy-eight sidebar entries in React Email
- [ ] Human review of the information header and every email family/variant; implementation checkboxes do not record acceptance

Preview paths above are relative to `emails/templates/`. Every runtime component requires its action links and relevant data; illustrative values are assigned only through explicit `PreviewProps`. The shared header lives in `emails/components/email-header.tsx`, the visual primitives in `emails/components/email-message.tsx`, and preview-only fixture links in `emails/components/email-preview.ts`. The reference continues at `workspace-preview.tsx`. The licensed icon dependency prepares email-safe PNGs rather than relying on SVG or a system symbol font.

The design-export command now explicitly renders `PreviewProps` through React Email's renderer and produces HTML/plain text in one pass. The prior CLI export path called required-prop templates without their preview inputs and failed; adding sample runtime defaults was deliberately rejected. Temporary bundles are removed and final exports replace generated outputs only after successful rendering.

Focused checks passed: TypeScript, all seventy-eight HTML/plain-text exports and npm audit with zero reported vulnerabilities. All seventy-eight designs rendered at both 320px and 960px without horizontal overflow, missing icons or unexpected font families. Desktop responses were valid cached revalidations. The actual React Email sidebar exposed seventy-eight entries, and opening the account-confirmation entry rendered the expected header and action. Keyboard focus and a browser-simulated image/gradient-off fallback retained a readable live-text action and account information.

These are design previews, not deployed notifications or claims that future features/events are available. No emails, contact imports, subscriptions, Resend templates or production resources were sent or mutated. Marketing address/preference links and all action URLs must be supplied with real authorized values before delivery. Future reports require approved activity inputs, and private cases stay discreet. Gmail/Apple Mail/Outlook delivery/rendering has not been exercised; supporting-client fonts and static email-safe glass remain the stated limits. Product-document changes await human acceptance.

### Logo-Only Welcome Redesign — 2026-10-22

The user rejected the pictured welcome email's comparison-card layout and large technical warning, required the logo without a Tmax text title, and explicitly asked the main agent to redesign it without subagents. The user then authorized new character artwork through `fgen`, referencing the original app mascot.

- [x] Remove the text wordmark from every email header and prepare a white PNG directly from the original logo contour
- [x] Retire unused email-only TimeMaster font faces, ribbon tokens and generated legacy logo/font aliases without modifying native app fonts or brand source artwork
- [x] Replace the welcome email and workspace reference with an unboxed, left-aligned headline and short introduction, one native-style action and a large illustration
- [x] Stack the copy and character on narrow screens while retaining the compact logo/context header
- [x] Preserve the factual local-first/exercise-library-sync boundary in a short supporting line rather than a large warning panel
- [x] Generate a new welcoming pose with `fgen` using `TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png` as the original-character reference
- [x] Integrate `genesis/REFERENCE/tmax-branding/email-welcome-mascot.png`, verified as 1024 × 1536 with a real transparent alpha channel, into both welcome previews
- [x] Reuse the existing commercial footer without removing preference/unsubscribe links or caller-supplied postal-address content
- [x] Run TypeScript and export all seventy-eight HTML/plain-text designs, then exercise every exported design at 320px and 960px
- [x] Inspect the new welcome in React Email at desktop and mobile sizes; exercise keyboard focus, image-off readability and the live preview action
- [ ] Human review of the new illustration-led welcome/reference and logo-only headers

The new shared welcome composition is `emails/components/email-welcome.tsx`. Only the welcome and workspace body layouts were redesigned in this revision; the other catalog entries retain their body designs and receive the shared logo-only header. Manrope and Inter remain the text faces. The TimeMaster font continues to belong to the native app but is no longer needed by email headers.

The generation used the installed, authenticated `fgen` CLI and the user's existing subscription, with the original mascot explicitly supplied as its reference. The generated pose preserves the ivory material, black clothing and orange accents. No coding subagents were used in this revision; no native product files, private user images, contacts, subscriptions or sending resources were changed.

Engineering checks passed: all seventy-eight exports rendered at both widths without horizontal overflow, missing images or unexpected font families. The original wordmark is absent, the welcome character loads, and the live-text action remains usable with images/gradient styling removed. Browser proof does not establish Gmail/Apple Mail/Outlook rendering or human acceptance. Sending remains disconnected and production identity/address/link configuration remains pending.

## macOS Tmax Installation — 2026-10-23

The user accepted the newer native Mac build and requested the visible name Tmax, one installed app, and removal of redundant builds without changing saved data.

- [x] Install the accepted native build at `/Applications/Tmax.app` and launch its actual window with the existing bundle identity
- [x] Name the macOS Debug and Release build products Tmax and update the shared launch scheme and XcodeGen source
- [x] Remove the two stale installed Mac apps and redundant temporary native Mac build after checking the installed copy
- [ ] Human review of the renamed Dock entry and installed Tmax app

### macOS Presentation, Profile, and Header Repairs — 2026-10-23

- [x] Paint popup and sheet margins with the app background and remove redundant native titles without removing dismissal controls (done in round 2 below: the empty title band and the bottom bar are gone, actions sit in one compact top row)
- [x] Match the traffic-light strip to the app background and place the active page title beside the native window controls
- [x] Adapt the imported Profile header to desktop proportions so its actual identity, controls, and tabs are reachable (expanded header exercised; compact scrolled header is a separate item below)
- [ ] Expand page actions by dragging their header controls and keep expanded Mac groups compact and sized to their action count (bigger Mac buttons are in round 2 below; drag and size not yet exercised)
- [ ] Exercise the four repaired paths in the native Mac app and preserve the iOS layout and existing profile data
- [ ] Human review of the repaired popup surfaces, titlebar, Profile, and expanding actions

### macOS Polish Round 2 — 2026-10-24 / 2026-10-25

User-reported misses on the installed Tmax build, fixed from the user's direction. For most of the session the Mac display was asleep, so window-server screenshots were unavailable; the checks below use an in-process harness that renders views offscreen and posts synthetic clicks, drags and key events. Human review remains pending.

- [x] Popups and sheets: the empty top strip (the empty navigation title reserved a band) and the bottom action bar are removed; Cancel, Close, Done and Save sit in one compact row at the top of the popup, so content such as the Streak challenge button is no longer cut off. All `AppToolbar` items go through `MacSheetToolbar.swift`; pushed pages in the main window keep their native titlebar toolbar
- [x] Streak challenge popup compacted on Mac so its main button is visible at the default window size
- [x] Launch screen no longer shows a scroll indicator on Mac (the sign-in sheet already hid its indicators)
- [x] Navigation rail on Mac is dark Liquid Glass with a material fallback, and its icons tilt along the arc and fade toward the edges
- [x] Interface zoom on Mac: ⌘+, ⌘=, ⌘−, ⌘0 and the View menu, persisted, 50–200 percent; exercised with key events at 110, 150, 100 and 80 percent and layout reflow
- [x] Home on Mac: wide windows get two or three columns, edit mode shows remove, option and resize controls, the picker is sized, the page is no longer clipped above the rail (layout and edit-mode rendering exercised)
- [ ] Home on Mac: exercise reorder drag, resize grip, edge auto-scroll, Escape during a drag, the right-click menu and that buttons inside tiles still click (compiled only)
- [x] Startup stall: evicted iCloud files and folders are downloaded in parallel at launch with a status line, the page-types migration now finishes and writes its marker, a "Waiting for iCloud or a macOS permission prompt" notice appears after 12 seconds, and stale window-restoration state can no longer leave the app without a window
- [x] Larger expanded header actions on Mac: groups are centered, sized by action count, up to three times the compact size and at least 120 points tall (exercised with the actions forced expanded on Workouts and Home)
- [ ] Expand page actions with a real mouse drag on a header and with trackpad overscroll (the drag gesture could not be driven by synthetic events)
- [x] Profile compact header on Mac: avatar left, name beside it, shield and action buttons docked right on one row (exercised at the smallest window with interface zoom)
- [ ] Human review of popups, launch screen, rail, zoom, Home, startup, header actions and Profile

Known limits: popups built with raw `ToolbarItem` (Physique) or `AppToolbar.group` still use the system bottom bar. The Home Map widget does nothing on Mac (`startOutdoor` is empty there). The data folder `~/Documents/TimeMaster` sits in iCloud Drive, and with the disk nearly full macOS evicts it again within minutes; keep the folder downloaded (Finder, Keep Downloaded) or free disk space.

## Cycle 42 — Native Workout Bundles and Media Workspace — 2026-10-24

User-requested five-agent implementation. New components reuse the native dark/orange visual system, readable app typography, thumbnails, and concise visual controls. White bundle cards remain distinct from orange timed exercises. Existing uncommitted work and deleted legacy documentation are preserved. Implementation and human acceptance are separate.

- [x] App-owned resizable Mac video preview with a connected Quick Cut action (gallery video → `MacVideoPreviewWindow` → Cut opens the workspace editor)
- [x] Timed multi-exercise bundles: repeated sets, per-exercise durations, drag reordering, ordered/random, optional spoken phrases, small/big rests, white bundle base, stacked-card shuffle playback with every exercise page reachable
- [x] Fast upward page entrances on iPhone and Mac, directional Mac page travel with transient motion blur, Reduce Motion fade
- [x] Native Mac popup sizing, scrollable content, bottom action row, and warm-up picker layout repair
- [x] Per-video live full-Markdown comment composer, persisted by the importer, page creation, and attachment editing; shown beside previewed video
- [x] Multi-link detection, per-link validation/download status, multi-file import, independent per-source editor models, right source sidebar, left/right swipe removal with confirmation, multiple movable Mac windows
- [x] Searchable save destinations, video-comment step, independently movable save windows
- [x] Compact top-left editor navigation, transport outside the video, frame-strip seeking, ⌘+/⌘−/pinch timeline zoom, visual media-tray grouping
- [x] Reinstall Homebrew yt-dlp (2026.08.19), prefer it over the older Python copy, validate and download a real YouTube link with the app's arguments
- [x] Database left hierarchy disclosure, distinct open control, descendant four-cover group mosaics
- [x] Divider after exclusive All and independently multi-selectable type filters
- [x] Larger Settings icons and shared native styling
- [ ] Runtime scenarios: macOS and iOS targets build and the Mac app launches with an isolated home; core tests pass (CLI tests excluded: they need the default build path). Window, drag, swipe, pinch, popup, bundle-playback and motion behavior were NOT exercised because UI automation and screen capture are not authorized on this Mac. iOS was not rebuilt after the final bundle-card edit (disk full)
- [x] Commit and push owned work to origin/main
- [ ] Human review of bundles, media workflows, navigation motion, native popups, database controls, and Settings

Known limits: four of the five agents hit a usage limit mid-work and were completed by hand, so every item above needs the human review listed. Both Database filter strips (root and workout picker) already have the divider after All and multi-select chips.

### Cycle 42 follow-up — Mac media workspace fixes from screenshot review — 2026-10-24

User-reported misses after the first handoff, fixed and exercised in an isolated build with an in-process UI harness (coordinate clicks, synthetic drags, key and scroll events, window captures). Human review remains pending.

- [x] Import, Save and Preview windows use one dark unified title bar (no grey bar), keep their designed size, and the Save window grows to the available screen height
- [x] Import workspace sidebar is drag-resizable from 88 to 520 points with a hover-only orange handle, double-click reset, compact thumbnail mode and persisted width
- [x] Database list and grid rows put the expander chevron on the right beside the open control
- [x] Timeline is one lane: frames live inside each clip, trim handles resize the clip, ruler labels never overlap or garble at the end
- [x] Timeline zoom via ⌘ + scroll, pinch, ⌘+, ⌘− and ⌘0 inside the video windows (the app-wide interface zoom leaves those shortcuts to the timeline there)
- [x] "+" in the sidebar and the empty workspace open the Add Videos popup over the editor: paste links with live detection, choose or drop files, Cancel/Add buttons
- [x] Popups without divider lines or hairline borders, and without inner scrolling: shared Mac popup sizes to its content, Add Videos lists up to three detected links plus a count and grows its paste field with the text, Save window lists up to six destinations plus a hint
- [x] Save window details form keeps the Save button pinned under the form and shows the readable destination path instead of page identifiers
- [ ] Human review of the import workspace, timeline, Add Videos popup, Save and Preview windows, and Database rows

Not changed here: Home widget layout for wide Mac windows and the larger expanded header actions are being implemented in the concurrent Mac polish session (`HomeWidget`, `HomeWidgetCanvas`, `ScrollingChrome` working-tree changes); this round did not touch those files.

## Cycle 43 — System Surfaces: Notifications, Widgets, Live Activity — 2026-10-25

Requested by the user: confirm notifications on macOS and iOS, develop widgets, find out whether macOS has Live Activities, and say what a Tmax menu bar controller would contain. Implementation is ready for human review; nothing here is human-verified.

- [x] Show notification banners and sound while Tmax is open on iOS and macOS (new `NotificationPresenter` delegate; before this, every notification fired while the app was frontmost, including the post-workout celebration, milestone and streak messages, was silently dropped)
- [x] Serialize reminder, rest-day and missed-day scheduling in one ordered queue; a schedule edit no longer deletes rest-day affirmations
- [x] Plan missed-day nudges for the next seven days (one hour after the reminder time, cancelled when that workout type is logged that day) and refresh them whenever the app becomes active; the old code computed a trigger in the past, so no nudge was ever pending
- [x] Add Settings → Workout Reminders → Send Test Notification (asks for permission, schedules a banner three seconds out, shows a denied state with a link to system settings); the macOS “Open Settings” button now opens System Settings → Notifications instead of doing nothing
- [x] Remove the unused legacy daily-schedule API (`WorkoutSchedule`, `scheduleWorkoutNotifications`) while still clearing its old `workout_pre_*` and `workout_post_*` requests
- [x] Handle `timemaster://start` (with or without `workoutID`) and the Mac ⌘⇧R Start Workout command: `.launchWorkout` previously had no listener anywhere, so the widget START action, the deep link and the menu command did nothing; a saved workout checkpoint still takes precedence and opens the resume prompt
- [x] macOS build is now ad-hoc signed as a bundle (`CODE_SIGN_IDENTITY "-"`, signing allowed); the old unsigned bundle (linker signature only, identifier `Tmax`, Info.plist not bound) made `requestAuthorization` fail instantly with `UNErrorDomain` code 1 and no prompt, which is why a fresh Xcode build could never get notification permission
- [x] Home Screen widget: the START pill now starts the workout through `timemaster://start`; Pin to Widget is finally honored (selection order: configured workout, pinned workout, first workout); the shared snapshot also publishes this week's total session count
- [x] New Lock Screen widget “Tmax Glance” in circular (weekly-goal gauge with streak), rectangular (next scheduled workout, streak) and inline families
- [x] New Live Activity for a running workout: Lock Screen, Dynamic Island (compact, minimal, expanded), self-ticking countdown and progress, stale hint, completion summary, and one interactive Pause/Resume button (iOS 17+ App Intent, runs inside the app); started and updated from the player, ended on completion, stop, dismissal, resume-discard and launch without a checkpoint
- [x] Widget extension is now ad-hoc signed for the iOS Simulator so it receives the App Group like the app (it had no entitlements before, so its shared data could not be read in the simulator)
- [x] Five permanent planner tests (`NotificationPlannerTests`) cover the nudge window, completion cancelling only the matching day, ended schedules and Monday-based weekdays
- [x] Build iOS app with widget extension (arm64 Simulator) and macOS app; both pass. A multi-architecture generic Simulator build fails at link because `TimeMasterRouting` has only an arm64 slice; that predates this cycle
- [x] Checks used one temporary iPhone 16 (iOS 18.6) simulator, created for these checks and deleted afterward; no other simulator was touched. Temporary test probes and their hooks were removed before commit
- [ ] Human review on an iPhone: Workout Reminders → Send Test Notification, then finish a workout with the app open and confirm the “Workout Complete” banner
- [ ] Human review on the Mac: install a build from this commit, press Send Test Notification and click Allow on the macOS prompt (the prompt appears with the signed build; the banner itself was not observed because nobody answered it)
- [ ] Human review of the Live Activity on a device: Lock Screen layout, compact/minimal/expanded presentations, Pause/Resume, ending, and the Mac menu bar copy through iPhone Mirroring (iPhone on iOS 18+, Mac on macOS 26)
- [ ] Human review of the widgets: Quick Start START and detail taps, Pin to Widget, and “Tmax Glance” in all three Lock Screen families

Evidence from the temporary iPhone 16 / iOS 18.6 simulator, against the real notification center: with the delegate disabled the test banner never appeared while Tmax was open; with it enabled the banner appeared over Home; backgrounded, it appeared on the Home Screen. After a schedule edit the old manager left only the reminder while the new one kept the reminder and both rest-day affirmations. For a workout ten minutes ago the new planner produced one pending nudge firing about 49 minutes later, and completing the workout cancelled it; for a workout seventy minutes ago the old logic left no nudge pending. `timemaster://start` opened the Warm Up screen. Starting the workout requested the Live Activity; its expanded presentation rendered the title, workout name, countdown, progress, up-next line and pause button, and pressing that button paused the app (saved checkpoint: paused, 43 s left).

Known limits: the compact, minimal and Lock Screen presentations of the Live Activity, the Home Screen and Lock Screen widgets, and StandBy were not rendered in a simulator, so they are build-verified only. macOS has no ActivityKit: `Activity`, `ActivityAttributes`, `ActivityConfiguration`, `DynamicIsland` and `ActivityFamily` are unavailable in the macOS 26.5 SDK, and a Mac only mirrors an iPhone's Live Activity in its menu bar. No macOS widget or menu bar controller was built: a Mac widget extension needs real signing with an App Group (team 43TM9CFS43 exists on this Mac; registering the group changes the Apple Developer account, so it needs approval), and the menu bar controller needs a design decision first. Reminders still read the legacy per-type schedules in Workout Types, not the Weekly Schedule that drives Home and Today, so planned workouts there get no reminder. Widget data refreshes only when the app runs, so a widget can show yesterday's schedule until Tmax is opened. The widget extension deploys at iOS 17, so iOS 16 devices do not get the Live Activity or widgets.

## Cycle 44 — Native Mac Menu Bar Companion — 2026-10-26

User direction: a minified Tmax popup with multiple pages, one shared workout across the popup and main window, state-changing menu bar indicators, and non-interrupting workout updates. The requested visual follow-up is small polish, not a layout redesign. Human review remains pending.

- [x] Add Home, Activity, Workouts, Schedule, Coach and Settings pages using the existing palette, typography, cards and controls
- [x] Show real workouts, schedules, history, streaks, weekly goals and recent activity; search and open workout details, create workouts, and hand coach drafts to the existing chat
- [x] Publish the real player's workout state and route Pause, Resume, Skip and End back to the same player
- [x] Keep the workout window alive when closed during a session, keep its timer running while hidden, and restore it from the popup or Dock
- [x] Change the menu bar mark, progress and optional time label for upcoming, warm-up, preparation, countdown, exercise, rest, pause and completion states
- [x] Default to Quiet: only the indicator changes, without automatic windows, sound or focus changes
- [x] Offer explicit Glance and Alert modes, selectable moments, per-workout muting and calmer behavior while the workout window is in front; Glance uses a non-key panel
- [x] Add local quotes and contextual workout suggestions without requiring an AI request
- [x] Make popup cards and secondary actions neutral, retain orange for primary actions and progress, shorten settings copy and remove repeated section text
- [x] Verify bold menu bar text for countdown, active exercise, pause and completion, while rest and warm-up remain lighter
- [x] Pass 59 permanent focused app checks plus two temporary hosted popup/player scenarios on the existing iPhone 16; remove temporary native/iPhone harnesses before publishing
- [ ] Human review of popup pages, workout starting/resuming, switching to the main window, controls, icon states and selected bold labels
- [ ] Human review of Quiet, Glance, Alert, keyboard focus, login launch and the small visual/copy adjustments

Observed native smoke: a real hosted workout continued ticking after window close; popup commands paused, resumed, skipped and ended that player; the popup fit its intended size; Quiet showed no tip; Glance retained app/key-window focus; tip replacement, icon hiding and restoration worked. Native popup pages and iPhone-hosted popup states were rendered. Native glass button pixels are not faithfully represented by view-cache snapshots, so glass appearance remains for human review.

The initial full app-test run exposed conflicting existing Outdoor pane expectations: ninety-five-percent floating height/full visibility versus reserved-area capping/earlier fading. No Outdoor source or test changes are retained in this cycle; those failures are not represented as passing.

## Cycle 45 — Local-First Startup and Explicit Sync — 2026-10-26

User-reported failure: startup waited for 273 iCloud files and made the app unusable. The user explicitly rejected cloud sync as a default.

- [x] Trace the earlier automatic iCloud hydration to `2e37cb5` and managed account/database sync to `31bfae3`
- [x] Remove startup's bulk iCloud download barrier and use local Application Support storage on macOS instead of iCloud-managed Documents
- [x] Adopt resident files from the previous Documents library without deleting its contents, following symlinks or overwriting newer local files; use APFS clones where available
- [x] Keep cloud-only items out of automatic startup reads and expose the preserved library plus explicit cached-file recovery in Database Sync settings
- [x] Make an absent sync preference local-only on both platforms; retain an explicitly stored choice and do not treat sign-in as consent to sync
- [x] Avoid account-library handoff while local-only and remove account restoration from the app's launch-readiness condition
- [x] Prevent opt-in while old-library recovery is incomplete, so missing local files cannot be uploaded as cloud deletions
- [x] Exercise local-root selection, binary-file preservation, newer-local-file preservation, source preservation, symlink rejection, default-off sync, local-only sign-in, explicit opt-in and opt-out in an isolated native launch
- [x] Run the core persistence/synchronization suite: 133 checks passed
- [ ] Human review of normal launch, the recovered local library, account sign-in without sync, explicit opt-in and cached-file recovery

The Mac's system-wide iCloud settings are unchanged. Items available only in iCloud still require an explicit Finder download and cached-file import; they are not claimed to have been recovered. The original library remains available for recovery.

## Cycle 46 — Closer Mac Navigation Shortcuts — 2026-10-26

User direction: bring Database and Analytics closer in the Mac app's navigation menu. The pair moves directly after Home instead of sitting near the far end of the carousel. This is an ordering adjustment, not a spacing or styling redesign.

- [x] Apply the adjustment once to existing and fresh Mac layouts; leave the iPhone layout unchanged
- [x] Preserve the relative order of other pages, retain deliberately hidden pages, and respect subsequent manual reordering
- [x] Exercise saved-layout migration, persistence, missing Database, missing Home, reversed shortcut order, later edits, fresh layouts and Mac availability filtering with the real layout store
- [x] Build macOS and render the real navigation component before and after the adjustment; remove the temporary native harness
- [ ] Human review of Database and Analytics directly after Home in the updated Mac navigation menu

## Cycle 47 — Named Instagram Exercise Import — 2026-10-26

User direction: download the supplied exercise reel, identify and name each distinct movement, cut individual videos, and make the results visible in the currently installed Tmax app. Human review of the names and clips remains pending.

- [x] Download `https://www.instagram.com/p/DedvkOXt_EM/` and inspect the movement sequence and source-frame cut boundaries
- [x] Import thirteen named exercise pages with independent H.264/AAC video attachments into the active local Mac library
  - [x] Bar Pullover
  - [x] Reverse Tabletop to Seated Pike
  - [x] Push-Up to Rotating Sit-Through Flow
  - [x] Dive-Bomber Push-Up
  - [x] Sit-Through
  - [x] Standing Windmill Toe Touches
  - [x] Crab Hip Rotations with Knee Drops
  - [x] Seated Windshield Wipers
  - [x] Cat-Cow
  - [x] Heel-Sitting Thoracic Rotation Flow
  - [x] Deep Squat Thoracic Rotations
  - [x] Sumo Squat Stretch with Shoulder Dips
  - [x] Standing Cat-Cow
- [x] Preserve the original download and import provenance, including source ranges, references, page IDs, video paths, and the original file checksum
- [x] Mark five nonstandard variation names as descriptive, identify the incomplete 0.6-second sit-through, and exclude the text interlude and repeated promotional ending
- [x] Validate the real library and decode all 2,080 retained video frames through AVFoundation; advance AVPlayer for every saved clip and render native previews
- [x] Refresh `/Applications/Tmax.app` through its existing library notification, open Database, expand the collection, and observe all thirteen exercise navigation targets across the scrolled list
- [x] Open Seated Windshield Wipers in the installed app and inspect its attachment, guide, source range, references, and workout configuration
- [ ] Human review of each exercise name, especially the five descriptive variations, and each saved clip in Database

The collection is `kir_martysiuk — Mobility & Calisthenics` in the Mac library at `~/Library/Application Support/TimeMaster/Exercises Database/`. The source archive is `Workspace/Video Imports/DedvkOXt_EM/` under the same data root. Its 30-second exercise configuration is the required editable app default, not the video length or a prescribed training dose. These are local user-library files, not repository media or an iPhone/cloud import. No application source, existing workouts, cloud settings, or unrelated project files were changed. The existing validator reports valid records with optional-field reflection warnings; it does not report a warning-free library. Product specifications remain unchanged pending acceptance.

## Cycle 48 — Existing Exercise Library Consolidation — 2026-10-26

User direction: pause the six-type exercise request, find the exercises saved by earlier app versions, and merge them into the currently installed Tmax database. All investigation and recovery work was performed directly, without subagents. Human review remains pending.

- [x] Locate the previous Mac Documents library, the original `com.vovas.TimeMaster` iPhone library, current Mac data, and alternate preview/test storage
- [x] Recover 280 cloud-only exercise files into durable local storage with coordinated read-and-copy; preserve the original library and leave app cloud sync disabled
- [x] Preserve a pre-merge snapshot of the current library, raw snapshots of both older libraries, the preview exercise records, file checksums, ID mappings, and the merge plan
- [x] Restore 75 earlier Mac exercises and their existing hierarchy
  - [x] Boxing — 21 exercises
  - [x] Cardio — 4 exercises
  - [x] Core — 6 exercises
  - [x] Core & Wrestling — 18 exercises
  - [x] Flexibility — 5 exercises
  - [x] Gymnastics — 3 exercises
  - [x] Kickboxing — 5 exercises
  - [x] Lower Body — 6 exercises, retaining Glutes and Quads
  - [x] Upper Body — 7 exercises, retaining Push and Pull
- [x] Deduplicate the original iPhone's 23 unchanged starter exercises and eight matching containers; confirm the preview library's 23 starter records also match the restored canonical entries
- [x] Preserve the original iPhone's unique Boxing notes and both Hello pages, including their photos and video, under `Recovered original iPhone`; retain the video-only page as a container rather than inventing workout timing
- [x] Normalize legacy dates and physical parent relationships, use UUID-based page directories, and migrate legacy covers into ordered attachments
- [x] Preserve original guide files and cached manifest descriptions independently, without rewriting or concatenating their contents
- [x] Preserve all 41 pre-existing library files byte-for-byte, including the thirteen newly imported Instagram exercises
- [x] Validate all 106 merged pages and the untouched existing workout; verify checksums for all 109 restored attachments, generate native previews for 53 recovered videos, and confirm native image-container readability for 56 images
- [x] Refresh `/Applications/Tmax.app`, observe all eleven root categories, and exercise Lower Body → Glutes → Glute Bridges, Donkey Kicks, and Lunges through the real installed interface
- [ ] Human review of the restored folders, old generic drill names, recovered original-iPhone pages, notes, photos, and videos
- [ ] Resume the user's six-type exercise request after consolidation review

The consolidated local library contains 89 exercise pages and 17 container pages, with 66 video attachments and 56 images. The original Mac library remains in Documents; this is a local recovery, not opt-in to ongoing cloud sync or an installation into a simulator. The recovery snapshot and receipt are under `~/Library/Application Support/TimeMaster/Backups/Library Merge-20261026-FFA0EE2B-A10E-477B-B1D1-0A7FA1B3418D/`. Trashed items and isolated QA data were not resurrected. Existing workouts, history, app source, and sync preferences were not changed. No six new exercise types were created, and no dependent implementation or next prompt was needed.

---

## Cycle 49 — F30 Tmax Marketing Website — 2026-10-26

User direction: build the professional Next.js and TypeScript website from the user's seven annotated sketch frames; recreate the app's button styles in TypeScript; design a menu bar and footer in the app style; use a pure black page and film background; generate the hero film in one take without wasting Higgsfield credits; generate still cinematics with `fgen`; record every app clip ourselves. Product context lives in `features/F30-tmax-website/`. Nothing here is human-verified.

- [x] F30 product specification: parent and child DOCKS.md files transcribed from the sketches and the user's answers (classical marble statue; mascot named Talos)
- [x] Next.js 16.4 and TypeScript workspace in `website/` with Tailwind 4, GSAP 3.15, Lenis, React Three Fiber, Phosphor and Simple Icons
- [x] F30-A — Native button and surface system recreated in TypeScript (action, icon, selection, segmented, card and glass surfaces; SwiftUI press spring converted to CSS `linear()`), app tokens, and the app's own fonts as subset WOFF2
- [x] F30-A — Menu bar (transparent to glass, hides during immersive holds, mobile full-screen sheet) and footer (ribbon wordmark, configured-or-Coming-soon downloads)
- [x] F30-E — Hero film: `fgen` start and end frames approved, then one Kling 4.0 take at 10 credits (Seedance 2.5 and 2.0 were rejected before charging as Pro-only; the user approved Kling 4.0)
- [x] F30-E — Film pipeline: chroma key with finger occlusion, despill, true-black clamp, per-frame screen corners, desktop and mobile WebP sequences
- [x] F30-B — Hero and scroll film: canvas sequence, perspective phone-screen layer, simulated live counter with NFT prize tag, Install Now glide, accelerating feature words, TikTok-style rail, three-second page-change edit
- [x] F30-B — User addition: darker low-key film (relit `fgen` frames, one Kling 4.0 take, 10 credits) with a cursor-following WebGL light driven by a Depth Anything Video depth film (15.07 credits)
- [x] F30-E — Real app recordings from the simulator: seven clips (home, workout player, rest timer, builder, exercise library, map recording, routes). Per the user, recording stopped while the app is still in development; missing clips use the closest existing recording as a stand-in
- [x] F30-C — Choice hub, download call to action and chapter slot
- [x] F30-C-a — AI chapter with the Talos 3D model (Tripo H3.1, 18 credits)
- [x] F30-C-b — Social chapter with the generated parallax scene
- [x] F30-C-c — Workout Builder chapter
- [x] F30-C-d — Map chapter
- [x] F30-D — Impact stats
- [x] F30-B — Hero film quality: desktop frames at the source's native 1916x1080 with higher-quality opening frames; relighting rebuilt on precomputed surface slopes so the chest no longer shows horizontal stripes
- [x] F30-B — Page-change edit rebuilt as the TikTok "ego edit" the user described: 14 photographed book pages with the word "real" highlighted and locked to the screen center, full-screen desktop and phone page sets; per the user the pages never move: hard cuts accelerating from 0.2 to 0.05 seconds per page, a glow on the word, grain and flashes, 1.8 seconds in total
- [x] F30-B — Removed the TikTok-style like rail beside the phone and the selector's "Scroll to switch" hint, per the user
- [x] F30-B — Hero headline rotates between "Everything App", "Social Media" and "AI Coach" with a letter-roll swap every 3.6 seconds; promo sentence removed from the hero; "$10–150" tag moved onto Install Now with a shake and ping every 5 seconds
- [x] F30-C — "Pick your obsession" rebuilt around scroll: one glass strip of five options with icons (AI Coach, Social Media, Workout Builder, Map, Crossplatform) and an orange thumb that glides through them, above a straight row of procedural 3D iPhones looping app videos; as the thumb moves, one phone grows while the other shrinks; a soft light glides after the cursor and only catches the device frames (no glare on the screens; drifts on touch screens)
- [x] F30-C — Crossplatform option: when scrolled to, its iPhone shrinks while a MacBook opens, a Linux desktop, an Android phone and a watch rise in; each flashes its OS logo (Apple, Tux, Android, Apple) before its video plays; the replay resets when the user scrolls away
- [x] F30-C — Install banner is the finale of Pick your obsession (after Crossplatform the devices fade and the banner with the store buttons rises inside the pinned stage); every Install button opens it as a pop-up: a large notification that slides in from the right on desktop (page stays usable; close button, Escape or the store buttons; it also appears once per visit when the stats come into view) and a bottom sheet on phones
- [x] F30-D — The damage report redesigned: eight generated marble visuals (`fgen`) faded behind the cards that fade in as they scroll in; each card keeps its top title (label) and a larger bottom title (outcome) centered with icons around a rolling number with a short metric line beneath it (for example "312 h" over "a year"); glass Per person / Collection toggle with icons; a different scroll reveal per card (iris, wipe, tilt, zoom, slide, rise); hover lean and glow; the jokes, including "Sweat in. Collectibles out.", removed
- [x] F30-D — Rolling numbers rendered each digit in a visible dark box with shaved edges (the shadow and the narrow digit windows were clipped per digit); the shadow now applies to the whole number and the windows are wider than the glyphs
- [x] F30-C-a — Talos no longer stays pinned for a full screen after the AI story ends (it used to cover the next section's heading); it now leaves with the end of the story
- [ ] F30-E — Mac app recording for the MacBook and Linux desktop screens: screen capture is blocked until Screen Recording is granted or the user supplies a clip; the computers show iPhone clips until then
- [x] Production builds rendered components unstyled (the component stylesheet loaded before Tailwind's, so its base reset won); globals.css now loads first and declares the layer order
- [ ] F30-B, F30-C and F30-D DOCKS.md: describe the "real" page edit, the relit film, the rotating headline, the Install tag and pop-up, the obsession wheel and the redesigned damage report once the user accepts them
- [ ] Configure the real App Store, Google Play and signed IPA links (external prerequisite)
- [ ] Human review of the website
- [ ] Native app (found while recording): the workout editor's "Browse exercises" button does nothing on an empty workout and otherwise opens a page preview instead of the exercise browser
- [ ] Native app (found while recording): sheet "Cancel"/"Close" labels render squeezed into a small circle

## Cycle 50 — Database Image Memory — 2026-10-26

User report: the installed Mac app grew from a stable 50 MB to about 500 MB. The running app measured 508 MB (peak 766 MB). Its regions held two 46.5 MB bitmaps (4032 x 3024), one 64.5 MB bitmap (5504 x 3072), a 26.9 MB file buffer and matching Core Animation copies, which are the full-resolution photos recovered from the original iPhone library, decoded at full size to draw 56-point and 120-point Database covers. Nothing here is human-verified.

- [x] Decode photos at display size through ImageIO for Database list and card covers, container cover mosaics, page media viewers, legacy media thumbnails, profile and post photos, and Mac save-popover tiles
- [x] Bound the shared image cache by memory cost (64 MB) as well as by count, key it by requested size, and stop re-encoding video frames through PNG
- [x] Load page photo viewers once off the render path; they previously re-read and decoded the whole file on every view update
- [x] Limit concurrent cover and video-frame decodes to three
- [x] Compare the previous and the new build against the same cloned library on the Database page: 484 MB (peak 633 MB) before, about 100 to 150 MB after; every cover and mosaic still renders
- [ ] Human review of Database covers and page photo viewers with the consolidated library, and of the installed app's memory after relaunch

A short startup spike of about 130 MB remains from the launch animation and first frames; it is released within a second and was not changed.

## Cycle 51 — Database Rows, Links and Live Library Updates — 2026-10-26

User direction: tapping a container row must expand it and never open the page, only the open button opens it, and the open button gets an icon in the app's style; links (Instagram for example) must display properly; items an AI agent adds to the library must appear live. Checked by compiling the macOS and iOS targets only, at the user's request; nothing was launched or exercised. Nothing here is human-verified.

- [x] Container rows (list and gallery): a tap anywhere on the row toggles expansion with the chevron's animation; the row no longer navigates; only the open button does. Leaf rows still open on tap
- [x] Open button restyled as the app's orange glass control with a bold arrow, replacing the thin outlined system icon
- [x] Link rows: one compact row per link with a platform tile (Instagram gradient, YouTube, TikTok, Facebook, web), a derived title (Instagram post, reel or @handle, YouTube video or Short, TikTok video), the short URL without scheme, `www` or tracking query, and an orange open control; the whole row opens the link
- [x] Link metadata: Instagram, TikTok and Facebook are no longer scraped (login walls returned generic "Instagram" cards); YouTube uses oEmbed for title and thumbnail; web pages read only the page head; titles are entity-decoded and generic or login-wall titles are ignored; results are cached per session and fetched in parallel
- [x] The page-creation link preview uses the same row; the unused tall embed card and `PageLinkList` are removed
- [x] Live library updates: a file-system watcher on the exercise database (macOS, 0.4 second coalescing) reloads the Database screen when files change on disk; iOS reloads when the app becomes active; in-app AI tool calls already reload after each tool
- [x] A reload that cannot read the library keeps the previous list instead of blanking it; duplicate page ids from copied folders no longer crash a reload
- [x] An open page re-reads its guide when the library reloads (unless it is being edited)
- [x] macOS and iOS targets compile
- [ ] Human review of the row tap behavior, the open button, link rows for Instagram, YouTube, TikTok and web, and live updates while an agent writes pages
- [ ] Page switching (live whole-page slide with motion blur) is not part of this cycle; the unfinished work is parked in a git stash

## Cycle 52 — Media Viewer, Global Markdown Editor and Workout Media Swipe — 2026-10-27

User direction: Database media squares were small and fixed, so they become big horizontally swipeable cards (also on the workout view); the media viewer swipes through images and videos on macOS and iOS and plays videos inline; swiping up from below the media opens a full-screen Markdown editor; that editor is one global Notion-style editor that replaces the notes editors, lets a pasted link become a thumbnail card, and inserts images; on the workout page, swiping up on a picture opens the same editor, the Database stays reachable while swiping, and the floating music and workout widget stays visible. Checked by compiling the macOS and iOS targets, a headless macOS harness that types into the real editor text views without showing a window, and headless iOS simulator tests that render the new views to image files and type into the real editor; nothing was launched on the desktop. Nothing here is human-verified.

- [x] Media strip (`MediaStrip`) replaces the 144 by 108 grid: cards are about 72 percent of the width (220 to 360 pt, 4:5), snap while scrolling (iOS 17 and macOS 14; plain scrolling on iOS 16), show a position counter, a cover badge, a note marker and an "Add notes" or "Notes" chip that opens the editor directly; macOS adds previous and next buttons. Used on the page detail, the quick preview and the workout attachment strip
- [x] Viewer (`PageMediaGallery`): horizontal paging between images and videos, videos play inline and only the visible one plays, pinch and double-tap zoom on images, counter, full screen on iOS and a large sheet on macOS; on macOS the arrow keys and on-screen buttons page and "Cut video" opens the existing video workspace instead of a separate preview window
- [x] Notes drawer in the viewer: a handle below the media (touch drag, mouse drag, two-finger swipe up on macOS, tap, or the chevron) opens the editor; the media shrinks above it and keeps playing, can be hidden, and shrinks while the iOS keyboard is open; swipe down collapses it, swipe down on a collapsed viewer closes it; notes save about 0.7 seconds after typing and on page change or close
- [x] Notes storage: database page media keep using the page's media comments; media attached to a workout section (not to a page) keep their notes in a small local file (`Documents/Media Notes`), so they are not synced with the library
- [x] Global Markdown editor (`MarkdownEditorView`): one text block per paragraph, heading, list item, to-do, quote and code block; live Markdown shortcuts (`# `, `- `, `1. `, `[] `, `> `, three backticks, `---`); `/` block menu; format bar with bold, italic, strike, code, link, turn-into, indent, outdent, image and link card (command B, I, K and E); Return, Backspace and Tab behave like a block editor; pasting multi-line Markdown becomes blocks; block menu to duplicate, move, turn into or delete; Markdown markers stay visible but dimmed so the text maps one to one with the saved file
- [x] Link cards: pasting a link offers "Thumbnail card" or "Titled link" (or dismiss); a card shows the page thumbnail (YouTube, web pages) with title and address, loads title and thumbnail in the background, can take a chosen picture ("Choose thumbnail…") or be turned back into a plain link; saved as standard Markdown (`[![title](<thumbnail>)](<link>)`)
- [x] Images in notes: paste, the image button or the `/` menu insert a picture (downsampled to 2400 px) stored in the page's `Attachments` folder (or the local notes folder); pages that do not exist yet cannot take pictures until they are saved
- [x] Read-only renderer (`MarkdownDocumentView`) draws the same blocks, cards and images for guides and notes; `MarkdownTextView` and `MediaCommentBubble` now use it
- [x] Replaced editors: media comments, the page guide (tappable field that opens a full-screen editor), database notes (new and inline), the save-video popover comment and guide; `MediaCommentComposer`, `MediaCommentTextView` and the old block parser are removed. Not migrated on purpose: the rest cue (shown as plain text), Physique, profile and AI prompt text fields, and the legacy exercise details field
- [x] Workout page: the 260 by 260 carousel is now a large swipeable pager (up to 380 pt tall, neighbouring cards peek, dots, loops videos and honors pause) showing the section's pictures and videos first and then the exercise page's media; tap opens the viewer, swipe up opens the viewer with the editor
- [x] Workout viewer: the "Database" button opens the exercise page browser over the viewer; the floating music and workout widget is present in the viewer and editor (also in viewers opened from a page inside the workout browser); the workout detail media sheet passes the same context
- [x] Permanent tests: `MarkdownDocumentTests` (Markdown parse, round trip, numbering, fences, split and merge, list Return, indent and Backspace, typed shortcuts) and `MarkdownEditorSessionTests` (link offer and card, dismissing the offer, multi-line paste, slash menu)
- [x] macOS and iOS targets compile; the 12 permanent tests and 6 simulator render and typing checks passed on the iPhone 16 simulator; the macOS harness passed
- [ ] Human review of the strip on the page, quick preview and workout views; paging, zoom and inline video in the viewer on Mac and iPhone; the swipe-up drawer on iPhone, iPad and with a trackpad on Mac; editor typing, shortcuts, slash menu, pasted link card and image insertion on both platforms; notes on database media and on workout-only media; the workout page pager, Database button and floating widget; the guide, database note, rest and save-video editors
- [ ] Page switching (live whole-page slide with motion blur) is still not part of this cycle; the unfinished work stays in a git stash

## Cycle 53 — Agent Bridge, the Rust tmax Command and Coach Tool Fixes — 2026-10-27

User direction: let external AI agents (and the in-app Coach) do everything in Tmax — upload assets, create exercises and pages, build workouts, import videos — through one validated app-owned path, with the command line written in Rust only; fix the Coach tool requests; permission only for deleting, never allow/deny at every step; keep command output small so it does not eat the chat's context. Product context lives in `features/F31-agent-bridge/`. All work done directly, without subagents. Nothing here is human-verified.

- [x] F31 product specification (`features/F31-agent-bridge/DOCKS.md`) and index row; F09-C and F09-D marked superseded
- [x] One tool catalog (23 tools) in `TimeMasterCore/Sources/Agent`: typed arguments with coercion and unknown-option rejection, page lookup by title path or id with ambiguity and typo suggestions, dry-run for every write, batch with `$0.id` references and full rollback, undo journal
- [x] Lean results: paths instead of ids in lists (id only when a path is ambiguous), empty and default values omitted, lists capped with a `more` count, plain slashes; measured on the test library: overview 1058 to 607 bytes, depth-3 listing 1823 to 506, search 1251 to 327, one page 481 to 174, write results about half
- [x] Mac bridge (`TimeMaster/Agent/AgentBridge.swift`): private unix socket in the data root's `.agent` folder, same-user check, discovery file, ready flag; every write runs inside the app through the library-access guard and then reloads the Database and Workouts stores
- [x] Trust levels in Settings → Agent Access (Off, Read only, Standard, Full): Standard allows add, edit, move, import and settings freely and shows one native confirmation (Cancel is the default) only before deleting; Full never asks; Read only allows reads and dry-runs
- [x] Rust command `tmax` (`tmax-cli/`, only `serde_json` as a dependency): auto-opens Tmax in the background, waits for ready, typed `--flags` from the catalog (`--media a.jpg --media b.mp4`, `@file`, `--json`), relative paths made absolute, `batch`, `undo`, `doctor`, `tools`, `install`, `mcp` (stdio MCP server), distinct exit codes; about 21 ms per call once running, 1.9 s from a cold start; bundled at `Tmax.app/Contents/Helpers/tmax` by a build phase in `project.yml`
- [x] `import_video` for agents (macOS): link or local video, named clips cut with the existing trim service, one exercise page per clip, rolled back on failure
- [x] Coach fixes: tool turns echo the assistant's tool request (OpenAI and Anthropic shapes) so follow-up requests are valid; unreadable tool arguments become a tool error instead of an empty call; the Coach reads and writes the current page format (created pages now show in Database, notes survive); container and exercise page tools added; created workouts appear without relaunch; reply limit 1024 to 4096 tokens; final message requested with tools disabled; guidance text shared with external agents; approval only before deleting
- [x] Workout totals match what the app shows after reload (explicit rest rows between sections, none after the last)
- [x] Retired the Swift `timemaster-tool` and its tests, and the Coach's private `ToolRouter`; the generated AGENTS.md and skills describe `tmax` and upgrade older generated copies
- [x] Tests: 154 TimeMasterCore tests pass (agent toolbox, wire formats, schema); 21 Rust tests pass; macOS target builds
- [x] Isolated end-to-end run (throwaway home, built app, bundled and release `tmax`): create folder and exercise with photo and video, relative-path media, search, get, list, dry-run, duplicate refusal, typos, bad media, workout build and totals, edit and move without prompts, delete confirmation timing out unanswered, batch with references and rollback, undo, MCP initialize, list and call, local video import cut into 1.0 to 1.3 s clips, Read only, Full and Off levels, cold-start auto-open through a stand-in bundle
- [ ] Human review: Settings → Agent Access (segmented control and the command-line section), the delete confirmation alert, and running `tmax context` and a create-with-media command from Terminal after installing this build over the current app (`/Applications/Tmax.app` is still the previous build)
- [ ] Not exercised: the Coach tool loop against a live provider (wire shapes are unit-tested and the app compiles), the link-download path of `import_video`, the Delete and Cancel buttons of the delete alert (UI scripting is not available here, so only the unanswered timeout was run), and the Install button
- [ ] Known limits: undo reverses creations, attachments and notes only (not edits, moves or deletes); a clip end beyond the video's length is clamped and reported; each page write moves the previous manifest into `.trash` (existing behaviour); the `tmax` binary is built for the machine's architecture
- [ ] The "create 6 different types of exercises" request remains on hold

## Notes
- Codebase converted to this system: 2026-07-04.
- Cycles 1-3: original F01-F08 features (documented retroactively from working code).
- Cycle 4: user feedback from 1 month of use (built 2026-07-04).
- Cycle 5: dynamic types, analytics rework, vacation, prepare time, fixes (built 2026-07-05 to 2026-07-06).
- Cycle 6: Revolution REV-01 — file-based data architecture (DOCUMENTED 2026-07-06, NOT BUILT).
- Cycle 7: V2 Notion-style rework from IDEA.md (PLANNED, no code written).
- Cycle 8: Mac readiness & daily flow (planned 2026-07-13).
- Cycle 9: V2 workout database completion from workout-builder defect feedback.
- [x] Workout Builder Redesign (from workout-builder-plan.md)
  - [x] Schema extensions for prepareTime (SetSlot/Section in app + core manifests + page manifest; nil/0/positive semantics; legacy decode inherits)
  - [x] WorkoutSectionBuilder factory (makeSection/makeBundle/makeSlots/makeSlot; config with prepareTime; page drop templates copied by setIndex)
  - [x] Configurable exercise creation paths (duration/sets/reps/rest/prep/after-rest visible on iPhone; DatabasePageBrowserSheet + pending configurator + PageCreationSheet leaf-first + prepare control)
  - [x] Immediate create-and-navigate (addWorkout returns Workout; list view dismisses sheet then navigates to new empty detail with Add First Exercise)
  - [x] Builder row deletion (visible destructive icon + swipe for every set, drop, rest, content, big-rest, section; preparation row delete sets slot.prepareTime=0; Add Preparation restores nil inheritance; section default preserved)
  - [x] Preparation in player/resume (WorkoutPhase.prepare; beginCurrentSet chooses prep vs work; preparationView with skip; tick/reconcile; checkpoints encode phase; legacy safe)
  - [x] All call sites migrated to factory; no legacy direct construction in picker/editor/detail
  - [x] Core tests (82 tests pass including all WorkoutPreparationTests for roundtrips, duration math, inheritance, drops)
  - [x] macOS + iOS simulator builds succeed
  - [x] Detail: Restored the builder's threaded row hierarchy and category-specific row colors after source recovery
  - Verified per plan smoke paths (builds/tests only; human verification separate)
- Cycle 10: real-world polish from ISSUES.md — stability, database hierarchy, V2 workout + player reworks, mac UI polish, minimalist cleanup, scheduled-today Home, music behavior (planned 2026-07-13).
- server.py and start_server.command are F05 companion files.
- .gitignore covers xcuserdata, DerivedData, .ipa, .DS_Store.
