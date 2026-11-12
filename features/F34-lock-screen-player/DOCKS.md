# F34 — Lock Screen Workout: Live Activity and Now Playing

While a workout runs and the phone is locked or Tmax is in the background, the workout stays visible and controllable from the Lock Screen. On iOS 17 and later it is a Live Activity (also in the Dynamic Island). On iOS 16, where Tmax's Live Activity cannot run, the workout appears as a music player in the Lock Screen and Control Center, and its controls move the workout.

## Why It Exists

A workout is performed with the phone on a floor, a mat or a bench, often locked. Looking at it should answer three questions without reading: what is happening now, how much time is left, and what is next. Pause and skip must be one touch away without unlocking.

## Visual Principle

The Lock Screen surfaces are driven by pictures, rings and dots, not sentences. Each exercise shows its cover as a small artwork tile. The next exercise shows as a second small tile. Time is a large self-ticking number inside or beside a ring. Position in the workout is a row of dots (or a bar when there are many).

## iOS 17 and Later: Live Activity

- **Lock Screen and banner.** Left: a rounded tile with the exercise's cover (or a glyph in a neutral tile when there is no cover), wrapped in a progress ring. Centre: the time, the exercise title on one line and the workout name small. Right: an Up Next tile with the next exercise's cover; during a rest it is larger and shows the name. Bottom: position dots (a bar above ten), two round buttons (pause or resume, and skip to the next step), a slim bar for the current step and a thinner bar for the whole workout.
- **Dynamic Island.** Compact: the cover or a glyph on the left, the time on the right. Minimal: a ring with the cover or glyph. Expanded: the tile, the time, the title, the Up Next tile, the dots and both buttons.
- **Colour language.** The same as the app's player: black and white. Work uses the workout's own colour (orange by default); every other phase (warm-up, get-ready, rest, completed) is white, with a phase glyph; paused dims the ring and shows a pause glyph. There is no teal, amber, red-orange or green.
- **Completed.** A full white ring with a check, the total time large, then it lingers briefly and dismisses.
- **Without covers.** Where the shared App Group is unavailable (for example some sideloaded builds) every layout falls back to glyphs and colour and still looks complete.
- **Accessibility.** The title carries one spoken sentence that replaces the dropped text ("Rest, up next Single Leg Takedown, set 2 of 5, section 2 of 3"); the time stays a separate, live element. Text sizes are capped so the fixed-height banner never clips.
- **Where it starts and ends.** It starts with the first step after the warm-up choice, updates only when something visible changes, ends with the workout or when the person stops it, and is removed at launch when no workout can be resumed.

## iOS 16: Now Playing

- **The workout is the track.** The title is the current step ("Sprawl", "Rest", "Get ready"), the artist is the workout name, the album line carries position and what is next, the artwork is the exercise cover (during a rest, the next exercise's cover), the duration is the current step's length and the elapsed time is how far into it the person is.
- **Controls.**
  - Play and Pause (also headphone and car buttons) pause and resume the workout.
  - Next and Previous move to the next or previous exercise; Previous restarts the current exercise when it has run for more than three seconds.
  - Alternatively, skip buttons move the time forward or back by a chosen number of seconds.
  - The scrubber moves the position inside the current step.
- **Settings, Workout, Lock Screen Player (shown on iOS 16 only).** Choose between exercise buttons and seconds buttons; choose 5, 10, 15, 30 or 60 seconds for the skip buttons; switch scrubbing on or off.
- **Stopping the music stops the workout.** When something else takes the audio (a call, another app), or headphones are unplugged, the workout pauses. It never resumes by itself.
- **How it stays alive.** While a workout runs on iOS 16, Tmax holds an exclusive audio session with an inaudible loop so the system keeps Tmax as the Now Playing app. This pauses audio from other apps for the length of the workout, as any music player would. Workout music and spoken prompts play as before. When the workout ends, the session is released and other audio may resume.

## Haptics

Haptics are in the player itself (see F33): a countdown tap at three, two and one, a double thump when an exercise starts, a soft tap for get-ready and warm-up, a medium tap when a rest starts, a warning-style tap for a section break, a selection tick on pause, a light tap on resume and when rest is extended, and a success pattern at the end. One switch in Settings, Workout, Haptics turns them off. They fire while the app is open; iOS does not allow haptics from a locked phone.

## States

| State | What is shown |
|---|---|
| Warm-up | Flame glyph, countdown, first exercise as Up Next |
| Get ready | Hourglass-style glyph, the exercise about to start |
| Work | Cover tile with ring, time, title, position, Up Next |
| Rest | White ring and time, larger Up Next tile with name |
| Paused | Dimmed ring, pause glyph, time frozen; on iOS 16 the player shows paused |
| Completed | White ring and check, total time |
| No cover, no App Group | Glyph tiles only |
| Stale | Dimmed time and a hint to open Tmax |
| iOS 16 without a workout | No Now Playing entry; controls disabled |

## Limits

- The Live Activity needs iOS 17 or later; the Now Playing player is used on iOS 16 only.
- The exclusive audio session pauses other apps' audio while a workout runs on iOS 16.
- The Mac has no Live Activity; it keeps its menu bar companion.

## Files

- `TimeMasterShared/WorkoutActivityAttributes.swift`, `WorkoutLiveActivityModel.swift`, `WorkoutLiveActivityArtwork.swift`, `WorkoutLiveIntents.swift`
- `TimeMasterWidget/TmaxWorkoutLiveActivity.swift`, `TmaxLiveParts.swift`, `TmaxLiveLockScreenView.swift`
- `TimeMaster/Services/WorkoutLiveActivityController.swift`
- `TimeMaster/Services/WorkoutNowPlayingController.swift` — iOS 16 player
- `TimeMaster/Utilities/WorkoutHaptics.swift`, `TimeMaster/Utilities/AudioManager.swift` (session modes)
- `TimeMaster/Views/Settings/WorkoutPlayerSettingsCards.swift`

## Dependencies

- F03 Timer and Player, F11 Resilient Background Timer, F19 Music Behavior, F33 Workout Player

## Reference

- `CYCLES.md` Cycle 43 (first Live Activity) and Cycle 62
