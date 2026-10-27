# F30-C-c — Workout Builder Chapter

The story of building a workout in seconds. It follows the shared chapter template: an intro moment, fast beats with real recordings sliding in from the side borders, and a clear-out into the stats.

## What We Build

- **The intro moment:** the headline "Build it in seconds." stays in place while the page is held. As the visitor scrolls, the cards of a real-looking workout fly in from every border, tilted and scattered, and snap into an ordered workout: a warm-up, push-ups, a core bundle, a rest, and pistol squats. Timed exercises use the app's orange base. The bundle uses the app's white base, matching how the app tells bundles and timed exercises apart.
- **Beats.** Each beat has a real recording and two short lines:
  1. **Drag. Drop. Done.** Exercises are dragged from the library into a workout, with sets, reps, rest, and timing edited right on the card.
  2. **Bundles that shuffle.** Moves are grouped into one timed bundle and run in order or shuffled every set.
  3. **A soundtrack with a timeline.** Songs and playlists are placed on the workout's own music timeline. The main track takes over, and the background music resumes where it left off.
  4. **Edit while you sweat.** Sets can be changed mid-workout without stopping the clock. The timer follows to the Lock Screen and the Dynamic Island.
  5. **On schedule. On you.** Workouts are planned by day and time. A missed session gets a nudge an hour after the reminder.
- Every line describes behavior the app ships today.

## States

| State | Behavior |
|---|---|
| Intro scrolling | The cards assemble in step with the scroll and disassemble when scrolling back. |
| Recording not yet available | The device frame stays empty and dark. Nothing is faked. |
| Reduced motion | The workout appears already assembled, and the beats appear without sliding. |
| Phone | The cards stack at full width and the beats stack the phone above the text. |

## Dependencies

- [F30-C](../DOCKS.md): the chapter template and switcher.
- [F30-E](../../F30-E-media-production/DOCKS.md): the builder, bundle, music, player, and schedule recordings.
