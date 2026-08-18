# features/DOCKS.md — Time-Master Feature Index

| Code | Feature | Status | Dependencies |
|------|---------|--------|-------------|
| F01 | Core Data Layer | done | — |
| F02 | Workout Management | done | F01 |
| F03 | Timer & Player | done | F01 |
| F04 | History & Analytics | done | F01, F03 |
| F05 | Database Import | done | F01 |
| F06 | AI Coach | done | F01 |
| F07 | Settings & Extras | done | F01 |
| F08 | Home Screen Widget | done | F01 |
| **F09** | **File-Based Data Architecture** | **done** | **F01, F06** |
| F10 | Agent Settings Control | done | F06-B, F07 |
| F11 | Resilient Background Timer | ready for iOS hardware verification | F03-A |
| F12 | Home Dashboard & Quick Start | done | F01, F03, F04 |
| F13 | Stability & Freeze Investigation | pending (Cycle 10 — first) | — |
| F14 | Database Hierarchy Model (root container vs leaf exercise) | pending (Cycle 10) | F01-B, F09-D |
| F15 | V2 Workout Management Rework | pending (Cycle 10) | F01-B, F02-A, F14, F23 |
| F16 | V2 Player Rework | pending (Cycle 10) | F02-A, F11, F13, F19 |
| F17 | Minimalist Text Cleanup | pending (Cycle 10) | — |
| F18 | macOS Polish (window clip, box artifacts, settings crash) | pending (Cycle 10) | F13 |
| F19 | Music Behavior (general upload + sequential default) | pending (Cycle 10) | F16, F17 |
| F20 | Scheduled-Today Home Widget & Missed-Red Indicator | pending (Cycle 10) | F12, F22, F04 |
| F21 | Home Quick Settings Access | pending (Cycle 10) | F18, F17 |
| F22 | Per-Type Time-of-Day Schedule | pending (Cycle 10) | Cycle 5 TypeSchedule |
| F23 | Editor Database Picker Fix (old empty DB issue) | pending (Cycle 10) | F14, F15, F09-A |
| **F24** | **Slot Navigation** | **ready for human verification** | Existing MainTabView destinations |
| **F25** | **Music Player Update** | **ready for human verification** | **F07, F19, existing WorkoutStore and MusicManager** |
| **F26** | **Private Liquid Glass Controls** | **ready for human verification** | **F24, F25, existing SwiftUI toolbar and settings controls** |

## Cycle 4 — Bug Fixes & Enhancements (complete)

| Parent | Code | Sub-Feature | Status |
|--------|------|-------------|--------|
| F03 | F03-A | Persistence & Resume | done |
| F03 | F03-B | In-Workout Controls & Media | done |
| F04 | F04-A | Streaks & Partial Logging | done |
| F05 | F05-A | Import, Export & Previews | done |
| F06 | F06-A | Text Selection | done |
| F07 | F07-A | UI Polish | done |

## Cycle 5 — File-Based Data Revolution (REV-01)

| Parent | Code | Sub-Feature | Status |
|--------|------|-------------|--------|
| F09 | - | File-Based Data Architecture | pending |
| F09 | F09-A | TimeMasterCore (shared library) | pending |
| F09 | F09-B | Knowledge Layer + AGENTS.md | pending |
| F09 | F09-C | CLI Tool (`timemaster-tool`) | pending |
| F09 | F09-D | AI Tool Calling (in-app + external) | pending |
| F09 | F09-E | Mac App (native macOS build) | pending |
| F01 | F01-A | Migrate models to file manifests | pending (after F09-A) |
| F05 | F05-A-v2 | Import → Exercises Database/ | done (after F09-A, F01-A) |
| F06 | F06-B | AI Database Creation (tool-calling) | pending (after F09-D) |

## V2 Sub-Features (Cycle 6 — Notion-Style Rework, after F09)

| Parent | Code | Sub-Feature | Status |
|--------|------|-------------|--------|
| F01 | F01-B | Unified Page Model | in_progress |
| F02 | F02-A | Workout Builder Rework | pending |
| F04 | F04-B | Flame Streak + Per-Type Analytics | pending |
| F07 | F07-B | Notification Pipeline | pending |
| F07 | F07-C | Workout Types & Schedules (extended) | pending |

## Cycle 10 — V0.3 Cleanup & Real-World Polish (planned 2026-07-13 from ISSUES.md)

| Code | Sub-Feature | Status |
|------|-------------|--------|
| F13 | Stability & Freeze Investigation (Phase 0 — first) | pending |
| F14 | Database Hierarchy Model (root container vs leaf exercise) | pending |
| F15 | V2 Workout Management Rework | pending |
| F16 | V2 Player Rework | pending |
| F17 | Minimalist Text Cleanup | pending |
| F18 | macOS Polish (window clip, box artifacts, settings crash) | pending |
| F19 | Music Behavior (general upload + sequential default) | pending |
| F20 | Scheduled-Today Home Widget & Missed-Red Indicator | pending |
| F21 | Home Quick Settings Access | pending |
| F22 | Per-Type Time-of-Day Schedule | pending |
| F23 | Editor Database Picker Fix (old empty DB issue) | pending |

## Build Order
```
F01-F08 (done) → F09 → {F09-A → F09-B → F09-C → F09-D}
                            ↓
              F01-A, F05-A-v2, F06-B (parallel after F09-A)
                            ↓
                       F01-B, F02-A, F04-B, F07-B/C (Cycle 6-7)
                            ↓
                       Cycle 8-9 (F10-F12 complete)
                            ↓
                       Cycle 10 — F13 first, then F14 + F23, then F15 + F16 paired,
                            then F17/F18/F19/F20/F21/F22 parallel polish
```

## _archive/
- SPEC.md — original V1 spec from pre-documentation era (superseded by genesis/ORIGINAL IDEA.md + features/DOCKS.md)
- PROVIDER_SYSTEM_SKILL.md — AI provider plug-in pattern (reference, not a feature doc)
