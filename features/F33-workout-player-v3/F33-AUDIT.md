# F33 Audit — workout player, 2026-11-27

Scope: why the player feels messy, old and slow, and what the rebuild must fix. Static reading of the code plus the real library on this Mac; no profiler run, no device run. Items marked INFERENCE are not reproduced.

## Findings

| Complaint | Cause found | Evidence |
|---|---|---|
| Slow, messy | One 2163-line view with 55 `@State`, 18 `some View` properties and 10 `some View` methods; the 1 s timer changes `@State`, so the whole body re-evaluates every second (media catalog rebuilt, queue items rebuilt). Each phase swaps a whole subtree through `if/else`, which recreates the cover and video views. The backdrop is a full-screen image scaled 2.6x with a 28 pt blur. `saveResumeState()` is called from 12 places and also syncs the Live Activity and Now Playing. | `WorkoutPlayerView.swift` (`contentLayer`, `backgroundLayer`, `startTimer`, `tick`, `currentMediaCatalog`); the engine split planned as F16-A/B in CYCLES Cycle 10 was never built. Cost per tick is INFERENCE. |
| Video does not loop in the middle | Bundle: the "now" card draws only a still cover. Single: the looping player is created once in `onAppear`, the pager rows have index identity, and the media index resets only on section change, edit or restore, so an exercise change with no rest or preparation between keeps the old clip (INFERENCE from SwiftUI identity rules). The loop is not muted although every attachment used in the mockups carries an AAC audio track (ffprobe on all 10 clips); `PageWidgetClipsTile` already mutes. | `PlayerBundleStage.swift` (`PlayerNowCard`), `WorkoutMediaPager.swift` (`WorkoutLoopingVideo`, `card`), `WorkoutPlayerView.swift` lines 76, 279, 324, 1595 |
| Static UI | 9 animation call sites in the whole file, no shared-element motion, haptics only at logical phase changes (12 calls) and none on button presses or card movement. Transport and chrome buttons use `.buttonStyle(.plain)`. | `WorkoutPlayerView.swift`, `PlayerControls.swift`, `WorkoutHaptics.swift` |
| Time not in our font | The clock is Inter Black with tabular digits. The TimeMaster ribbon face has 54 glyphs (A-Z, a-z, space): no digits and no colon, so it cannot draw a time. Fact labels and the Live Activity timer use SF Rounded. Docs say Manrope for body text, code uses Inter 18pt Bold. | `PlayerControls.swift:10-13`, `PlayerUpNextCard.swift:125`, `TmaxLiveParts.swift:16-17`, `ProfileDesign.swift`, font table of `TimeMaster-Regular.ttf` |
| Not Apple style | Flat white-12 % circles instead of glass; the bounce engine only on rest +/- and Done. iOS 27 adds no glass modifier: the material changes by itself, people get a Liquid Glass transparency slider, Reduce Transparency and Contrast still apply, and iPhone apps become resizable, so fixed 402 x 874 geometry is out. HIG: glass for controls and navigation, not content; clear glass over media needs a 35 % dim. | Apple "What's new in SwiftUI" WWDC26, HIG Materials, HIG Playing haptics |
| Resume opens a slide-over | The resume prompt is a `.sheet` with medium and large detents. Every Start request (widget `timemaster://start`, command bus, links) is sent to it whenever a checkpoint exists. Its Resume button dismisses the sheet and presents the full-screen player in one update (INFERENCE: race). The Home Continue card itself opens the full-screen cover directly. | `WorkoutResumeView.swift:42-44`, `TmaxApp.swift:214-215, 286-293, 343-346`, `HomeWidgetViews.swift:216-237` |
| Finished workout offered for resume | `completeWorkout()` clears the checkpoint, but the unguarded `didEnterBackground` handler and the background-task expiry handler call `saveResumeState()` again, which rewrites a checkpoint past the last section and sets `hasResumableWorkout`. Closing the app on the finished screen reproduces it by reading (INFERENCE). | `WorkoutPlayerView.swift:348-351, 1300, 1869`, `WorkoutResumeManager.swift:72` |
| Rest indicator without the rest exercise | The model has a rest exercise and alternatives per rest; the player shows only a text button. No workout in the library has one set (0 of 191 scanned), so the mockups attach real pages to show the place. | `WorkoutManifest.swift:133-134, 216-218`, `WorkoutPlayerView.swift` (`PlayerRestExerciseChoices`) |
| Voice | `speakPhase` stops speech at every phase and on pause. In the rebuild the voice belongs to the session: slides, sheets, preview and resume never cut it. | `WorkoutPlayerView.swift` (`speakPhase`, `pauseTimer`) |

## Rebuild shape (for the Revolution Protocol, path B)

- Engine without UI: phase list, a deadline-based phase clock, commands (next, back, jump, pause), voice, haptics and the checkpoint. Screens only render its state; the clock is its own leaf view so nothing else redraws each second.
- One presentation host for the player and the resume screen, full screen, used by Home, Schedule, workouts, widget links and resume.
- Checkpoint guard: nothing is written after finish, an out-of-range or stale checkpoint is dropped at load.
- One muted looping clip player per visible card, reused when the exercise changes; backdrop from a small cached bitmap, not a live blur.
- Gooey glass controls: `GlassEffectContainer` plus the EverBounce press; iOS 16 keeps the frosted fallback.
- Haptics matched to the motion: soft at the start of a slide, rigid when the card lands, soft on the rebound; selection ticks for paging; success at the end.

## Open decisions

- Time font: Inter Black tabular (works now) or the ribbon face, which needs 0-9 and ":" drawn first.
- Card direction: right to left on Next, left to right on Back (the mockups) or mirrored.
- Whether the full motion path may require iOS 17 or stays behind an iOS 16 fallback.

Mockups: `junk/workout-redesign/` (local, see CYCLES Cycle 78).
