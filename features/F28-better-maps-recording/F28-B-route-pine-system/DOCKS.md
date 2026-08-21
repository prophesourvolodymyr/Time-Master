# F28-B — Route Pine System

F28-B defines the iPhone route feature’s permanent-map composition and every morphing pine that presents it. A pine is a persistent Liquid Glass surface whose frame, mask, and content change over the same map. It is not a sheet, page, navigation destination, or replacement for the map. F28-B owns pine geometry, detents, transitions, direct manipulation, accessibility, and the Start/type/empty-feature shells. Recording telemetry and workout lifecycle belong to F28-C; map data and camera services belong to F28-D; Music content and playback belong to F28-E; finished-workout content and Library persistence belong to F28-F; persisted quick-setting ownership and recovery entry belong to F28-G.

## What We Build

- One iPhone-only, full-screen route destination over a single long-lived interactive map.
- A main route pine that presents Start, live-workout content, Finish content, Library, and Library detail in place.
- Bottom-anchored sibling feature pines for Type, Music, Rate, and Route.
- One upper quick-option pine, opened from the exposed-map Map, Trophy, or Settings controls.
- A fixed compact player pine that is present only while local playback exists.
- Native Apple Liquid Glass on iOS 26 and later, with the existing private LiquidGlassKit treatment on iOS 16 through iOS 25. The older renderer follows the same frames, clipping, timing, identity, and interaction rules; only the material implementation differs.
- Direct, interruptible resizing in which the moving glass edge follows the finger and content remains a stateful part of the same pine.
- System-symbol iconography, native hit targets, Dynamic Type, VoiceOver state, Reduce Motion, and Reduce Transparency behavior for every pine.

The reference canvas is an iPhone-shaped 390 by 844 composition only. Native layout uses the actual device bounds, safe-area insets, Dynamic Type metrics, and available height. The dark area outside the phone-shaped reference is not app UI. macOS receives no F28-B route interface.

## Architecture and Layer Ownership

The visible stack, from back to front, is:

1. **Permanent map layer.** One map instance remains alive for the entire route session. It owns map gestures wherever the map is exposed, camera state, user location, route overlays, mode state, and weather placement through F28-D. Opening or resizing any pine never replaces it with a blank or newly created map.
2. **Map controls.** The right-side download and location controls and display-only WeatherKit information belong to the map layer. They remain spatially constrained by the exposed map and never become part of a pine’s content. Download’s final area-selection surface is intentionally outside this document’s visual design.
3. **Exposed-map quick stack.** Map, Trophy, and Settings are compact icon-only controls in exposed map space. The stack is not painted through a pine and disappears where no usable map region remains.
4. **Main route pine.** The bottom surface owns the Start composition and receives live-workout, Finish, Library, and Library-detail content without changing its identity or becoming navigation.
5. **Closable lower feature pine.** Type, Music, Rate, or Route is a second bottom-anchored surface. The main pine remains its immediate sibling above the feature’s moving top edge.
6. **Compact player pine.** A fixed-height playback surface is independent of the workout and feature pines. It reserves bottom space while playback exists and cannot be dismissed by dragging.
7. **MAX drawer.** When a main pine is in true MAX, a feature opens as a bottom drawer over that flat pine. The MAX surface underneath does not resize or reflow.

The route session, map, camera, active workout, local Music queue, player state, unfinished result, selected feature, and each pine’s remembered geometry are long-lived state. Changing focus, map mode, feature, or detent does not recreate any of them.

## Continuous Geometry and Detents

All dimensions below describe product proportions and relationships, not fixed pixel coordinates. Safe areas and content measurement adjust them for every supported iPhone.

| Pine | Resting presentations | Geometry and ownership |
|---|---|---|
| Main route/workout | Compact about the lower 30%; medium about the lower 60%; normal full/minimal-100%; true MAX | Bottom-anchored with safe-area breathing room. Compact and medium are floating rounded glass. Normal full is still a floating rounded pine. True MAX is a second explicit state: flat, edge-to-edge, and full height. |
| Type, Rate, Route | Expanded/near-full, medium, compact about 30% visible height | Bottom edge stays anchored. These pines open at compact by default, remain usable there, and can be resized through the normal detents. |
| Music Editor | Content-fit default around 70%; larger/full content-fit state; compact around 30%; normal detents after manual resize | Intrinsic Music content chooses an initial height within sensible bounds. Search tray and expanded content add only measured space. Once the user drags manually, that height takes priority until the editor is reopened. Internal content scrolls after the height cap. |
| Upper quick-option | Approximately a compact upper 30% pine | Grows from the quick control that opened it, remembers that origin, and closes back toward that control. It is structurally one pine even when its inner content changes between Map, Settings, and empty Trophy. |
| Compact player | Fixed height while playback exists | Bottom-anchored, non-resizable, non-dismissible. Pausing playback keeps it visible. Only explicit Stop Playback in Music Editor removes it. |
| MAX feature drawer | Bottom drawer above flat MAX | A feature opened from MAX overlays a short bottom drawer. It never shrinks the MAX pine or turns it into a sibling stack. |

The lower feature pine’s normal visibility is intentionally separate from its content’s coordinate space. The pane mask can reveal more or less of stationary content; the content does not slide with the moving top glass edge.

## Permanent-Map Stacking

The map remains visible in every exposed region, including the space between sibling pines. Panning the exposed map is still map interaction and never starts a pine resize. Covered regions belong to the surface above them. There is no map search bar in this feature.

The main pine and a closable feature pine dynamically share the lower portion of the phone:

- The feature pine is bottom-anchored.
- The main pine sits directly above the feature’s current top edge with a small breathing gap.
- When the feature grows, the main pine compresses only as needed to remain visible and usable.
- When the feature shrinks, the main pine reclaims the released space without jumping to a fixed top-of-screen frame.
- The main pine’s current content and state remain in place while its frame changes.
- The exposed-map quick stack is continuously repositioned above the highest lower pine edge. It keeps its preferred map position while space allows, moves upward as the pine approaches, fades when the complete stack cannot fit, and is absent at normal 100%, detail-full, and MAX states.
- A compact player reserves its own bottom region. In an ordinary route or workout state, the main pine and map controls sit above that reserve. MAX remains flat and edge-to-edge; a MAX drawer uses the player reserve when playback is present.

No transition in this stack creates a second map, a modal result sheet, or a navigation page.

## Start Composition

The initial route pine is the Start composition over the live map:

- A small square Library control sits to the left of the central orange Start control.
- Start is centered and orange, with balanced space on the right.
- The mode bar below contains exactly Type, Music, Rate, and Route.
- At compact height, the mode bar is icon-only. As the main pine grows, icons enlarge continuously and their labels fade in below the icons. There is no selected underline.
- The Start control, Library control, mode bar, icon sizes, label space, and internal spacing all interpolate continuously with the pine height rather than changing only after a detent snap.
- The Type slot shows the committed activity icon. Before an explicit Type commit, the neutral Start state uses the visible Run default. Scrolling a Type chooser never changes this slot.
- Tapping Library replaces Start and the mode bar with Starred and Library content inside the same main pine. It does not open a map control, sheet, or page. Library card/detail behavior and persistence are F28-F.

Starting a workout morphs this same route pine into live-workout content at compact height. It does not move the pine to a new screen position. Finishing later morphs the same pine again; its current height and map camera are retained while F28-C and F28-F provide the real workout state and finalized content.

## Main Pine Interaction

### Direct resizing

The main drag handle is a generous native hit target centered along the top edge. A vertical drag changes the pine height one-to-one with the finger. During direct manipulation, the surface and every internal control have no animation lag: Start, the Library control, mode bar, metric layout, and exposed-map geometry track the live fraction immediately.

On release, the pine settles to the nearest valid compact, medium, or normal-full detent using a restrained velocity-aware spring. Grabbing during that settling motion interrupts it immediately and transfers control to the new finger position. A canceled gesture follows the same safe nearest-detent settling rule.

The diagonal resize symbol is hidden at compact and medium. It appears only after the user has physically reached the normal full/minimal-100% resting state. Its appearance is not a shortcut to MAX. Pressing it enters true MAX. Pressing the same control in MAX exits to normal full, preserving the pine’s content and state.

### Content reflow

Main content reflows inside its existing glass base. Live workout metrics move continuously from the compact composition of Total on the left, speed in the center, and Time on the right toward an expanded composition with Time above the centered speed and Total below. Metric values are real F28-C state; only changed digits use a restrained vertical roll. Finish information similarly appears progressively as the same pine grows. A Finish “More Info” cue is a compact pill, not a second drag surface.

A content change inside the main pine uses morphing and reflow rather than a page transition. Focus, scroll state, drafts, and the map remain continuous through the change.

## Lower Feature Pine

Type, Music, Rate, and Route share one lower feature surface. Selecting a different mode replaces content inside that surface while preserving its open geometry and each feature’s state. Selecting the already-open mode closes that feature pine. A handle tap alone never closes a feature.

The normal Type, Rate, and Route pine opens at the compact roughly 30% visible detent. Music initially sizes from the amount of real Music content and generally opens around 70%; a smaller library produces a shorter opening surface, while more rows grow it only until the content cap. Reopening Music measures its current content again. Manual dragging takes precedence over automatic sizing until the editor is reopened.

While any lower feature is open:

- The main Start or live-workout pine remains immediately above it and remains independently usable.
- The main mode bar returns to compact icon-only treatment.
- The map remains behind both pines and remains interactive in every uncovered region.
- Selected feature, scroll position, inline expansion, Type preview, Music section, and remembered real detent survive temporary focus changes and resizing. Closing Music clears the tray-open state so it cannot reappear unexpectedly; the rest of the editor state remains available when the same editor is reopened.
- Switching to another lower feature does not reset the first feature’s state. Closing and reopening returns to its last real detent rather than to a nearly dismissed height.

### Bidirectional coupled resizing

Both siblings remain live while Music is open. Dragging the Music top edge upward makes Music larger and pushes its top edge downward, compressing the main workout pine only when necessary. The workout sibling never disappears or becomes an unusable sliver. Dragging the main workout handle upward grows the workout pine and, when space is needed, pushes Music downward so Music shrinks rather than becoming disabled. The map remains visible wherever the coupled stack leaves space.

The same constraint applies during a live workout. Opening Music is not a workout-specific screen and does not stop or reset recording. Closing Music restores the pre-feature main height when no coupled resize was required; when the workout was intentionally compressed by Music, the retained coupled height is restored consistently with the user’s last direct layout.

### Compact-to-zero dismissal

Every closable lower feature pine uses one continuous dismissal gesture:

1. From any real detent, the user drags the top handle downward.
2. At compact, dragging can continue past the approximately 30% visible height toward zero.
3. The bottom edge remains anchored while the top glass edge follows the finger. The feature surface fades only as it approaches the close zone; it never translates as a modal sheet.
4. Releasing near zero closes only that feature pine and exposes the map. The main sibling remains the route/workout pine.
5. Releasing above the close zone settles to the nearest expanded, medium, or compact detent.
6. A handle tap without meaningful movement does not close the feature.

The close zone is deliberately below the ordinary compact detent, leaving roughly no more than a small fraction of the pine visible so an ordinary compact resize does not accidentally dismiss it. A closing gesture never persists the temporary near-zero height; reopening uses the last real detent or content-fit height.

The compact player is the explicit exception: it has no 30%-to-zero gesture and remains present until playback is explicitly stopped from Music Editor.

## MAX and MAX Drawers

Normal full is still a floating rounded pine with safe-area geometry and the same map-backed identity. True MAX is entered only through the diagonal control after normal full is reached. In MAX:

- The same Liquid Glass surface becomes flat and edge-to-edge with no floating rounded-card silhouette.
- The surface covers the phone to the safe-area policy selected by the native composition; its base is visually flat and its lower controls become part of the flat composition rather than another capsule.
- Map controls and the exposed-map quick stack are absent because no usable map region remains.
- Live content, workout state, route state, drafts, scroll position, and playback continue unchanged.
- The diagonal control remains available as the explicit exit back to normal full.

Opening Type, Music, Rate, or Route from MAX presents a bottom slide-over drawer above the flat MAX pine. The drawer owns its own glass identity and is allowed to be dismissed by a deliberate downward drag. The underlying MAX pine does not shrink, reflow, or change height. A handle tap without a downward drag leaves the drawer open. Dismissing it reveals the exact prior MAX presentation, including content and state.

## Upper Quick-Option Pine

The left-side vertical quick stack contains Map, Trophy, and Settings icon-only controls. They belong to the exposed map, not to the main route pine. The upper quick pine hides its trigger stack; in a lower feature or Library/detail state the stack is governed by the remaining exposed-map geometry: it stays compact and above the moving lower edge while the full stack fits, then moves upward, fades, or disappears as space runs out. The main pine naturally covers it as it grows, and normal full/MAX states have no usable stack.

Tapping any quick control uses the same upper pine structure:

- The glass surface grows from the tapped control’s actual screen-space origin, with a restrained scale/opacity morph.
- The selected origin is remembered while the pine is open.
- Map presents the map-mode selector shell; actual map mode behavior is F28-D.
- Settings presents the compact scrollable route quick-settings surface; durable preference behavior is F28-G.
- Trophy/Competition remains intentionally empty inside its correctly sized, focused pine. Empty means no invented copy, cards, metrics, backend, or disabled trigger.
- Switching the selected quick content preserves the upper pine and its origin rather than creating duplicate panes.
- Closing morphs back toward the originating left-side control, not toward the Library control, then restores the main pine’s saved height.

The small Library control beside Start is never an upper quick opener. It always owns the in-place Library state.

## Type Chooser

Type is the one fully defined lower feature besides Music. It opens at the compact feature height so it is usable without first expanding the pane. The chooser uses Apple’s official native wheel-style control: SwiftUI’s native wheel Picker where the host is SwiftUI or UIKit’s native picker equivalent where the host is UIKit. A custom scroll view that imitates wheel physics is not used.

- The available new choices are exactly Run, Bike, and Walk, each with its distinct native/system workout symbol beside its name.
- The centered wheel value is a preview only. Preview state is separate from the committed Start activity type.
- Wheel movement snaps one item at a time and exposes the centered value as selected/previewed to accessibility.
- The orange circular check control is the only commit boundary. It accepts the centered value and gives a restrained confirmation pulse.
- Only after the check is committed does the Start Type slot morph from its generic/default presentation to the exact accepted Run, Bike, or Walk icon.
- Dragging the Type wheel scrolls the chooser. Dragging the feature handle resizes the pine. The two gestures do not compete.
- Resizing, temporarily focusing another pine, or dismissing and reopening the chooser preserves the committed type and the selected preview according to the route-session state.

The legacy combined Run & Walk type is a durable historical type owned by F28-C and migration. It is not added to this new Type chooser.

## Intentionally Empty Feature Interiors

Rate and Route retain their mode buttons, glass pine, focus state, compact/medium/expanded detents, coupled stacking, dismissal, MAX drawer behavior, accessibility labels, and state preservation. Their interior remains empty until an approved product surface exists. No dashboard, cards, metrics, route planner, rating controls, placeholder explanation, speculative API, or fake data is added.

Trophy/Competition follows the same empty-content rule inside the upper quick pine. Other future placeholder features remain structurally empty when named without an approved interior. Empty does not mean disabled when the structural opening and dismissal behavior has already been designed.

## Music and Player Geometry Boundaries

F28-E owns the real Music Editor content, playback, search, drag intent, and track history. F28-B owns the surfaces that contain it:

- Music Editor is the same lower feature pine before and during a workout. The workout Music action opens or focuses it; it never creates a workout-only editor.
- Search is inline content within Music’s existing pine and may grow that pine only by the measured tray content. It is not a popup, second pine, or unrelated overlay.
- The current Music pine’s section, scroll position, expanded collection, search state, and manually selected height survive focus changes. Closing the editor clears its tray-open state; the player pen opens/focuses that same editor without resetting its retained section, scroll position, collection expansion, or pane height.
- Starting playback slides a fixed-height compact player up from the bottom with a restrained spring. Its artwork, title, progress, and bare transport icons are F28-E data. Previous, play/pause, and next controls have no individual bases or enclosing transport capsule.
- The player’s grab line is visual only. No drag or swipe dismisses it. Workout Stop/Resume affects the workout, never playback. Stop Playback inside Music Editor is the only removal action.
- When the player is visible, lower ordinary pines and map controls respect its reserved height. Player visibility does not alter the workout identity or route data.

## Animation and Interruption Rules

- Direct pine resizing is one-to-one, with no transition lag on the active surface or its dependent geometry.
- Release settles to the nearest valid detent with a restrained spring. A new drag interrupts a running spring at its current visual position rather than waiting for the animation to end.
- Opening a lower feature morphs the existing surface from its selected mode and keeps the map visible; it never performs a navigation push or sheet translation.
- The feature top edge moves while the feature content stays in its stable screen-space coordinate system. The changing glass mask clips and reveals content instead of dragging content with the edge.
- Main/feature coupled reflow is continuous in both directions. Whichever sibling is being grown retains gesture priority; the other compresses only enough to remain visible and usable.
- Compact-to-zero dismissal is the same edge motion as resizing, with no separate modal-dismiss animation.
- The upper quick pine scales from the tapped quick control’s origin and closes toward that same origin.
- In-pine state replacement uses restrained opacity and reflow transitions. It does not announce or visually behave as a new page.
- Native iOS 26 glass identities remain stable across related morphs so material response participates in the transition. The iOS 16–25 private fallback preserves the same identity relationships, frames, clipping, timing, and interruption behavior.
- Touch-down feedback is subtle scale, opacity, tint, or haptic feedback where enabled. Animated system symbols may replace, pulse, rotate, or change state only when a real action occurs.
- The Type confirmation gives a short pulse. Changed metric digits roll vertically only when the value changes; unchanged values remain visually stable.
- Long-title marquee motion and decorative symbol effects stop under Reduce Motion. Reduce Motion also replaces large spring travel with restrained reflow/crossfade while retaining direct one-to-one drag and unmistakable state changes.
- Reduce Transparency removes backdrop capture and uses readable opaque surfaces without changing geometry, z-order, or interaction.

## Accessibility and Responsive Behavior

- Every icon-only control exposes a meaningful VoiceOver label and current state, including whether a quick pane is open, a Type value is previewed or committed, a MAX control will enter or exit MAX, and whether playback is active.
- Pine handles expose adjustable accessibility actions for moving through compact, medium, and expanded detents. Closable feature handles expose an explicit dismiss action as well as the direct compact-to-zero gesture. MAX drawers expose a dismiss action without resizing the MAX surface.
- Type and Music wheels expose their selected/centered values, use native picker accessibility, and keep preview separate from commitment.
- VoiceOver focus follows content replacement inside the same pine. It does not announce Start-to-live, live-to-Finish, Library, or feature replacement as a newly pushed page.
- Color is never the only indication of selection, pressed state, paused state, or MAX. Text, system-symbol state, labels, and accessibility values accompany color.
- Dynamic Type keeps essential actions available at every detent. Content that cannot fit scrolls inside its pine; controls do not become inaccessible solely because labels grow.
- Native hit targets remain at least Apple’s recommended size even when the visible compact control is icon-only.
- Safe-area insets, home-indicator clearance, orientation policy, device height, and Dynamic Type determine final geometry. The reference percentages remain the spatial relationship, not a hard-coded canvas.

## Dependencies and Conceptual Sibling Links

- F28-C — accepted movement, workout state, Run/Walk/Bike types, legacy type, real metrics, pause/resume, elevation, recovery, and three-metre boundary.
- F28-D — permanent map host, map modes, camera/follow state, route overlays, WeatherKit placement, and offline-map contract.
- F28-E — shared Music Settings presentation, real playback, inline search, drag/drop intent, player data, and played-track history.
- F28-F — Finish fields, Establish, local Public Profile publication, Library cards/detail, export, and deletion safety.
- F28-G — persisted quick settings, privacy defaults, endpoint distance, recovery entry, migration, and unusual-state messaging.
- F09, F24, F25, F26, and F27 — persistence, full-screen destination behavior, shared Music, cross-version glass policy, and route entry points.
- Apple Liquid Glass on iOS 26+, the existing private older-system renderer on iOS 16–25, native wheel picker controls, VoiceOver, Dynamic Type, and accessibility motion/transparency settings.

## Files and Reference

- `TimeMaster/Views/Outdoor/` — permanent map host, route pine composition, sibling surfaces, and accessibility presentation.
- `TimeMaster/Views/MainTabView.swift` — full-screen route destination and shared dependency presentation.
- `TimeMaster/Models/OutdoorActivity.swift` and `TimeMaster/ViewModels/OutdoorActivityStore.swift` — activity state consumed by main/Library content.
- `TimeMaster/Utilities/MusicManager.swift` and `TimeMaster/ViewModels/MusicLibraryStore.swift` — shared playback and Music state consumed by F28-E.
- `features/F28-better-maps-recording/tmux_route_recording_prototype (1).html` — authoritative permanent-map, pine geometry, detent, transition, Type, empty-feature, MAX, and accessibility interaction reference. Its simulated map, telemetry, music rows, and Library records are visual scaffolding only.
- `features/F28-better-maps-recording/DOCKS.md` — parent product decisions.
- `features/F28-better-maps-recording/RF28-A-outdoor-remake-migration/DOCKS.md` — migration ownership and child boundaries.
