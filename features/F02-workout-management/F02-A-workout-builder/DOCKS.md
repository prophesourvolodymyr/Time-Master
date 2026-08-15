# F02-A — Workout Builder Rework

Complete rework of the workout creation and editing experience. Lego-style builder that pulls exercises from the unified database, supports work sections with sets/drops/rest exercises and bundle sections for technique browsing. Player page popup with floating controls.

## Sub-Features
- [ ] **F02-A-a** — Database Browser + Workout Page
- [ ] **F02-A-b** — Drag-to-Build + Sets
- [ ] **F02-A-c** — Bundle Section Mode
- [ ] **F02-A-d** — Player Page Popup

## Architecture
All sub-features share the unified `ExercisePage` model (F01-A) and the reworked `Workout` model with `WorkoutSection` blocks.

## Preparation, Structure, and Deletion Contract

`Section.prepareTime` is the default preparation duration for its slots, clamped to `0...30` seconds. Each `SetSlot.prepareTime` is intentionally tri-state: `nil` inherits the section default, `0` is a durable per-set removal, and a positive value is a per-set override. Imports create slots with `nil`, never with a copied deletion marker. This preserves old manifests that omit the key and lets later changes to the section default affect only inheriting slots.

The database remains the source of exercise content. A slot keeps only the source page ID and workout-local timing, set, drop, rest, and preparation structure; the player and inspector resolve the current title, guide, and media from `DatabaseStore.page(id:)`. `WorkoutSectionBuilder` is the sole page-to-section factory. It rejects containers, creates one timed section for one leaf page, and creates ordered bundle slots from selected leaves. Matching `PageDropSetTemplate.setIndex` values are copied to the matching local slot.

Every expanded timed or bundle slot renders its preparation, work/item, drops, normal rests, and rest content independently in the same scrolling builder list. Removable rows use a trailing destructive swipe action only; the rows never show an inline trash control. Removing preparation writes `0`; `Add Preparation` restores `nil` inheritance. Removing the final slot asks to remove its parent section rather than persisting a zero-slot section. Removing a normal rest clears its local duration, row, and rest-exercise link; removing a drop rest clears only that drop’s rest. The required big section-rest row remains visible when reset to zero.

The expanded list uses continuous Reddit-style thread rails: each child depth adds a quiet vertical rail and a short horizontal branch into its row, so work, drops, rests, and rest content visibly remain attached to their parent set. Category color belongs to the complete row, never to a badge or isolated label: timed set and drop rows are pure white with black content; rest rows, including big rest and their contents, are orange with black content; section headers and preparation rows remain neutral. Every row name is centered in its middle column. Its duration and cover thumbnail, when present, stay together in the leading column; controls remain trailing. Rows with a loaded cover photograph still derive a restrained 22%-wide leading wash and one-point outline from that photo. SF Symbol fallback thumbnails do not create a glow or colored outline.

## Player Preparation Phase

After optional warm-up, the player runs preparation before every timed set and every bundle item whose effective preparation is positive. Preparation retains the pending section and slot index, counts toward elapsed time, does not announce motivation prompts, and offers pause and `Skip Preparation`. Completing or skipping it starts the timed countdown or enters the self-paced bundle item. Set rest and section rest route through the same preparation decision before the next work item.

Resume checkpoints encode a `prepare` phase alongside warm-up, active, and rest phases. Restoring during preparation returns to the same pending slot and reconciles elapsed time before continuing. Bundle items remain self-paced after preparation, so background reconciliation never invents a timed bundle work period.

## Files (summary, detailed in sub-features)
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` (full rewrite)
- `TimeMaster/Models/Workout.swift` (add WorkoutSection, SetSlot, SectionMode)
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (add bundle mode, page popup)
- `TimeMaster/Models/WorkoutSectionBuilder.swift` (the only leaf-page and bundle section factory)
- `TimeMaster/ViewModels/WorkoutResumeManager.swift` (persisted player phase contract)
- `TimeMasterCore/Sources/Models/WorkoutManifest.swift` (portable slot preparation schema and duration accounting)
- `TimeMasterCore/Tests/WorkoutPreparationTests.swift` (preparation compatibility and duration contract)
- New builder views under `TimeMaster/Views/WorkoutDetail/`

## Dependencies
- F01-A — Unified Page Model (must be verified first)
- F05-B — Notion-Style Pages (pages must exist in DB to build workouts from)

## Verification
- [x] All sub-feature implementation items pass
- [x] Workout creation flow is wired end-to-end: DB browse → preview/select pages → configure sets → save
- [x] Both section modes (timed + bundle) are wired into the player

Evidence: F02-A is implemented on the active `WorkoutDetailView` → `DatabasePageBrowserSheet` → `WorkoutStore` path and on the `WorkoutPlayerView` timed/bundle path. macOS arm64 and iOS Simulator Debug builds succeeded on 2026-07-13; the iPhone 16 Pro Simulator app installed and launched; `TimeMasterCore` passed 67 tests.
