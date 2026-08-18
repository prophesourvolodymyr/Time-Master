# F24 — Slot Navigation

A native SwiftUI replacement for the iOS bottom tab bar. It ports the supplied slot-machine navigation prototype's interaction model while keeping TimeMaster's real pages and data. The prototype is a visual and motion reference only; its Realistic page content, copy, colors, and assets are not imported.

## What We Build

- Replace the iOS `TabView` tab bar with a bottom slot-navigation reel for Home, Workouts, Database, Analytics, AI Coach, and Profile.
- Keep the existing macOS `NavigationSplitView` sidebar unchanged; the phone-oriented reel is an iOS navigation surface.
- Render one emoji slot per real TimeMaster destination. The selected destination is the centered, enlarged slot and exposes its text label.
- Allow direct horizontal dragging on the reel. Items track the finger continuously, resist beyond the first/last page, carry the projected release motion into a spring settle, and select the nearest projected page.
- Allow horizontal swipes across the page viewport to move one destination while preserving vertical scrolling inside each real page.
- Keep non-touch navigation available through the standard accessibility actions and visible page labels; the native bar remains touch-first.
- Use the same mathematical arc for the visible nav background and every emoji position. The background arc stays fixed in the viewport while the reel moves across it, so icons never drift away from the curve during scrolling.
- Remove the prototype's red accent, red glow, red active tint, and red navigation-only progress treatment. The slot bar uses neutral dark surfaces, white text, and neutral opacity/scale changes. Page-owned colors remain controlled by their existing views.
- Respect Dynamic Type, VoiceOver, Reduce Motion, minimum hit targets, and light/dark system contrast where applicable. The app remains dark by default through the existing app theme.
- Extend the neutral slot surface through the iOS bottom safe area so the home-indicator region matches the bar; the page viewport still reserves the bar's height.

## Architecture

```
MainTabView (iOS)
  └─ SlotNavigationContainer(selection: $selectedTab)
      ├─ Page viewport
      │   └─ Existing TimeMaster page for the selected index
      └─ SlotNavigationBar
          ├─ fixed SlotArcShape background
          ├─ shared SlotArcGeometry (path + item y positions)
          └─ draggable SlotNavigationItem reel

MainTabView (macOS)
  └─ existing NavigationSplitView sidebar + detail
```

`SlotNavigationContainer` owns page-swipe direction and page transition state. `SlotNavigationBar` owns the reel offset, drag gesture, rubber-band bounds, projected snap target, and slot appearance. `SlotArcGeometry` is the single source for both the stroked/filled arc and item anchor positions; no second parabolic approximation is allowed.

The reel uses a fixed slot width derived from available width. Its logical offset centers the selected item. During a drag, the visual offset is the logical offset plus the live translation, with a soft edge resistance. On release, `predictedEndTranslation` chooses the landing index; a spring animates from the current presentation offset to that index. A new drag cancels the previous settle without waiting for it to finish.

## Real Page Mapping

| Index | Page | Slot emoji | Label | Existing view |
|---:|---|---|---|---|
| 0 | Home | `🧠` | Home | `HomeDashboardView` |
| 1 | Workouts | `🎯` | Workouts | `WorkoutListView` |
| 2 | Database | `🗂️` | Database | `DatabaseView` |
| 3 | Analytics | `📊` | Analytics | `AnalyticsView` |
| 4 | AI Coach | `🤖` | AI Coach | `AICoachView` |
| 5 | Profile | `👤` | Profile | `ProfileView` |

No HTML page body, Realistic copy, motivational strip, demo statistics, or external assets are used.

## States

| State | Visual behavior | Interaction |
|---|---|---|
| Resting, selected | Center slot follows the shared arc, enlarged emoji, full white label, neighboring slots smaller and dimmer | Tap any visible slot to spring it to center and select its page |
| Resting, neighboring | Same arc anchor, reduced emoji scale and opacity, no red tint | Tap selects the destination |
| Dragging | Reel follows the finger one-to-one; each slot's y position is recalculated from its current x on the fixed arc; labels interpolate by distance from center; page content remains stable until release | Continue dragging, reverse direction, or release; gesture is never locked out |
| Dragging at first/last page | Translation is rubber-banded instead of hard-stopped | Releasing returns to the boundary page |
| Settling | Reel springs from the current presentation offset to the projected nearest slot; selected page transitions from the swipe direction | A new drag interrupts the spring from its visible position |
| Page swipe | Horizontal page swipe selects the adjacent page and uses the same slot spring; vertical movement remains owned by the page's scroll view | Swipe left/right beyond the threshold; edge swipes do nothing beyond the first/last page |
| Reduce Motion | No spring overshoot or page slide; selection changes with a short opacity/scale fade while the arc and slots remain spatially stable | All destinations and labels remain available |
| VoiceOver / accessibility | Each slot exposes its page label, selected state, and an adjustable action to move left/right; the emoji is decorative content, not the only label | Rotor/action changes selection without requiring a drag |
| Compact width / rotation | Slot width and arc control points recalculate from the container width; the selected slot remains centered and all hit regions remain at least 44 points | Same drag and tap behavior |

## Animation Rules

| Animation | Response / duration | Trigger |
|---|---|---|
| Slot reel snap | `interpolatingSpring(stiffness: 260, damping: 28)`; no fixed-duration dependency | Tap, page swipe, or drag release |
| Active slot emphasis | Scoped ease/spring interpolation around scale, opacity, and label reveal | Slot distance from center changes |
| Page change | `move` from the swipe direction combined with opacity; `easeOut` fallback for Reduce Motion | Selected page changes |
| Snap feedback | Small neutral scale settle on the centered emoji; no color flash | Reel reaches its target |
| Edge rubber band | Continuous nonlinear resistance, no discrete animation during finger tracking | Drag passes the first/last logical offset |

## Files

- `TimeMaster/Views/MainTabView.swift` — routes iOS destinations through the slot container while preserving the macOS split view.
- `TimeMaster/Views/Navigation/SlotNavigationContainer.swift` — page viewport, selection binding, page swipe, transition direction, and accessibility-aware page hosting.
- `TimeMaster/Views/Navigation/SlotNavigationBar.swift` — draggable slot reel, neutral arc surface, shared arc geometry, hit targets, labels, and accessibility actions.
- `features/F24-slot-navigation/DOCKS.md` — feature source of truth.
- `features/DOCKS.md` — feature index entry.
- `CYCLES.md` — implementation dashboard entry.

## Dependencies

- Existing `MainTabView` routing and all six destination views must remain available.
- Existing `Theme` surface/background tokens provide the neutral app palette; the slot bar must not introduce a red navigation accent.
- No third-party package or HTML/WebKit wrapper is required.

## Reference

- `~/GSpace/TheReal/Realistic/Realistic APP/genesis/UI-MOCKUPS/Navigation-Bar-Prototype.html` — direct visual and interaction reference supplied by the user; learn the slot-machine reel behavior and page-swipe flow, but do not import its Realistic content or red-tinted navigation treatment.
