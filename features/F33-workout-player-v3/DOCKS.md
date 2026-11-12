# F33 — Workout Player V3: Bundles, Up Next and the Original Player Look

The workout player keeps the Tmax look it always had and shows, in every phase, what is playing now and what plays next, with pictures instead of instructions. A bundle (several exercises played back to back, for example wrestling drills) is a first-class kind of section with its own playback rules, its own screen and its own agent tools.

## Why It Exists

A person who performs drills does not want to read the screen. They want to glance at it from a mat and see the current drill, the clock, and the drill that comes after the break. The earlier player showed what comes next only in one situation (the break between sections), and its bundle screen could not be navigated. An audit of bundles also found places where playback and the shown totals disagreed with the saved workout.

## What a Bundle Is

A bundle is one section of a workout. It has one or more sets (rounds). Every set plays all of its exercises once, one after another. Each exercise has its own length in seconds (as short as one second) and its own rest after it (zero switches straight to the next exercise). After the last exercise of a set comes the rest between sets. Before the first exercise of every set there is an optional get-ready time. The order is either fixed or shuffled each time the workout starts; a shuffle moves only exercises inside a set, and a drop set always stays right after its exercise. Spoken name callouts can be turned off. A bundle can be built in the app (Add to workout, Bundle) or by an agent.

## Playback Rules (one set of rules for every section)

- Every exercise, set and drop set of a section is played, in order. A drop set plays right after its exercise and its set: set, drop, then the rest.
- A rest that was deleted in the builder is not played. There is no hidden default rest.
- The workout's total time is exactly what plays: preparation, exercises, drops and rests, with no rest after the last section.
- The music timeline snaps to the same times, bundles included.
- "Extra rest" taps use the amount chosen in Settings, Workout, Extra Rest Time (a second button adds twice that), up to two minutes per rest.
- A position (exercise 4 of 6, set 2 of 3) always counts what is really played.

## Look

The player is black with the current cover heavily blurred behind it, white controls and white type, exactly as before. There are no phase colours: no teal, amber, red-orange or green. The only orange is the app's own orange glass buttons (extra rest, Done). The clock is the original big plain number, always centred on the screen: seconds only under a minute (for example 07), minutes and seconds from one minute (for example 1:15). Break screens keep the small spaced capital label above the clock (WARM UP, PREPARATION, REST BETWEEN SETS, REST). Pause and play is the original white circle with a black glyph.

## The Screens

- **Warm-up choice.** The original: the title Warm Up, six time buttons (Skip, 0:30, 1:00, 1:30, 2:00, 3:00) and a white Start button.
- **Warm-up.** The label, the centred clock, the white pause circle, the white Skip Warm Up button, and below it the Up Next card with the first exercise.
- **Get-ready.** The label, the centred clock, the pause circle, the white Skip Preparation button, and below it the Up Next card with the exercise about to start. In a bundle the whole queue shows under the card as small covers.
- **Work, single exercise.** The exercise's pictures as a swipeable pager (swipe up for notes), the exercise name with a book glyph that opens its page, dots for the sets (small and large dots, the current one stretched) with the length and reps, the clock, back, pause and next, and a small pill at the bottom with the next exercise's cover and name; tapping it previews that exercise. The last exercise shows a chequered flag instead.
- **Work, bundle.** A large "now" card (cover, name, length, white outline, play chip) with a tall "up next" card beside it at the right (cover, name, length, forward chip), or a chequered flag on the last exercise. Below: the whole queue as small covers, with a mark on finished ones, a white outline on the current one, a thin divider between sets and a shuffle glyph when the order is shuffled; tapping an upcoming or finished cover jumps to it, tapping the current one opens its page, a long press offers a preview. Then round dots, the clock and back, pause, next.
- **Rest (between exercises, between sets, between sections).** The label, set dots, a rest exercise button when the rest has one, the centred clock, the pause circle, the orange extra-rest buttons next to the white Skip Rest button, and below them the Up Next card: the exercise that comes after the break, or the first exercise of the next section. A bundle also shows its queue under the card (for a break between sections, the next section's queue). Pressing and holding the clock offers plus 15, 30 or 60 seconds.
- **Up Next card.** A wide card below the skip button: the cover at the left with a forward chip, the small label UP NEXT, the exercise name, its length and reps, and a book glyph at the right. Tapping it opens a preview of that exercise (its page, pictures, video and notes) over the player without stopping the clock; the card is inactive when the exercise has no page or media to preview.
- **Finished.** The original: a white check circle, Workout Complete, "Great job finishing" with the workout name, three small chips (time, exercises, sections), confetti and the orange Done button.
- **Top bar.** Close at the left; at the right the manage-workout button, the music button, the bundle settings button (bundles only) and the section badge (for example 1 / 2).
- **Backdrop.** The cover of the current exercise (during a break, of the next one), heavily blurred and dimmed.

## Navigation

- **Next** ends the current step (exercise, get-ready, warm-up or rest) and starts the next.
- **Back** restarts the current exercise if it has run for more than three seconds, otherwise goes to the previous exercise; during a break it goes back to the exercise before the break.
- **Jump.** In a bundle a tap on a cover in the queue starts that exercise.
- **Preview.** The Up Next card, the pill and the queue previews open the exercise page in an overlay without stopping the clock.
- The lock screen controls (F34) and the menu bar companion send the same commands.

## Haptics

Haptics play while the app is in front. A light tap at three, two and one seconds; a soft tap for warm-up and get-ready; a double thump when an exercise starts; a medium tap when a rest starts; a warning-style tap when a section break starts; a selection tick when pausing; a medium tap when resuming; a selection tick when rest is extended; a success pattern when the workout finishes. Settings, Workout, Haptics switches them all off.

## Agents

A bundle is fully manageable by an agent through the `tmax` command, MCP and the in-app Coach:
- `build_workout` accepts a section that is a bundle: exercises with their own seconds and rest, sets, rest between sets, order, spoken callouts and get-ready time.
- `get_workout` reads sections in order, with every bundle's sets, order and exercises; `list_workouts` shows how many bundles a workout has.
- `add_workout_section`, `update_workout_section` (change fields, replace exercises, change sets, move) and `remove_workout_section` (asks for approval) manage sections; `update_workout` renames a workout or changes its type or the rest between sections.
- A short guide, `skills/build-bundle.md`, explains it to agents.

## States

| State | What the person sees |
|---|---|
| Warm-up choice | Title, six time buttons, Start |
| Warm-up | Label, clock, pause circle, Skip Warm Up, Up Next card with the first exercise |
| Get-ready | Label, clock, pause circle, Skip Preparation, Up Next card with the exercise about to start, queue in a bundle |
| Work | Pager, name, dots and pill (single) or now, next and queue (bundle); clock and transport |
| Rest | Label, clock, pause circle, extra-rest buttons, Skip Rest, Up Next card, queue in a bundle |
| Paused | The pause button shows play; the clock stays |
| Last exercise | Chequered flag instead of a next card |
| No cover | A neutral tile with the exercise's glyph |
| Finished | Check circle, chips, confetti, Done |
| Workout edited while playing | The position is kept; a changed length changes the time left |
| App left and returned | The saved checkpoint is replayed through the same rules |

## Animation Rules

| What moves | How |
|---|---|
| Now and next cards | Slide one place with a soft spring (about 0.4 s); a fade with Reduce Motion |
| Queue | Scrolls the current cover to the centre in 0.3 s |
| Set dots | The current dot stretches with a soft spring |
| Extra-rest note | The added seconds appear above the clock and fade after about a second |
| Backdrop | Cross-fades in 0.4 s |
| Pause and play glyph | Replace each other (iOS 17 and Mac 14 and later) |

## Limits

- Shuffled order changes only inside a set.
- A workout with no covers uses neutral glyph tiles; the screens stay complete.

## Files

- `TimeMaster/Views/Player/WorkoutPlayerView.swift` — state machine and screens
- `PlayerStyle.swift`, `PlayerControls.swift`, `PlayerCoverImage.swift`, `PlayerUpNextCard.swift`, `PlayerBundleStage.swift`, `PlayerSetDots.swift`, `PlayerCompletedView.swift`, `PlayerConfettiView.swift`, `PlayerOverlayVideo.swift`
- `TimeMaster/Utilities/WorkoutHaptics.swift`, `TimeMaster/Views/Settings/WorkoutPlayerSettingsCards.swift`
- `TimeMasterCore/Sources/Models/WorkoutBundleSequence.swift` — one playback sequence for timed and bundle sections
- `TimeMasterCore/Sources/Agent/AgentToolRegistry+Bundles.swift`, `AgentToolbox+Bundles.swift`, `AgentToolbox+Workouts.swift`
- `TimeMasterCore/Sources/DatabaseManager+BootstrapBundleSkills.swift`

## Dependencies

- F02 Workout Management, F03 Timer and Player, F11 Resilient Background Timer, F16 Player V2, F19 Music Behavior, F31 Agent Bridge

## Reference

- `CYCLES.md` Cycle 9 and Cycle 42 (bundles), Cycle 62 (this feature)
