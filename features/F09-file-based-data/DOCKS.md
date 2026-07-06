# F09 — File-Based Data Architecture

Converts the entire app data layer from UserDefaults JSON blobs to a transparent, AI-readable file-system database. Every exercise, workout, config, and history entry becomes a folder with manifest files. AI agents and the app itself read/write through a single validated core library.

## What We Build

1. **Root directory structure** — `~/Documents/TimeMaster/` with clean folder hierarchy
2. **`schema.json`** — declarative contract defining every object type, property, tool, and filesystem path
3. **`AGENTS.md`** (root of data dir) — instructions for external AI agents on how to work inside
4. **Exercises Database/** — unlimited nesting, every exercise is a folder with `manifest.json` + `guide.md` + media
5. **Workouts/** — each workout is a `manifest.json` referencing exercise IDs
6. **Workspace/** — AI sandbox (temp/, exports/) — external folders ignored by the app
7. **Knowledge/** — AI loads `*.md` files as system prompt prefix on session start
8. **`skills/`** — reusable AI agent skill files inside the data directory
9. **Config/**, **History/** (JSONL), **Music/**, **Backups/** — all file-based
10. All writes go through **F09-A TimeMasterCore** — no direct filesystem mutation by app or AI

## Architecture

```
~/Documents/TimeMaster/
├── AGENTS.md
├── schema.json
├── skills/
├── Knowledge/
├── Media/
├── Exercises Database/        ← unlimited nesting
├── Workouts/
├── Workspace/                 ← AI sandbox, ignored by app
├── Config/
├── History/
├── Music/
├── Backups/
└── .trash/                    ← soft-deleted items, recoverable

App Layer:
  iOS app ───┐
  Mac app ───┼── TimeMasterCore (F09-A) ── filesystem
  CLI tool ──┘     ↑ validator + single writer

AI Layer:
  In-app AI coach ── function-calling loop (F09-D)
  External AI agents ── CLI tool (F09-C) ── TimeMasterCore
```

## Key Rules

- **Unlimited nesting** — exercises can nest infinitely (folder → sub-exercise → sub-sub-exercise...)
- **External folders ignored** — anything not matching a known schema is skipped silently
- **Every folder is self-describing** — a `manifest.json` in any folder is a complete object
- **AI never touches filesystem** — only calls tools defined in `schema.json`, routed through `TimeMasterCore`
- **Workspace/** is a free zone — AI can create/delete anything there, app ignores it
- **Never-lose-data** — deletions go to `.trash/`, AI writes require approval gate, auto-backup before AI sessions

## Files
- `TimeMasterCore/` (new Swift package) — all validation, reading, writing
- `schema.json` (generated from type definitions) — auto-updated from Swift types
- Data directory created on first launch at `~/Documents/TimeMaster/` (Mac) / sandbox Documents (iOS)

## Dependencies
- F01 — Core Data Layer (models migrate from UserDefaults to file-system manifests)
- F06 — AI Coach (gains tool-calling loop, F09-D)

## Verification
- [ ] Directory created on first launch on both iOS and Mac
- [ ] Exercises Database supports unlimited nesting
- [ ] External folders in root cause no errors, app skips them
- [ ] schema.json is valid JSON, describes all object types
- [ ] TimeMasterCore validates writes, rejects malformed manifests
- [ ] Workspace/ accessible by AI, ignored by app UI
- [ ] AGENTS.md exists at root and contains valid instructions
