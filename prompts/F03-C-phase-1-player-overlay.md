# Phase 8 of F02-A-d → F03-C — Player Overlay Consolidation

## Context
We are building the V2 Notion-style Unified Page Model. Phase 7 completed F02-A-d: Player Page Popup — exercise page overlay with FloatingControlsBar showing timer, pause/stop/skip, section progress during workout. This effectively implements what F03-C ("Player Overlay — Floating controls bar") was supposed to be.

## What You Need to Read First
- `CYCLES.md` — remaining Cycle 7 items (F03-C, F04-B, F07-B, F07-C)
- `features/F02-workout-management/F02-A-workout-builder/F02-A-d-player-page-popup/DOCKS.md` — what was built
- `TimeMaster/Views/Player/FloatingControlsBar.swift` — existing floating controls
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — existing player integration

## What Happened Last Session (Phase 7 — F02-A-d)
- pageID field added to Section model (Codable, optional UUID) for page linking
- WorkoutPickerSheet passes page.id when creating sections from pages
- WorkoutSectionManifest.exerciseID mapped to Section.pageID during conversion
- DatabaseStore injected into WorkoutPlayerView via all sheet presentations (TimeMasterApp, WorkoutDetailView)
- ExercisePageOverlay created: full-screen page viewer with cover, markdown, media grid, YouTube/Instagram embeds, tags, workout config badges
- FloatingControlsBar created: semi-transparent pill with countdown/elapsed time, pause/stop/skip buttons, section progress (N of M), dismiss chevron
- Section name in activeSectionView made tappable with book.pages icon when pageID is present
- Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions (2026-07-11)

## Current State
F03-C ("Player Overlay — Floating controls bar") in CYCLES.md is effectively done — the floating controls were built as part of F02-A-d. The only missing piece is the music button in the FloatingControlsBar. All other features match what was specified.

## What to Build

### Task 1 — Mark F03-C as Done
- Update CYCLES.md: mark F03-C as `[x]` with detail noting the floating controls were delivered via F02-A-d
- Note the one gap: music button not included in FloatingControlsBar (can be added in a future enhancement)

### Task 2 — Plan Next Feature (F04-B or other)
- Read CYCLES.md for remaining Cycle 7 items
- Ask user: "F03-C is essentially done. What should be next? F04-B (Flame Streak + Per-Type Analytics), F07-B (Notification Pipeline), or F07-C (Workout Schedules)?"
- If user picks F04-B or another feature:
  - Read relevant existing code (HistoryView, AnalyticsView, StreakCard, ActivityHeatmap)
  - Create genesis/F04-B-raw/DOCKS.md with comprehensive spec
  - Propose breakdown to user
  - Create next prompt file for Phase 1 of the chosen feature

## Files to Modify
- modify: `CYCLES.md` — mark F03-C as done

## Verification
- [ ] CYCLES.md updated correctly
- [ ] User confirms next feature direction

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create the next prompt file.

## When You Finish
Report what was updated, what was decided about the next feature, and the path to the next prompt file.
