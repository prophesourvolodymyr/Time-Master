# P07 — Project Conversion

Convert an existing project (with any documentation system — or none at all) into this management system. Discover what docs exist, analyze the codebase if undocumented, propose a mapping, archive old docs, create new structure. Nothing gets deleted.

## Phase 1 — Discovery
1. Find all existing documentation files
2. Classify project type (iOS app, web app, library, etc.)
3. Map codebase structure (files, folders, architecture)
4. Identify what features already exist in the code
5. Propose feature breakdown + DOCKS.md mapping

## Phase 2 — Execution
1. Create genesis/ORIGINAL IDEA.md (from any existing spec/readme)
2. Create features/DOCKS.md index
3. Create feature DOCKS.md files for each discovered feature
4. Create CYCLES.md marking what's built
5. Archive old docs to features/_archive/
6. Update AGENTS.md section 0

## Rules
- Never delete old documentation — archive only
- DOCKS.md files document what WAS built (if code exists) or what WILL be built (if new)
- All features get numbered F01-FNN
- Verification checkboxes reflect actual build state
