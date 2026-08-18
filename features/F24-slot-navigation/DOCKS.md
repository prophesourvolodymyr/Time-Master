# F24 — Slot Navigation

A native SwiftUI replacement for the iOS bottom tab bar. It ports the supplied slot-machine navigation prototype's interaction model while keeping TimeMaster's real pages and data. The prototype is a visual and motion reference only; its Realistic page content, copy, colors, and assets are not imported.

## What We Build

- Replace the iOS `TabView` tab bar with a bottom slot-navigation reel for Home, Workouts, Database, Analytics, AI Coach, and Profile, and use the same real-page reel on macOS instead of the sidebar destination list.
- Keep the reel anchored to the bottom on both platforms. iOS keeps its compact phone-sized arc; macOS uses a taller arc surface so the slot icons have room to rise into the window while the page remains the real TimeMaster destination.
- Render one page-specific SF Symbol slot for every real TimeMaster destination. Home uses `house.fill`, Workouts `dumbbell.fill`, Database `books.vertical.fill`, Analytics `chart.bar.fill`, AI Coach `brain.head.profile`, and Profile `person.crop.circle`; the selected destination is the centered, enlarged slot and exposes its text label.
- Allow direct horizontal dragging on the reel. Items track the finger continuously, resist beyond the first/last page, carry the projected release motion into a spring settle, and select the nearest projected page.
- Allow horizontal swipes across the page viewport to move one destination while preserving vertical scrolling inside each real page.
- Start mobile and iOS on the Home page with Home centered in the page viewport and reel. Forward destinations enter from the right and move the previous page left; backward navigation enters from the left and moves the previous page right.
- Keep non-touch navigation available through the standard accessibility actions and visible page labels; the native bar remains touch-first on iOS.
- On macOS, make the navigation container keyboard-focusable. Left/right arrows move one destination with the same page transition, and number keys `1` through `6` select the matching semantic destination ID (`1` = Home through `6` = Profile) regardless of the visual reel order. Invalid number keys and boundary arrows are ignored without changing selection.
- Use the same mathematical arc for the visible nav background and every emoji position. The background arc stays fixed in the viewport while the reel moves across it, so icons never drift away from the curve during scrolling. Home is the initial centered destination, with AI Coach and Profile to its left and Workouts, Database, and Analytics to its right; forward and backward page navigation follow that visual order.
- Remove the prototype's red accent, red glow, red active tint, and red navigation-only progress treatment. The slot bar uses neutral dark surfaces, white text, and neutral opacity/scale changes. Page-owned colors remain controlled by their existing views.
- Respect Dynamic Type, VoiceOver, Reduce Motion, minimum hit targets, and light/dark system contrast where applicable. The app remains dark by default through the existing app theme.
- Let every page explicitly declare a navigation presentation through the shared `slotNavigationPresentation` modifier: `full` is the curved reel, `inline` is a compact icon rail, and `hidden` removes global navigation until the lower-corner reveal gesture. AI Coach declares `inline` on its page root so the preference survives its `NavigationStack` and the composer is never covered. Future pages with composer, player, canvas, or other bottom-owned controls choose their own declared presentation rather than relying on heuristic text-field detection. The selected navigation item carries the same presentation as a fallback, preventing a stale preference from keeping the previous rail shape during a page change. Full and inline surfaces animate as matched bottom-edge insertion/removal states, while the safe-area reservation changes with the same critically damped animation.
- On iOS, style the arc as a layered neutral material: a dark vertical base gradient, a soft white radial inner glow near the crest, and a bright-but-subtle top outline drawn from the same curve geometry as the filled surface. On iOS 26 and newer, apply the public `.glassEffect(.regular.tint(Theme.background.opacity(0.18)), in: shape)` over a `Theme.surface.opacity(0.84)` base so Liquid Glass remains restrained instead of replacing the dark palette. Earlier iOS versions keep the `.regularMaterial` fallback. The outline and glow belong to the arc surface and do not change slot z-order or page content layering. The curve crest is lowered slightly while the filled path still extends through the measured bottom safe-area inset; no fade overlay, extra padding, or separate solid safe-area rectangle is used. macOS uses the same neutral surface and exact outline/shadow curve with a taller bar frame and a lower crest; it does not adopt the iOS-only material API.

## Architecture

MainTabView
  ├─ iOS
  │   └─ SlotNavigationContainer(selection: $selectedTab, barHeight: 126)
  │       ├─ Page viewport
  │       │   └─ Existing TimeMaster page for the selected index
  │       └─ SlotNavigationBar
  │           ├─ opaque-enough glass SlotArcShape surface + soft outer depth shadow
  │           ├─ shared SlotArcGeometry (path + item y positions)
  │           └─ full curved reel / compact inline rail / transient hidden-mode rail
  └─ macOS
      └─ SlotNavigationContainer(selection: $selectedTab, barHeight: 196)
          ├─ full-width real TimeMaster page viewport
          ├─ taller bottom SlotNavigationBar using the same reel and arc
          └─ focusable arrow and `1`–`9` keyboard navigation

`SlotNavigationContainer` owns page-swipe direction, page transition state, keyboard selection on macOS, and the measured bottom safe-area inset passed to the bar. `SlotNavigationBar` owns the reel offset, drag gesture, rubber-band bounds, projected snap target, slot appearance, and platform bar height. `SlotArcGeometry` is the single source for both the stroked/filled arc and item anchor positions; the surface path alone extends below the bar frame by the measured safe-area amount so anchors do not move.

`SlotNavigationPresentation` is a view-level policy, communicated through a preference from the current destination to the container. It avoids title- or control-detection heuristics: a destination explicitly requests `.full`, `.inline`, or `.hidden`. On iOS, `.inline` reserves only the compact rail’s height below its page; the page’s own composer remains immediately above it. `.hidden` reserves no navigation space. A vertical upward swipe that begins in either lower 44-point corner reveals the compact rail; it dismisses after 2.5 seconds if unused. The reveal gesture only recognizes vertical intent and therefore cannot consume the existing horizontal page swipe. macOS retains its taller full reel regardless of an iOS page policy.

The reel uses a fixed slot width derived from available width. Its logical offset centers the selected item. During a drag, the visual offset is the logical offset plus the live translation, with a soft edge resistance. On release, `predictedEndTranslation` chooses the landing index; a spring animates from the current presentation offset to that index. A new drag cancels the previous settle without waiting for it to finish. On macOS, arrow and number selection updates the same binding and page transition state; it does not create a second navigation model.

## Real Page Mapping

| Destination ID | Visual reel position from left | Page | Slot symbol | Label | Existing view |
|---:|---:|---|---|---|---|
| 4 | 0 | AI Coach | `brain.head.profile` | AI Coach | `AICoachView` — inline rail |
| 5 | 1 | Profile | `person.crop.circle` | Profile | `ProfileView` |
| 0 | 2 | Home | `house.fill` | Home | `HomeDashboardView` |
| 1 | 3 | Workouts | `dumbbell.fill` | Workouts | `WorkoutListView` |
| 2 | 4 | Database | `books.vertical.fill` | Database | `DatabaseView` |
| 3 | 5 | Analytics | `chart.bar.fill` | Analytics | `AnalyticsView` |

No HTML page body, Realistic copy, motivational strip, demo statistics, or external assets are used.

## States

| State | Visual behavior | Interaction |
|---|---|---|
| Resting, selected | Center slot follows the shared arc, enlarged page-specific SF Symbol, full white label, neighboring slots smaller and dimmer | Tap any visible slot to spring it to center and select its page |
| Resting, neighboring | Same arc anchor, reduced SF Symbol scale and opacity, no red tint | Tap selects the destination |
| Dragging | Reel follows the finger one-to-one; each slot's y position is recalculated from its current x on the fixed arc; labels interpolate by distance from center; every slot remains above the glass arc while it expands, and the arc remains above the moving page without exposing a clipped black band | Continue dragging, reverse direction, or release; gesture is never locked out |
| Dragging at first/last page | Translation is rubber-banded instead of hard-stopped | Releasing returns to the boundary page |
| Settling | Reel springs from the current presentation offset to the projected nearest slot; selected page transitions from the swipe direction | A new drag interrupts the spring from its visible position |
| Page swipe | Home is the initial centered page. A forward swipe inserts the next page from the right and removes the current page to the left; a backward swipe inserts from the left and removes the current page to the right. Vertical movement remains owned by the page's scroll view | Swipe left/right beyond the threshold; edge swipes do nothing beyond the first/last page |
| Inline navigation | The large curved reel contracts into a 52-point dark-material icon rail below bottom-owned page controls. The selected icon has a subtle white capsule, all six icons retain their 44-point hit region, and labels are omitted to preserve composer width. | Select any destination by tapping its icon or dragging the rail horizontally; release projects the destination and settles the rail with the same slot spring. Chat input remains above the rail; no page content is obscured. |
| Inline dragging | The icon row follows horizontal finger movement one-to-one inside a soft translation limit. Projected release motion chooses the nearest destination, reversals remain interruptible, and a boundary release springs back without changing the page. | Drag across the compact rail and release; vertical page scrolling remains page-owned. |
| Full → inline transition | The full arc moves down while fading and the compact rail rises from the same lower edge. The safe-area reservation contracts with the surface, so the chat composer moves continuously with it instead of jumping or being covered. | Page selection can interrupt and retarget the transition. |
| Hidden navigation | The global surface is completely below the viewport and consumes no bottom space. No permanent handle remains. | An upward vertical drag beginning in either lower 44-point corner reveals the compact rail. It returns below the viewport after 2.5 seconds without a selection. |
| Hidden reveal gesture | The rail tracks no finger position; it is a direct, thresholded reveal. Horizontal drags remain page swipes and regular vertical scrolling remains page-owned. | Require a 42-point upward movement with stronger vertical than horizontal movement. |
| Reduce Motion | No spring overshoot, large slide, or reel motion; presentation changes use a short opacity fade while the correct safe-area reservation takes effect. | All destinations and labels remain available. |
| VoiceOver / accessibility | Each full or inline slot exposes its page label, selected state, and an adjustable action to move left/right; symbols are decorative content, not the only label. A hidden page exposes a named Show navigation accessibility action. | Rotor/action changes selection without requiring a drag. |
| Compact width / rotation | Slot width and arc control points recalculate from the container width; the selected slot remains centered and all hit regions remain at least 44 points | Same drag and tap behavior |

| Keyboard navigation on macOS | The focused navigation container keeps the current slot centered in the taller bottom arc; left/right arrows move one index and `1`–`9` select an existing index. | Focus the navigation surface and press a valid arrow or number key; keys outside the available destinations do nothing. |

## Animation Rules

| Animation | Response / duration | Trigger |
|---|---|---|
| Slot reel snap | `interpolatingSpring(stiffness: 260, damping: 28)`; no fixed-duration dependency | Tap, page swipe, or drag release |
| Active slot emphasis | Scoped ease/spring interpolation around scale, opacity, and label reveal | Slot distance from center changes |
| Page change | `move` from the swipe direction combined with opacity; `easeOut` fallback for Reduce Motion | Selected page changes |
| Navigation presentation | Critically damped `response: 0.42`, `dampingFraction: 0.9`; short opacity fade when Reduce Motion is on | A destination changes from full to inline, or a hidden rail reveals/dismisses |
| Inline rail snap | The compact rail returns from its live translation with the slot reel interpolating spring (`stiffness: 260`, `damping: 28`); Reduce Motion uses the short ease-out fallback | Inline drag release |
| Snap feedback | Small neutral scale settle on the centered SF Symbol; no color flash | Reel reaches its target |
| Edge rubber band | Continuous nonlinear resistance, no discrete animation during finger tracking | Drag passes the first/last logical offset |
| iOS arc material | The arc keeps its lowered crest, neutral vertical depth gradient, soft inner white glow, and top outline while slots remain in front | Resting, dragging, and settling; drag scale affects the complete arc layer |

## Files

- `TimeMaster/Views/MainTabView.swift` — routes both iOS and macOS destinations through the slot container while preserving the real page views.
- `TimeMaster/Views/Navigation/SlotNavigationContainer.swift` — page viewport, selection, page swipe, transition direction, macOS focus and keyboard handling, and accessibility-aware page hosting.
- `TimeMaster/Views/Navigation/SlotNavigationBar.swift` — draggable slot reel, neutral arc surface, shared arc geometry, platform bar height, hit targets, labels, and accessibility actions.
- `TimeMaster/Views/Navigation/SlotNavigationItem.swift` — page-specific SF Symbols, labels, accessibility hints, and explicit navigation presentation types/modifier.
- `TimeMaster/Views/Navigation/SlotNavigationArc.swift` — shared arc path, lowered iOS crest offset, top outline path, and inset contour path.
- `features/F24-slot-navigation/DOCKS.md` — feature source of truth.
- `features/DOCKS.md` — feature index entry.
- `CYCLES.md` — implementation dashboard entry.

## Dependencies

- Existing `MainTabView` routing and all six destination views must remain available.
- Existing `Theme` surface/background tokens provide the neutral app palette; the slot bar must not introduce a red navigation accent.
- No third-party package or HTML/WebKit wrapper is required.

## Reference

- `~/GSpace/TheReal/Realistic/Realistic APP/genesis/UI-MOCKUPS/Navigation-Bar-Prototype.html` — direct visual and interaction reference supplied by the user; learn the slot-machine reel behavior and page-swipe flow, but do not import its Realistic content or red-tinted navigation treatment.
