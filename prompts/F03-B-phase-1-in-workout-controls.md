# Phase 1 of F03-B — In-Workout Controls & Media

## Context
Time-Master V1 iOS app. F03-B adds rest preview (next exercise thumbnail during rest), full-screen media overlay during workout (tap photo → preview, timer continues), and mid-workout rest adjustment (+15s/+30s buttons).

## What You Need to Read First
- `features/F03-timer-player/F03-B-in-workout-controls/DOCKS.md`
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (full player, all phases, state management)
- `TimeMaster/Views/WorkoutDetail/MediaPreviewSheet.swift` (existing full-screen media viewer)
- `TimeMaster/Utilities/Theme.swift`

## What Happened Last Session
F03-A completed: background persistence, resume, partial logging, live activities built.

## What to Build

### 1. Rest Preview — Next Exercise During Rest
- During rest phase (sectionRest), show next exercise photo/video centered in a rounded card
- Card: ~200x200pt, 50% opacity fade-in, with rounded corners (16pt)
- Below card: "Next: [Exercise Name]" in Theme.textSecondary
- Smooth crossfade: current exercise photo fades out, next preview fades in
- If no next exercise (last section): show "Workout Almost Done" text or wind-down preview
- Tap on preview thumbnail → opens full-screen viewer (#2)

### 2. Full Media Preview During Workout
- Tap on current exercise photo during active phase → full-screen overlay
- Overlay: dark background (Theme.background with 0.95 opacity), media centered
- Timer overlay in top corner showing remaining time (monospaced, white, 20pt)
- If photo: zoom/pan gestures. If video: play/pause/seek with AVPlayer controls
- Tap background or swipe down to dismiss overlay
- CRITICAL: workout timer continues running while overlay is open
- Section end → overlay auto-dismisses, normal transition occurs
- Transition: scale from tap point + fade, duration 0.3s

### 3. Mid-Workout Rest Adjustment
- During rest phase (both setRest and sectionRest), show floating buttons:
  - "+15s" button (left side)
  - "+30s" button (right side)
- Buttons: pill shape, Theme.surface bg, white text, 14pt font
- Tapping adds time to current rest timer
- Timer label briefly flashes "+X seconds" then resumes counting from new value
- Multiple extensions stack (e.g., +15 then +30 = +45s total added)
- Max total rest per period: 120s (enforced — buttons disable at cap)
- Long-press on rest timer: opens quick picker (15s, 30s, 60s, Custom)
- Buttons hidden during active exercise phases

## Files to Create/Modify
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — rest preview overlay, media overlay, rest buttons (all modifications to existing view)

## Verification
- [ ] Rest period shows next exercise photo preview centered
- [ ] Next exercise name visible below preview
- [ ] Tap preview → opens full-screen overlay without stopping timer
- [ ] Tap exercise photo during workout → full-screen overlay with timer in corner
- [ ] Overlay dismisses on tap/gesture, timer continues
- [ ] Video playback in overlay works, timer unaffected
- [ ] +15s and +30s buttons visible only during rest
- [ ] Buttons extend timer correctly, multiple stacks work
- [ ] Max 120s enforced, buttons disable
- [ ] Long-press timer → quick picker
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F03-B): rest preview, full media overlay, rest adjustment"
3. **GENERATE THE NEXT PROMPT:** Create `prompts/F04-A-phase-1-streaks.md`
