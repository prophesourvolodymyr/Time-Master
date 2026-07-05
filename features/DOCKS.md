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

## Active Sub-Features (Cycle 4 — Bug Fixes & Enhancements)

| Parent | Code | Sub-Feature | Status |
|--------|------|-------------|--------|
| F03 | F03-A | Persistence & Resume | pending |
| F03 | F03-B | In-Workout Controls & Media | pending |
| F04 | F04-A | Streaks & Partial Logging | pending |
| F05 | F05-A | Import, Export & Previews | pending |
| F06 | F06-A | Text Selection | done |
| F07 | F07-A | UI Polish | done |

## V2 Sub-Features (Cycle 5 — Notion-Style Rework)

| Parent | Code | Sub-Feature | Status |
|--------|------|-------------|--------|
| F01 | F01-A | Unified Page Model | pending |
| F02 | F02-A | Workout Builder Rework | pending |
| F02-A | F02-A-a | Database Browser + Workout Page | pending |
| F02-A | F02-A-b | Drag-to-Build + Sets | pending |
| F02-A | F02-A-c | Bundle Section Mode | pending |
| F02-A | F02-A-d | Player Page Popup | pending |
| F03 | F03-C | Player Overlay | pending |
| F04 | F04-B | Flame Streak + Per-Type Analytics | pending |
| F05 | F05-B | Notion-Style Pages | pending |
| F06 | F06-B | AI Database Creation | pending |
| F07 | F07-B | Notification Pipeline | pending |
| F07 | F07-C | Workout Types & Schedules | pending |

## Build Order
F01 (foundation) → F02/F03/F04/F05/F06/F07/F08 (parallel-eligible after F01)

## _archive/
- SPEC.md — original spec (superseded by genesis/)
- PROVIDER_SYSTEM_SKILL.md — architectural pattern reference
