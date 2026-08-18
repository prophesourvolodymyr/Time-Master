# CYCLES.md — Time-Master
**Planned with user:** 2026-07-04, revised 2026-07-06 and 2026-07-13

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


- [x] Exercise Database Fixture & Validation
  - [x] Detail: Seeded 52 source video clips across Boxing, Core & Wrestling, Flexibility, Gymnastics, and Kickboxing with generated cover frames, guides, durations, rests, sets, and SF Symbol icons
  - [x] Detail: Added parent links and explicit page kinds/workout types to the existing hierarchy; removed the stale accidental test page with a recoverable backup
  - [x] Detail: Updated `SchemaManager.validateAll()` to validate page manifests while retaining legacy exercise fallback; string-backed page enums are accepted by schema validation
  - [x] Verified: 88 page manifests decode through `DatabaseManager.walkPageTree`, 52 video references resolve, and CLI validation reports `valid: true`

### Phase 2 — V2 Workout Management + V2 Player (paired)
- [ ] F15 — V2 Workout Management Rework
  - [ ] F15-A — V2 `WorkoutListView` card grid with page-backed cover thumbnails, today-only filter (consumes F20), scheduled-time badges, empty state
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
  - [x] Bottom-safe-area surface continuity keeps the neutral slot bar filled through the iOS home-indicator region
  - [x] Verified: iOS and macOS Debug builds succeed; 82 TimeMasterCore tests pass; app installed/launched on iPhone 16 Pro Simulator and Home renders the real page with the neutral slot surface; manual gesture and accessibility verification remains for human review

## Cycle 13 — Music Library Update
- [x] F25 — Native Music Library / Settings screen
  - [x] Provider-neutral music library model, persisted ordered destinations, local-file adoption, and provider adapter boundaries
  - [x] Compact black Music screen with Uploads, General, Type/Mine workout panes, native iOS 18 glass fallback, provider brand assets, local import, local search, select/add, move/duplicate transfer, player, guide, and accessibility motion/transparency handling
  - [x] Music opens as a full-screen destination with an explicit close control; top controls no longer overlap Uploads; Search runs its fixed-frame provider-logo sweep
  - [x] iPhone 16 iOS 18.6 Simulator build installed and launched; external Spotify, YouTube Music, SoundCloud, Dropbox, and Google Drive credentials remain required for their official integrations

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
