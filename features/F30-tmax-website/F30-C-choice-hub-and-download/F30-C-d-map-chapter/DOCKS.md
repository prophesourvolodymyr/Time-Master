# F30-C-d — Map Chapter

The outdoor story: runs, walks, and rides recorded live on the map and kept on the phone. It follows the shared chapter template.

## What We Build

- **The intro moment:** a dark, label-free night map of a river city, generated with `fgen`, fills the screen. The headline "Every run, drawn live." sits on top. While the page is held, scrolling draws an orange route along the river, segment by segment. A glowing runner dot travels along the route, and the map slowly un-zooms and straightens. A glass stats panel counts distance and time in step with the route, and the pace stays consistent with them. A faint glow of the full planned route sits under the drawn line.
- **Beats:**
  1. **Hit record. Go.** Live GPS recording for runs, walks, and rides, with pauses and laps that keep every second.
  2. **Every route, yours.** Trips live on the phone first. GPX or CSV export is available anytime.
  3. **The long way home.** Plan a route, follow it, and replay it, with pace, distance, and time where they happened.

## States

| State | Behavior |
|---|---|
| Intro scrolling | The route draws forward with the scroll and erases backward. The numbers follow exactly. |
| Map image loading | The panel and headline are already readable on black. The map fades in. |
| Reduced motion | The full route is drawn, the final numbers are shown, and the map is static. |
| Phone | The map crops around the river and the stats panel keeps its three numbers in one row. |

## Dependencies

- [F30-C](../DOCKS.md): the chapter template and switcher.
- [F30-E](../../F30-E-media-production/DOCKS.md): the map recordings and the generated night map.
