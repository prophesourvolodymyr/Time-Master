# P01 — Feature Audit

Read a feature's DOCKS.md, research the internet for reference implementations, interrogate every assumption, flag problems, propose ideas — deliver it all as a structured audit so the user knows exactly what gaps exist before building.

## When to Use
Before writing any code for a feature that has unknowns.

## Checklist
1. Read the feature's DOCKS.md + all dependency DOCKS.md files
2. Confirm understanding with user (3-line summary)
3. Ask 10 sharp questions — challenge every assumption
4. Extract the UX vision (what user sees, every state)
5. Draw ASCII diagrams (state machine, animation timeline, component hierarchy, data flow)
6. Propose 4 AI-approved additions user didn't ask for
7. User confirms → write FNN-AUDIT.md → implement

## When to Skip
- Bug fixes (no unknowns)
- Small refactors (no new design decisions)
- Simple sub-features fully specified in DOCKS.md
