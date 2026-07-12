# Phase 7 of F01-B — F02-A-d — Player Page Popup

## Context
We are building the V2 Notion-style Unified Page Model. Phase 6 completed drag-to-build + inline config + bundle mode: DatabasePageBrowserSheet (embedded V2 browser in workout context with grid/list/search/filter/sort, preview bar with config steppers, bundle mode for multi-select), inline SectionConfigCard in WorkoutDetailView with editable Dur/Sets/Reps/Rest/Btwn steppers + Confirm/Cancel, repCount field on Section + WorkoutSectionManifest + playback display, Reps stepper in WorkoutPickerSheet, and "Browse Pages" toolbar button. All 63 core tests pass, macOS arm64 build succeeds.

## What You Need to Read First
- `features/F02-workout-management/F02-A-workout-builder/F02-A-d-player-page-popup/DOCKS.md` — full spec
- `features/F02-workout-management/F02-A-workout-builder/DOCKS.md` — parent spec
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — existing player (timer, phases, media carousel, confetti)
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — page detail view (cover hero, markdown, media, links, tags, children)
- `TimeMaster/Views/Database/PageCardView.swift` — card view
- `TimeMaster/Views/Database/VideoEmbedCard.swift` — YouTube/inline video embeds
- `TimeMaster/Views/Database/PageMediaGallery.swift` — media gallery

## What Happened Last Session (Phase 6)
- repCount field added to Section model and WorkoutSectionManifest (Codable, min 1)
- WorkoutStore conversion handles repCount; WorkoutPickerSheet has Reps stepper
- WorkoutPlayerView shows repCount during active section (below set counter)
- DatabasePageBrowserSheet created: full V2 browser (search/filter chips/sort/grid-list) in workout context, preview bar with Dur/Sets/Reps/Rest/Btwn compact steppers, "Add Section" button, bundle mode toggle with checkmarks and "Create Bundle Section"
- WorkoutDetailView: "Browse Pages" toolbar button, inline SectionConfigCard at top of sections list with editable steppers + Confirm/Cancel, pending section flow, improved section cell with integrated media thumbnail and drag handle
- DatabaseStore wired as environment object to WorkoutDetailView
- Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions

## What to Build

### Task — Player Page Popup
- Tap exercise name, photo, or dedicated "Open Page" button during workout → opens full ExercisePage overlay
- Overlay shows the complete page content: cover image, markdown body, media gallery, links (YouTube embed), tags
- Page content is scrollable — user can browse everything about the exercise mid-workout
- Tap to dismiss overlay, returning to the player at current position

### Task — Floating Controls Bar
- Always visible on top of the exercise page overlay
- Semi-transparent pill bar showing:
  - Time remaining in current section/set (countdown)
  - Pause/Resume button
  - Stop workout button (with confirmation)
  - Exercise name + section progress (e.g. "3 of 5")
  - Skip section button (forward.end.fill)
- Bar is compact (40-50pt height), not obstructing content
- For bundle sections: shows elapsed time instead of countdown

### States
| Player state | Overlay | Controls |
|-------------|---------|----------|
| Timed, active | Page open, timer running | Shows countdown, pause, stop, section progress |
| Timed, rest | Page open, rest timer running | Shows rest countdown, skip rest |
| Bundle, active | Page open | Shows elapsed time, next exercise preview |
| Overlay dismissed | Return to player | Full player UI restored |

## Files to Create/Modify
- **create:** `TimeMaster/Views/Player/ExercisePageOverlay.swift` — full-screen page viewer overlay
- **create:** `TimeMaster/Views/Player/FloatingControlsBar.swift` — compact pill controls bar
- **modify:** `TimeMaster/Views/Player/WorkoutPlayerView.swift` — add page popup trigger on exercise name/photo tap, integrate overlay

## Verification
- [ ] Tap exercise name in player → full page overlay opens
- [ ] Page shows all content: cover, markdown, media, links
- [ ] Floating controls bar visible with timer, pause, stop, skip
- [ ] Timer continues running while overlay is open
- [ ] Pause/stop/skip work from floating controls
- [ ] Dismiss overlay → return to player at current position
- [ ] Bundle mode: elapsed time shown in controls
- [ ] macOS arm64 build succeeds
- [ ] All 63 core tests pass (no regressions)

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create the next prompt file.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
