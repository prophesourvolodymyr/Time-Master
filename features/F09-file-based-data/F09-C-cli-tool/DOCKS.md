# F09-C — CLI Tool (`timemaster-tool`)

Thin command-line wrapper around `TimeMasterCore`. External AI agents (Claude Desktop, Cursor, Terminal) call this instead of touching files directly. All commands route through `DatabaseManager` → validated, atomic writes.

## What We Build

1. **`timemaster-tool` binary** — compiled Swift executable, installed to `$PATH`
2. **Sub-commands for every operation** — `create-exercise`, `search-exercises`, `list-folders`, etc.
3. **JSON input/output** — STDIN JSON args → STDOUT JSON results → STDERR errors
4. **Read-only mode** — AI can query without write access (`--readonly` flag)
5. **Schema-aware** — reads `schema.json` at startup, respects constraints

## Commands

```
timemaster-tool list-exercises [--type Strength] [--query "push"]
  → JSON array of matching exercises

timemaster-tool get-exercise <id>
  → full manifest.json + guide.md content

timemaster-tool create-exercise <json>
  → creates folder + manifest.json, returns exercise ID

timemaster-tool update-exercise <id> <json>
  → validates + writes updated manifest

timemaster-tool delete-exercise <id>
  → removes exercise folder

timemaster-tool search-exercises <query> [--type ...]
  → walks tree, fuzzy-matches names, returns results

timemaster-tool list-workouts
  → all workout manifests

timemaster-tool build-workout <json>
  → creates workout from exercise IDs

timemaster-tool import-media <path>
  → copies file to Media/, returns UUID filename

timemaster-tool get-stats [--type ...] [--days 30]
  → analytics: workout count, streak, volume

timemaster-tool list-types
  → all workout types (built-in + custom)

timemaster-tool validate
  → walks entire directory, reports schema violations
```

## Architecture

```
timemaster-tool (Swift Package executable)
├── main.swift                    ← CLI entry point, argument parsing
├── Commands/
│   ├── ExerciseCommands.swift    ← create/update/delete/search exercises
│   ├── WorkoutCommands.swift     ← list/create workouts
│   ├── MediaCommands.swift       ← import/validate media
│   └── StatsCommands.swift       ← analytics queries
└── OutputFormatter.swift         ← JSON pretty-print, error formatting
    ↓ imports
TimeMasterCore (F09-A)
    ↓
Filesystem (~/Documents/TimeMaster/)
```

## States
| State | Behavior |
|---|---|
| Unknown command | Show help, exit 1 |
| Invalid JSON args | Show expected schema, exit 1 |
| Validation failure | Show specific field errors, exit 1 |
| Directory not bootstrapped | Auto-bootstrap, then execute |
| Success | Print JSON result to STDOUT, exit 0 |

## AI Integration Example

```bash
# Claude Desktop / Cursor / Terminal
$ timemaster-tool search-exercises --query "shoulder" --type Strength
[
  {"id":"push-ups","name":"Push-ups","type":"Strength","duration":30},
  {"id":"pike-push-ups","name":"Pike Push-ups","type":"Strength","duration":30}
]

$ timemaster-tool create-exercise '{"name":"Wall Walk","duration":30,"type":"Strength","parentID":"handstand"}'
Created: Exercises Database/handstand/wall-walks/wall-walk/

$ timemaster-tool import-media ~/Downloads/demo.mp4
{"filename":"a3f7b2c1.mp4"}
```

## Build & Install
```bash
cd TimeMasterCore
swift build -c release
cp .build/release/timemaster-tool /usr/local/bin/
```

## Files
- `timemaster-tool/` (new Swift Package with executable target)
- `timemaster-tool/Sources/main.swift`
- `timemaster-tool/Sources/Commands/ExerciseCommands.swift`
- `timemaster-tool/Sources/OutputFormatter.swift`

## Dependencies
- F09-A — TimeMasterCore (imports DatabaseManager, all models)

## Verification
- [ ] `timemaster-tool list-exercises` returns JSON
- [ ] `timemaster-tool create-exercise` creates folder + manifest
- [ ] `timemaster-tool validate` detects corrupted manifest
- [ ] Invalid JSON args → useful error message, not crash
- [ ] `timemaster-tool import-media` copies file, returns UUID name
- [ ] Can be called from Claude Desktop / Terminal successfully
