# F28 — Better Maps and Route Recording

F28 is the complete iPhone remake of outdoor Run, Walk, and Bike recording. It replaces the old recorder, route picker, result sheet, and activity-detail interfaces with one full-screen route feature whose interactive map remains present while Liquid Glass pines continuously resize, exchange content, and preserve the active workout.

The monolithic HTML file in this folder is the authoritative high-fidelity interaction specification. Its visible structure, comments, motion rules, state relationships, and deliberately empty feature interiors define the expected product behavior. Placeholder telemetry, routes, music, weather, and Library records in the HTML are not product data and must be replaced by real app state.

## What We Build

- One iPhone-only full-screen route feature launched from existing Home and Workout entry points.
- A permanent interactive map background that is never recreated when the route feature changes state.
- A main route pine with compact, medium, full, and true MAX presentations.
- Closable sibling feature pines whose bottom edge remains anchored and whose top glass edge continuously follows the finger from full height through the compact detent toward zero.
- Start, live workout, Finish, Establish, Library, and Library detail as content states of the same main route pine rather than pushed pages or modal result sheets.
- Native Apple Liquid Glass for all morphing pines and floating glass controls on iOS 26 and later.
- The project’s existing private LiquidGlassKit treatment on iOS 16 through iOS 25, with the same geometry, state, timing, and accessibility fallbacks. These older builds remain unsuitable for App Store distribution.
- New Run, Walk, and Bike activity types. Existing combined Run & Walk activities remain a distinct legacy type and are never silently reclassified.
- Real offline-capable distance, speed, elapsed time, moving time, route, pace, elevation, pause, and recovery behavior.
- Real Apple WeatherKit temperature and condition presentation as display-only map information.
- A provider-owned map data layer supporting Explore, Terrain, Satellite, 3D, Transit, Traffic, Cycling, Dark, and Direction while preserving the same camera, route, workout, and pine geometry.
- A Music Editor connected to the existing persisted Music Settings library and real local playback system.
- A fixed compact player pine that survives Music Editor dismissal and remains independent of the live workout pine.
- A post-workout result bound to the finalized activity, including played-track history and real route geometry.
- A local established-workout Library with Starred, filtering, sorting, editable details, privacy, share/export, and deletion safety.
- Public activities posted to the user’s local Profile. Social accounts, remote feeds, comments delivery, and server publication are outside this feature and will connect through a future publication boundary.
- Every quick setting in the HTML backed by a persisted preference and a real service boundary.
- Rate, Route, Trophy/Competition, Trips, and every other explicitly unfinished interior remain intentionally empty. Their pines, focus behavior, dismissal, and state preservation still work.

## Product Decisions

- Supported iPhone deployment remains iOS 16 and later.
- Native Liquid Glass is used only where the public Apple APIs exist, on iOS 26 and later.
- The existing private glass renderer remains the selected older-system policy.
- Existing finished outdoor activities migrate into the F28 Library as Private entries while retaining raw route data and summary values.
- Existing Run & Walk records retain their legacy type label and badge.
- Public is a local Profile publication state in this version. Private activities remain visible in the route Library but do not appear as Profile posts.
- Changing a Public activity to Private never destroys its public description, tags, comments preference, hidden-endpoint preference, or played-track visibility preference.
- Workout tags are reusable user-created tags. Recent tags are offered during Establish and new tags can be created there.
- Hide Start & Finish offers 100-metre, 200-metre, and 500-metre distances, with 200 metres selected by default. The complete private route remains stored locally.
- Every delete requires confirmation. Activities lasting at least 60 minutes or covering at least 20 kilometres require a continuous 1.2-second destructive hold after the confirmation appears.
- The route feature is a full-screen destination. Exiting returns to the app surface that launched it.
- macOS receives no new F28 interface in this feature. Shared data remains compatible so a macOS interface can be built later.

## Product Architecture

The feature has five persistent product layers.

1. **Map layer.** Owns the map instance, camera, user location, route overlays, map mode, offline availability, direction, and weather placement.
2. **Main route pine.** Owns Start, live workout, Finish, Establish, Library, and Library detail content.
3. **Sibling feature pine.** Owns Type, Music, Rate, or Route content and can coexist with the compact main route pine.
4. **Upper quick pine.** Reuses one structural surface for Map, Trophy, or Settings content and grows from the quick control that opened it.
5. **Compact player pine.** Appears only while playback exists, remains fixed-height, and cannot be dragged away.

The main route pine and sibling feature pine share available vertical space. Neither is a system sheet. A direct drag changes live layout geometry and visible content continuously. A resting detent is chosen only after release. True MAX is a second explicit state available only after reaching the normal full-height detent.

The feature state belongs to one long-lived route session. Changing pine focus, map mode, feature selection, or detent never recreates the map, recorder, active music queue, workout, or unfinished result.

## Entry and Exit

Home Run, Walk, and Bike shortcuts open the same full-screen feature and preselect the corresponding activity type. The Workout area uses the same entry contract. A neutral entry begins with Run as the visible default.

The route feature initially shows the Start composition over the live map. The application’s slot navigation is not duplicated inside this full-screen destination.

The Library header exit arrow leaves the route feature and returns to the launching app surface. Internal Library back controls return only to the prior content in the same route pine.

If an activity is recording, paused, finished but not established, or recoverable, an exit cannot silently discard it. The app preserves the session and offers recovery when the route feature is opened again.

## Pine Presentation States

| Presentation | Main behavior | Map exposure | Controls |
|---|---|---|---|
| Compact | Approximately the lower thirty percent; primary content and essential actions remain usable | Large exposed map region | Labels may collapse where the HTML specifies icon-only controls |
| Medium | Approximately the lower sixty percent; content reflows rather than swapping screens | Map remains visible | Secondary information and labels become available |
| Full | Normal near-full-height resting state with safe-area insets | Small exposed map region | The diagonal MAX control becomes available |
| MAX | The same pine becomes a flat focused surface | Map quick controls are absent | A second diagonal action exits MAX back to Full |
| Sibling stack | Main pine compacts above Type, Music, Rate, or Route | Exposed map remains between persistent surfaces where space allows | Each pine keeps its own live drag behavior |
| Dismissal stretch | A closable feature pine continues below Compact toward zero visible height | Map exposure increases continuously | Release near zero closes that feature only |

The compact player pine is the only lower pine that does not support dismissal by dragging. Playback is removed only by Stop Playback inside the Music Editor.

## Start State

The Start state reproduces the HTML composition: Library control on the left, central orange Start control, balanced spacing on the right, and the Type, Music, Rate, and Route mode bar below.

Type opens the native wheel-style chooser for Run, Bike, and Walk. Wheel movement previews a type. Preview does not alter the committed Start icon or activity type. The orange check control commits the centred selection and animates confirmation. Start uses the committed type, or the visible Run default if no explicit change was committed.

Music opens the shared Music Editor. Rate and Route open empty feature pines with correct sizing, focus, motion, and dismissal but no invented content.

The Library control replaces Start content with the route Library inside the same pine. It is not a map control.

## Live Recording

Start requests location permission at the moment recording begins. Permission denial, restricted permission, unavailable location, and recovered authorization states remain inside the feature and never produce fake movement.

Accepted Core Location samples determine the route and distance. Invalid coordinates, inaccurate samples, implausible speeds, duplicate or reversed timestamps, and movement below the selected quality threshold do not contribute to accepted distance.

The live pine shows elapsed time, current speed, total distance, units, state, Music, Finish, Stop/Resume, and the intentionally unfinished heart control. Metric changes use short rolling transitions rather than replacing the entire view.

Stop pauses the same workout. Resume continues the same elapsed, distance, route, elevation, music history, and pane state. Auto Pause remains configurable and uses the existing twenty-second stationary rule with movement confirmation before automatic resume. Manual pause always overrides automatic resume until the user explicitly resumes.

Distance and speed remain available without a network connection. The active route is appended durably so a process interruption does not erase accepted samples.

A recording survives backgrounding and screen locking under the platform’s active location-session rules. Keep Screen Awake affects only display idling and does not change recording ownership.

## Elevation

The Hybrid elevation source is the default. It combines quality-filtered absolute altitude with barometric relative changes when the device supports them. GPS-only and Barometer modes remain selectable.

Elevation gain ignores noisy reversals below the quality threshold. Highest elevation comes from accepted absolute altitude. Barometer-only relative movement is anchored to the latest accepted absolute altitude when one exists. Loss of barometer data degrades to accepted GPS elevation without losing the activity.

Elevation processing is offline-capable. Downloaded terrain data may enrich map presentation and route context but is not required for the live workout’s own elevation totals.

## Finish, Resume, and Establish

Finish stops live collection and morphs the current main route pine in place. The current pine size and map camera are preserved. No result sheet or navigation transition appears.

If accepted movement is below three metres, the activity is discarded immediately, the route pine returns to Start, and a concise explanation appears. The user never sees Finish details or Establish for that activity.

A valid Finish shows editable title, distance, elapsed time, elevation gain, highest elevation, highest speed, average pace, and played-track count. Expanding the same pine reveals progressively more information.

Resume returns to the same live workout with all samples, time, music history, title draft, and route state intact.

Establish opens an in-place Public/Private chooser owned by the Finish pine. Private can commit directly. Public exposes description, reusable tags, endpoint privacy, comments preference, and player-track visibility. Establish persists the finalized Library activity before returning the route feature to Start.

## Local Publication and Profile

The Library contains both Private and Public established activities. The user’s Profile route feed contains Public activities only. Profile aggregates may continue to include the user’s complete private activity history.

Public activity metadata is local in this version. Allow Comments records the publication preference for a future social system but does not fabricate comments or remote delivery. A future publication service can read the same metadata without changing the route UI or activity identity.

Changing visibility is immediate and durable. Public to Private removes the activity from the Profile feed while retaining every public field. Private to Public restores the prior fields.

## Library

The Library replaces the Start composition in the main route pine. Starred is a horizontal carousel sourced from every starred activity and is never affected by Library filters.

The Library grid supports All Types, Run, Bike, Walk, and the preserved legacy Run & Walk type where relevant. It sorts by Recent, Oldest, Distance, or Name. Empty results show a compact filter-specific state.

Every card renders the real recorded route geometry or a cached route snapshot. It shows persisted distance, name, and an activity-type badge derived from stored type metadata.

Opening a card replaces the grid with detail content inside the same route pine. Detail supports title, star, visibility, statistics, description, tags and public preferences, played-track artwork/history, Share/Export, and Delete.

Normal deletion uses a confirmation. Significant deletion shows progress while the destructive action is held and cancels immediately if the finger leaves or lifts before 1.2 seconds.

## Music

The route Music Editor is another presentation of the same Music Settings library, membership ordering, artwork, collection, and local playback data. It does not create a second music database.

The main editor section and inline search-tray source section are independent. Run, Bike, Walk, and More are selectable with native wheel behavior. A source-section choice does not silently change the destination being edited.

Rows play real local tracks and expand real collections inline. Search remains inside the Music pine rather than becoming a popup or page. Provider entries without configured official integration remain honest unavailable states.

Direct row dragging gives predictable insertion-before and insertion-after feedback. Dwelling over the centre of a compatible sibling row creates folder intent. Crossing a row without the dwell does not create a folder.

Dragging from another section’s search tray creates a temporary playable reference for the current route session only. It does not change the source section or permanently copy that membership. Temporary imports are removed when the route session resets.

The compact player records a track already playing when the workout begins and every later track change. The finalized activity retains stable track references, display metadata, and artwork references needed for historical rendering.

## Map Modes

All modes reuse one renderer, camera, user-location state, recorded route, and pine layout.

| Mode | Product behavior |
|---|---|
| Explore | General-purpose vector streets, paths, buildings, places, and route context |
| Terrain | Real terrain elevation, hillshade, and contour context from licensed elevation data |
| Satellite | Licensed aerial or satellite imagery with required attribution and availability behavior |
| 3D | Real building heights and terrain presentation on the same map |
| Transit | Nearby routes, stops, and live vehicles where normalized schedule and realtime data are available |
| Traffic | Current traffic flow and incidents with provider freshness and attribution |
| Cycling | Cycleways, access, path classification, surface, and relevant bicycle attributes from shared vector data |
| Dark | A dark style applied to the existing vector map rather than a separate product |
| Direction | Device heading and camera orientation applied to the existing map |

A provider-owned data boundary normalizes vector, raster, elevation, transit, traffic, and attribution information. Provider failures degrade the affected mode without interrupting route recording. Offline behavior follows each provider’s legal caching rights.

## Map Controls

The right download action represents the future same-map offline-area selection contract. The HTML intentionally does not define the visible selection rectangle, confirm controls, or progress UI. F28 preserves the request, geographic-bounds, provider-capability, progress, cancellation, failure, and installed-state service boundaries without inventing an unapproved selection interface.

Location focuses the current position and enters follow mode through the real location and camera services. A user pan exits follow mode without stopping recording.

Weather is display-only. It updates from Apple WeatherKit, shows temperature plus current condition, uses only a temporary response-expiration-bounded cache permitted for WeatherKit performance, and disappears or shows unavailable without becoming tappable. WeatherKit values are never stored in the durable activity manifest or Library history.

## Left Quick Controls

Map, Trophy, and Settings occupy a compact vertical stack only within exposed map space. The stack moves continuously to stay above an approaching pine edge, fades when insufficient map area remains, and is absent in Full/MAX contexts where it cannot fit.

All three grow the same upper pine from the selected control’s origin. Map shows the map-mode selector. Settings shows persisted quick settings. Trophy remains empty.

## Quick Settings

The quick Settings pine persists:

- Metric or Imperial units.
- Auto Pause.
- Keep Screen Awake.
- Balanced or Precise GPS accuracy.
- Hybrid, GPS, or Barometer elevation source.
- Speed smoothing.
- Manage Offline Maps entry.
- Auto-download Route Area.
- Weather Info.
- Manage Music entry.
- Audio Cues: Off, Quiet, or Normal.
- Default visibility: Private or Public.
- Hide Start & Finish and its selected privacy distance.
- Allow Comments.
- Show Player Tracks.
- Haptics.
- Preferred export format: GPX or FIT.

Preference changes affect the current session where safe and future sessions durably. A recording-quality change never rewrites already accepted samples.

## Export and Sharing

GPX and FIT are functional export formats. Share uses the selected format and the system share surface.

Private exports contain the complete private route unless the user explicitly requests a privacy-applied copy. Public/Profile exports apply the selected endpoint hiding while leaving the stored private track unchanged.

Export failures remain in the route feature and do not change activity visibility or established state.

## Recovery and Data Migration

Every existing finished activity becomes a Private Library activity. Existing raw points, titles, times, pauses, laps, planned-route references, and summary values are retained.

Existing combined Run & Walk activities retain their legacy type. They are visible in All Types and under an explicit legacy label rather than being inferred from speed.

Old unfinished activities remain recoverable. Opening recovery restores the existing activity identity, track, pause state, type, planned route, and metrics instead of creating a new activity.

New fields decode safely when absent. Private is the migration visibility, unstarred is the migration star state, public metadata begins empty, and no historical played-track data is fabricated.

Backup and import include the expanded manifest, raw track, planned route references, tags, privacy preferences, played-track references, and route-related settings while preserving duplicate-skip behavior.

## States and Failure Behavior

| State | Visible result | Behavior |
|---|---|---|
| Location not determined | Start remains visible | Permission is requested only when recording starts |
| Location denied/restricted | Concise in-pine explanation | No fake route or metrics; Settings recovery action is available where appropriate |
| GPS temporarily unavailable | Existing route and metrics remain | Recording waits for accepted samples and clearly reports degraded status |
| Offline | Map uses installed data where available; recording metrics continue | Weather and network-only layers use cached or unavailable states |
| Recoverable activity | Recovery entry appears | Restores the same manifest and raw track |
| Empty Library | Empty Library and Starred states | Start remains reachable without fabricated cards |
| Filtered Library empty | Filter-specific empty state | Starred remains unchanged |
| Weather unavailable | Weather hides or reports unavailable noninteractively | Recording continues |
| Music empty | Real empty destination | Search/import behavior remains available without placeholder tracks |
| Provider unavailable | Mode or music source reports the real requirement | No mock content or false success |
| Export failure | In-pine error | Activity remains established and unchanged |
| Reduce Motion | Large movement becomes restrained reflow/crossfade | Direct drag remains one-to-one |
| Reduce Transparency | Readable opaque surfaces preserve geometry | No backdrop capture is attempted |

## Animation Rules

- Direct pine resizing tracks the finger one-to-one and remains interruptible.
- Release uses velocity-aware spring settling to the nearest valid detent.
- Compact-to-zero dismissal continues the same glass-edge movement and never becomes a translated modal sheet.
- Main pine content changes morph and reflow within one surface.
- Native iOS 26 glass identities are stable across related transitions so the material participates in the morph.
- Older-system glass preserves the same frames and transitions even though the material renderer differs.
- Icons use restrained system-symbol replacement, pulse, rotation, or state transitions tied to real actions.
- Metric digits roll only when their value changes.
- Press feedback begins on touch-down and remains subtle.
- Reduce Motion removes large spring travel, automatic marquee motion, and decorative symbol effects while retaining clear state changes.

## Accessibility

All icon-only actions expose meaningful labels and current state. Pine handles expose adjustable accessibility actions for moving between detents and dismissing closable pines. Type and Music wheels expose selected and previewed values. Color is never the only state signal. Dynamic Type preserves essential controls and allows internal scrolling where content cannot fit. VoiceOver focus follows content replacement inside the same pine without announcing it as a new page.

## Files

- `TimeMasterCore/Sources/Models/OutdoorActivityManifest.swift` — durable activity and publication fields.
- `TimeMasterCore/Sources/DatabaseManager.swift` — activity, track, route, and migration persistence.
- `TimeMaster/Models/OutdoorActivity.swift` — iOS-facing activity state and legacy type compatibility.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` — route Library, recovery, finalization, filtering, and mutation owner.
- `TimeMaster/Services/Outdoor/` — location, metrics, elevation, weather, map providers, offline data, privacy, and export services.
- `TimeMaster/Views/Outdoor/` — permanent map and all F28 pine states.
- `TimeMaster/Models/MusicLibraryModels.swift` — shared music references and section membership.
- `TimeMaster/ViewModels/MusicLibraryStore.swift` — shared ordered Music Settings and F28 editor data.
- `TimeMaster/Utilities/MusicManager.swift` — real local playback and route-session track events.
- `TimeMaster/Views/MainTabView.swift` — full-screen F28 presentation and shared dependencies.
- `TimeMaster/Views/Home/`, `TimeMaster/Views/WorkoutList/`, `TimeMaster/Views/History/`, `TimeMaster/Views/Profile/`, and `TimeMaster/Views/Analytics/` — entry points and route detail/profile integration.

## Dependencies

- F09 — file-backed data architecture and single-writer persistence.
- F24 — application slot navigation and full-screen destination behavior.
- F25 — persisted Music Settings library and local playback.
- F26 — cross-version Liquid Glass policy.
- F27 — Home outdoor shortcuts and widgets.
- Apple Core Location and Core Motion for recording and elevation.
- Apple WeatherKit for display-only weather.
- MapLibre Native and approved production data providers for map rendering and layers.
- Existing unfinished outdoor manifests and tracks remain migration inputs.

## Reference

- `tmux_route_recording_prototype (1).html` — authoritative monolithic product and interaction specification. Read the entire file, including comments, styling, markup, and behavior, before implementation changes.
- `features/F25-Music-Player-Update/DOCKS.md` — existing Music domain and provider boundaries.
- `features/F26-private-liquid-glass/DOCKS.md` — approved private older-system glass policy.
- `genesis/REFERENCE/` — inspect relevant mapping, motion, and outdoor references before implementation.
