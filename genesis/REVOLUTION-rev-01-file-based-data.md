# Revolution: File-Based Data Architecture — COLOSSAL

## Why This Revolution
Current data layer stores everything as JSON blobs in UserDefaults. This blocks external AI agents from reading/writing, makes the data opaque to users, prevents unlimited exercise nesting, and ties the Mac version to the iOS sandbox model. We need a transparent, AI-friendly, file-system database that both the app and external AI agents can work with.

## What Changes
1. **Data moves from UserDefaults → file system** — `~/Documents/TimeMaster/` directory
2. **Every exercise is a folder** with `manifest.json` + `guide.md` + media + links — unlimited nesting
3. **New shared library** (`TimeMasterCore`) — single writer, validation layer, atomic writes
4. **CLI tool** (`timemaster-tool`) — external AI agents call this instead of touching files
5. **AI Knowledge layer** — `Knowledge/*.md` injected into AI system prompt on session start
6. **AI tool calling** — in-app AI coach gains structured function-calling to query/modify database
7. **Workspace/** — free sandbox for AI agents, ignored by the app
8. **AGENTS.md + skills/** — bootstrap guide for external AI agents
9. **Mac parity** — same directory structure, same core library, same tool definitions

## Migration Path
1. Build `TimeMasterCore` (F09-A) first — it's the foundation
2. Build `Knowledge Layer + AGENTS.md` (F09-B) — no breaking changes
3. Build CLI tool (F09-C) — thin wrapper, easy
4. Build AI tool calling (F09-D) — enhances existing AI Coach
5. Then migrate existing app stores to use `TimeMasterCore` instead of `WorkoutStore`/`DatabaseStore`
6. Remove old UserDefaults persistence after migration is verified

## Affected Features
- **F01** — Core Data Layer: models get file-based counterparts, stores migrate
- **F05** — Database Import: import now writes to `Exercises Database/` instead of UserDefaults
- **F06** — AI Coach: gains tool-calling loop and knowledge injection
- **F07** — Settings: config moves to `Config/` directory

## Architecture Decisions
- **Single writer rule** — all writes go through `TimeMasterCore.DatabaseManager`, no direct filesystem access
- **Atomic writes** — temp file → validate → rename, never corrupt
- **Unlimited nesting** — exercises can be folders containing sub-exercises, any depth
- **External ignorance** — folders not matching a known schema are skipped, never error
- **Two AI access paths** — in-app (function-calling loop) and external (CLI tool), same core
- **File format** — JSON for structured data (manifest.json), Markdown for guides, JSONL for history
- **Media** — shared `Media/` directory with UUID filenames, referenced by manifests

## Risk Assessment
- **HIGH** — Data migration from UserDefaults: must be zero-data-loss, with backup
- **MEDIUM** — Concurrency: app writes while AI reads — mitigated by single-writer rule
- **LOW** — User confusion: `Exercises Database/` in Finder may look cluttered — mitigated by UI-only views
- **LOW** — iOS sandbox differences: `Documents/` path differs from Mac — `FileManager.default` handles this
