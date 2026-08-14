# P09: Documentation Integrity Audit

**System ID:** `DOC-01`
**Trigger:** User says "audit our docs", "check CYCLES.md", "clean up feature docs", "redocument this project", or "make the documentation logical."
**Input Requirement:** An initialized project with any amount of `genesis/`, `features/`, `CYCLES.md`, prompts, and source code.
**Output:** A complete documentation/cycle integrity report. After user approval, repaired documentation that matches the actual project.

---

## PHASE 1: DOCUMENTATION AUDIT (Read Only)

**Do not change files in Phase 1.** Read first, map the project, then show the user what is wrong and how it will be fixed.

### 1.1 Read Everything

Read all relevant material:
- `AGENTS.md`, `CYCLES.md`, `STYLES.md`
- Everything in `genesis/`, including `REFERENCE/` and all raw feature folders
- `features/DOCKS.md`
- Every feature, sub-feature, and sub-sub-feature `DOCKS.md`
- `FXX-AUDIT.md` files
- `prompts/` grouped by feature
- Relevant source files, config, and git history when docs make claims about code

Delegate parallel reading of separate feature trees when the project is large. The main agent must synthesize all findings.

### 1.2 Validate the Feature Map

Check all of the following:

| Check | What Must Be True |
|---|---|
| Index | Every feature folder appears in `features/DOCKS.md`; no index entry points to a missing folder |
| Codes | Feature codes are unique and nesting is logical: `F01` → `F01-A` → `F01-A-a` |
| Parent/child ownership | Parent docs summarize; child docs own detailed behavior |
| Dependencies | Every dependency exists, is implemented and human-reviewed before dependent work, and contains no circular chain |
| Reference material | Relevant feature docs point to `genesis/REFERENCE/` when reference code exists |
| Files | Documented source files exist, or the doc clearly marks them as planned |
| Scope | No feature quietly owns unrelated work that should be split into child features |

### 1.3 Validate Every DOCKS.md

For each feature doc, determine whether it is adequate for its type:
- Clear deliverables and boundaries
- Architecture/data flow
- Every relevant state, failure, edge case, and transition
- Relevant type-specific detail: UI, storage, API, AI, migration, or infrastructure
- Files, dependencies, references, decisions, and human-review handoff context
- Locked decisions and open questions where needed

Flag vague documentation such as:
> "Build settings UI"

Replace it in the proposal with concrete behavior, states, files, and review context.

### 1.4 Validate CYCLES.md

Check that CYCLES.md:
- Has a dependency chain diagram matching feature docs
- Groups cycles under `# VX.X — Release Name` titles
- Contains every planned active feature exactly once
- Uses deep static checkbox trees for sub-tasks
- Does not start a feature before dependencies are implemented and human-reviewed
- Marks implementation work `[x]` only in CYCLES.md; this does not claim human verification
- Uses bundles only for small independent features
- Uses parallel cycles only when dependencies and files allow it
- Links prompt bundles or phase prompts to the correct feature folder when applicable

### 1.5 Deliver the Repair Plan

Present a direct report in chat:

```markdown
# Documentation Integrity Audit — [Project]

## Project Map
- Features found: F01, F02, F03-A...
- Raw features found: F04-raw
- Missing from index: F03

## Problems Found
1. F02 depends on F01, but F01 is not yet listed as human-reviewed.
2. F03-A combines search indexing, UI, and migration. Split into F03-A-a, F03-A-b, F03-A-c.
3. CYCLES.md starts F05 before its F03 dependency is complete.

## Proposed Repairs
- Rewrite `features/F02-storage/DOCKS.md` with error, migration, and rollback states.
- Create `features/F03-search/F03-A-a-indexer/DOCKS.md`.
- Rebuild the dependency chain and Cycle 2-4 tree.
- Preserve existing content and describe unresolved claims as open questions; put follow-up work only in CYCLES.md.

## Decision Needed
Approve the repair plan / modify it / keep specific docs unchanged.
```

**Stop. User approval is required before Phase 2.**

---

## PHASE 2: REPAIR & REDOCUMENT (After Approval)

### 2.1 Preserve Before Rewriting

- Never delete documentation.
- Keep Git history intact.
- Move obsolete docs to `features/_archive/` only when the user approved it.
- If a doc is rewritten in place, preserve important old decisions under a `## Historical Notes` section or in the approved archive.

### 2.2 Rebuild the Documentation Structure

Perform only the approved repairs:
- Create missing `DOCKS.md` files
- Split overloaded features into nested sub-features
- Merge duplicate docs only when the user approved it
- Rebuild `features/DOCKS.md` index
- Add `REFERENCE/` links to relevant docs
- Update dependencies, file ownership, states, and decisions
- Mark unknown behavior honestly as an open question; never invent completion claims

### 2.3 Rebuild CYCLES.md

Create or repair the static project plan:
- Dependency chain at the top
- `# VX.X — Name` release sections
- Deep checkbox trees per cycle
- Bundles for small independent features
- Parallel groups only where dependency and file ownership rules make them safe
- No implementation checkbox belongs outside CYCLES.md; `[x]` records implementation, not human verification

### 2.4 Verify the Repair

Read the final docs again and confirm:
- Every feature is indexed
- Every cycle todo maps to a real feature/sub-feature doc
- Every dependency points to a real implemented and human-reviewed predecessor
- Every prompt path maps to the correct feature prompt folder
- No old documentation was deleted

Commit the documentation repair with a clear message.

---

## EXECUTION CONSTRAINTS

1. **AUDIT FIRST.** Phase 1 is read-only. No silent documentation rewrite.
2. **USER APPROVES THE MAP.** User controls what gets split, merged, archived, or left alone.
3. **CODE BEATS STALE DOCS.** If docs conflict with observed code behavior, document the conflict and propose the correction. Do not silently assume either one is right.
4. **HUMAN REVIEW IS FINAL.** The AI may run engineering checks, but the human verifies every implemented feature. The AI must list each item for review and must not claim human approval.
5. **GO DEEP.** A large project may require sub-agents to audit independent feature trees, but the final map must be coherent as one system.

---

## COMPLETION CRITERIA

- The entire documentation tree and CYCLES.md are audited
- The user approves the repair plan
- The feature map, index, dependencies, and nested docs are repaired
- CYCLES.md is rebuilt or corrected as a static, logical plan
- Old docs are preserved or archived with approval
- Every implemented feature is listed separately in the final response as ready for human verification
- The documentation repair is committed
