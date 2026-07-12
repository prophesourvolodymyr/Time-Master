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
| **F09** | **File-Based Data Architecture** | **pending** | **F01, F06** |

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

## Build Order
```
F01-F08 (done) → F09 → {F09-A → F09-B → F09-C → F09-D}
                            ↓
              F01-A, F05-A-v2, F06-B (parallel after F09-A)
                            ↓
                       F01-B, F02-A, F04-B, F07-B/C (Cycle 6)
```

## _archive/
- SPEC.md — original V1 spec from pre-documentation era (superseded by genesis/ORIGINAL IDEA.md + features/DOCKS.md)
- PROVIDER_SYSTEM_SKILL.md — AI provider plug-in pattern (reference, not a feature doc)
