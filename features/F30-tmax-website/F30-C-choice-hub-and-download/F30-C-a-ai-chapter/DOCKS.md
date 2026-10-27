# F30-C-a — AI Chapter: Talos

The default chapter, and the one most visitors are curious about. It introduces Talos, the Tmax AI agent, as a real 3D character. It shows what the agent actually does in a few plain lines and lets the visitor watch a short simulation of creating their own agent. Just as they get attached to the agent they're building, the page interrupts them with a reason to get the app now.

## What We Build

- **Talos in 3D:** a real-time 3D model of the existing mascot. The character is a bald ivory-marble athlete with a fluted lower-face mask, a black scarf, black shorts, orange wrist wraps, and an orange belt. It is lit to match the site: a warm key light, a cool rim light, and orange accents on pure black.
- **The flashing introduction:** the chapter opens in darkness. Light flashes, like a photographer's strobe or a stadium blackout, reveal Talos in bursts. Then the words "Introducing Talos" land.
- **Talos travels with the visitor:** as the visitor scrolls on, the 3D Talos does not stay behind. It moves along a deliberate path, using GSAP to follow the scroll: it shrinks and drifts to the side opposite each incoming panel, turns to look at that panel, and floats with a slow, heavy idle motion. Its movement is choreographed, never random.
- **What Talos does, in simple lines:** a short sequence of beats. Each beat pairs one plain sentence with a real recording that slides out from a side border. The capabilities come from the real app's AI coach and agent features. Examples: it builds a workout from one sentence, plans your week, creates exercise databases, explains any exercise, changes app settings when you ask, and asks before it acts. The exact list must match what the app's AI can truly do today.
- **Fast next-section scrolling:** beats change quickly. Every scroll gesture brings the next beat, so the chapter feels like flicking through a feed rather than reading a page.
- **The seven-second agent creation:** the chapter ends with a simulated interaction that plays by itself for exactly seven seconds. A creation card on the page is filled in as if someone were using it:
  - Typing a unique agent username. In Tmax, bots have their own separate usernames, so this is a handle such as @talos.ironmind, with an availability check that turns green.
  - Choosing a color from the app's icon colors, with Talos's accents recoloring live.
  - Choosing a personality, such as Strict, Hype, or Calm.
  - Choosing any other small detail that makes the agent feel personal.
- **The interception (fear of missing out):** as the simulated visitor is about to confirm their character, the page interrupts. A message appears: the username is free right now, but only the app can claim it. It comes with a short countdown and the download actions. The visitor sees that the agent they were building is waiting in the app.
- **The clear-out:** after the seven seconds, the whole chapter swipes upward off the screen and reveals the impact stats.

## States

| State | Behavior |
|---|---|
| Arrival | The chapter slides in from the bottom border, then the strobe introduction runs once. |
| 3D model loading | A still render of Talos holds its place, so nothing jumps when the 3D view appears. |
| WebGL unavailable | The still render remains and moves along the same path. |
| Scrolling back | The beats reverse. Talos retraces its path. The introduction does not replay with strobes. |
| Seven-second simulation | The chapter holds still while it plays. The visitor can skip with a clear button or by scrolling. The download actions stay usable. |
| Reduced motion | No strobes, path travel, or timed playback. Talos stands still, the beats are static, and the creation card shows its final filled-in state together with the interception message. |
| Phone | Talos becomes smaller and sits above or between the panels. The creation card fills the width. |

## Dependencies

- [F30-C](../DOCKS.md): the chapter template, the switcher, and the download buttons.
- [F30-E](../../F30-E-media-production/DOCKS.md): the Talos 3D model (one generation, at most 34 credits) and the AI recordings.
- The real AI features of the app (the AI coach, tool calling, and agent settings), so the copy stays truthful.

## Reference

- The original mascot artwork: `TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png` and `genesis/REFERENCE/tmax-branding/email-welcome-mascot.png`. These are direct assets.
