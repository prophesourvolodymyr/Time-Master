# F28-D — Map Platform

F28-D owns the one persistent interactive map behind the iPhone route feature. It provides a provider-neutral map, route overlays, camera and follow state, display-only weather, map-side controls, real map modes, attribution and licensing behavior, and the service boundary for offline regions. It does not own route recording metrics, the Music editor, Library mutations, or the quick-settings preference store; those surfaces consume this map state through their sibling contracts.

## What We Build

- One long-lived native map instance for the entire full-screen route feature. Start, live workout, Finish, Establish, Library, Library detail, Type, Music, Rate, Route, the upper quick pine, and the compact player remain layered over this same map.
- A permanent background that remains visible wherever no pine covers it. Opening a feature never replaces the map with a black filler surface, creates a second map, or resets the map camera.
- An interactive exposed-map region. Direct map pan and the provider's native map gestures remain available wherever pines do not cover the map; covered regions belong to the pines.
- A provider-owned normalized data boundary for vector streets and paths, terrain and elevation, satellite imagery, buildings, transit, traffic, cycling attributes, map styles, attribution, network requirements, and offline rights.
- Real Explore, Terrain, Satellite, 3D, Transit, Traffic, Cycling, Dark, and Direction presentations of the same map. Selecting a mode changes the map's real style or data layers rather than changing screens.
- Recorded-route and planned-route overlays with stable activity identity, plus route thumbnails derived from the real recorded geometry or a cached map snapshot.
- Location focus and follow-user behavior, including device-heading camera orientation for Direction mode.
- A display-only WeatherKit presentation containing temperature and current condition, with honest cached, hidden, and unavailable states.
- A right-side control group for offline-area entry, location focus, and weather display, plus the left map/trophy/settings quick-control stack that belongs to exposed map geometry.
- The native Liquid Glass map-related surfaces on iOS 26 and later, and the existing private glass renderer on iOS 16–25, with identical geometry, state relationships, motion, and accessibility behavior.

## Architecture

The map layer owns one map session and keeps these state families together: provider data availability, selected map mode, camera position and zoom, follow state, device heading, recorded and planned overlays, installed offline regions, attribution, and weather presentation. A mode change, route-state change, pine resize, or sibling focus change updates this session in place.

The normalized provider boundary is independent of the map renderer. The existing native map solution consumes normalized vector, raster, elevation, overlay, transit, traffic, cycling, style, attribution, and capability information. Provider changes, licensing changes, offline packaging, and a future renderer migration must not require a new route UI or a new camera model. The existing OpenGL-based renderer remains an implementation input on older builds; the product contract is the provider-neutral map state, not a particular vendor SDK.
 
Explore's normalized vector contract should use an OpenMapTiles/OSM-compatible schema or an equivalent production schema for roads, paths, buildings, places, cycling attributes, and styling. The exact host and provider remain a product/provider decision governed by production licensing, attribution, caching, and offline-use terms. The HTML's small locally bundled USGS National Map raster is prototype-only visual context with no runtime network dependency; it supplies no provider, route, search, polyline, or location behavior for the product.

The map does not own recording truth. Core Location/GNSS accepted samples remain the source of live distance and speed, and the map remains a presentation and overlay system even when no network map data is available. Recording, elevation totals, pause/resume, and recovery belong conceptually to F28-C. Library cards, finalized detail, privacy, and export consume the same saved route geometry through F28-F and F28-G without duplicating map ownership.

## Persistent Map and Camera State

- The map instance is created once for the route feature session and survives every in-place pine transition.
- Camera position, zoom, route visibility, selected mode, follow state, and installed-region state remain intact while the user changes pines, switches modes, starts or pauses a workout, finishes, resumes, establishes, opens Library, or returns to Start.
- A user pan is direct manipulation of the exposed map. It exits follow mode without stopping recording, changing the route, or changing the selected mode.
- Location focus centers the current position through the real location service and enables follow-user behavior. Follow follows the current position while the user permits it; a later pan disengages follow until the user explicitly focuses location again.
- Direction is a camera/orientation presentation over the existing map. It uses the device heading and native location/map camera state, not a second provider or a separate route view. If heading is unavailable or unreliable, the map reports the degraded orientation state and retains the route and camera rather than fabricating a direction.
- Camera changes caused by location follow, mode changes, or map gestures are interruptible and do not discard a partially completed pine gesture.
- The map has no search bar in this feature. Search, if supplied by another product later, must not be inferred from this contract.

## Route Overlays and Thumbnails

The active accepted recording route is drawn over the map as it grows. A planned route, when the activity has one, remains a separate overlay with its own identity and does not overwrite the recorded track. Both overlays remain available through pan, follow, mode changes, offline transitions, and pine morphs. Invalid or rejected location samples never create visible route geometry merely because they reached the map layer.

Finished activities retain their complete private route geometry. Library and Starred cards use the real recorded polyline rendered by the map system or a cached snapshot of that geometry; prototype lines are not geographic data. The thumbnail preserves the saved route's identity and is regenerated or read from cache without inventing a route when geometry is missing. The workout-type badge shown over a card comes from saved activity type metadata; its detailed Library presentation remains F28-F-owned.

A route thumbnail or overlay may be unavailable while provider data is unavailable, but that does not make the activity, raw track, or recording unavailable. The UI reports the actual missing map presentation and keeps the underlying route data intact.

## Map Modes

The upper Map quick pine presents a horizontally browsable selector. Explore is the initial selected mode. The selector has no selected underline requirement; selection is communicated through the selected state and accessible state, not color alone. Every selection is a real provider-normalized mode in the product, even though the HTML selector is only a structural prototype.

| Mode | Product behavior and data boundary |
|---|---|
| Explore | General-purpose licensed vector streets, paths, buildings, places, and route context. The shared vector network is the geometric base for other vector styles. |
| Terrain | Real terrain elevation, hillshade, and contour context from licensed DEM/elevation data. Terrain presentation may enrich route context but is not required for live workout totals. |
| Satellite | Licensed aerial or satellite imagery with provider attribution, credentials, quotas, regional availability, network requirements, and legal caching rights handled by the provider boundary. It is not a screenshot layer. |
| 3D | The same map presented with real building heights and terrain elevation where available. It is a presentation mode, not navigation and not a separate map instance. |
| Transit | Nearby routes, stops, schedules, and live vehicles from normalized GTFS and GTFS-Realtime data where coverage exists. Regional coverage and real-time freshness are explicit capability states. |
| Traffic | Current traffic flow and incidents from a production traffic provider. Vector flow is preferred when available; a transparent raster overlay is an acceptable provider result. Freshness, rate limits, cost, attribution, and regional coverage remain visible service capabilities. |
| Cycling | A style and data filter over the shared vector network, surfacing cycleways, bicycle access, path and road classification, surface, and relevant bicycle attributes when supplied by the source. It is not a separate cycling map product. |
| Dark | A dark style applied to the existing vector map. It does not purchase, fetch, or instantiate a separate map merely to make the map dark. |
| Direction | Device heading and camera orientation applied to the existing map. It uses no new map data provider. |

Switching modes preserves camera, follow state, recorded and planned overlays, active workout, installed-region state, and pine geometry. Unsupported or unavailable mode data degrades only that mode; the route feature never reports a false successful layer and never interrupts recording.

## Attribution, Licensing, and Offline Capabilities

Every provider-backed layer declares the attribution, license, network requirement, cache permission, offline permission, freshness, regional coverage, and failure behavior required for its data. Required attribution remains visible in the native map presentation wherever the chosen provider requires it, including satellite, terrain, traffic, transit, and other licensed sources. Provider credentials, quotas, costs, and usage restrictions are service concerns rather than UI assumptions.

The offline system supports installed regions and provider-validated layer capabilities. The approved MapTiler Cloud configuration is online-only unless a separate written license grants offline packaging; it never bulk-downloads or repackages MapTiler Cloud or OpenStreetMap display tiles by implication. New offline regions therefore require an explicitly offline-licensed or self-hosted source. Existing legacy installed packs remain discoverable. Vector, terrain, imagery, traffic, transit, and other layers may have different legal caching rights, and an installed vector region never implies that every other layer can be cached.

The right download control represents an offline geographic-area service boundary, not an on/off toggle. In the eventual native flow, the same map presentation focuses or expands for area selection; the user can pan and resize a geographic selection region directly, and the final screen-space bounds become real geographic bounds through the map/provider boundary. The offline service owns availability checks, region resolution, provider-rights validation, storage accounting, download progress, cancellation, errors, and installed-region persistence.

The visible area-selection rectangle, resize handles, confirm and cancel controls, download progress presentation, and installed-region management interior are intentionally not defined by the authoritative HTML. This specification therefore preserves the request, geographic-bounds, capability, progress, cancellation, failure, and installed-state contracts without inventing those controls or displaying fake progress. The old fixed-current-area offline interface is not revived. Existing installed packs remain discoverable through the new service.

## Map-Side Controls

The right-side map controls remain tied to the exposed map and the live pine geometry:

- **Download** begins the deferred offline-area contract described above. It never pretends that a region was downloaded merely because the control was pressed.
- **Location** focuses the current position and enters follow mode through the real location and camera services. Its pressed state reflects real follow state, not a local visual toggle. A pan exits follow without affecting recording.
- **Weather** is a noninteractive display. It is never a tappable action, never opens a weather screen, and never controls map or recording state. Its compact presentation shows temperature and current condition when available.

The map controls remain in exposed map space and must not paint through a pine. When a lower feature or the main route pine consumes map height, the controls follow the remaining map geometry or become unavailable when there is no room. They remain absent from the flat MAX composition except for controls explicitly owned by the focused pine.

## Upper Quick Pine and Map Geometry

The left exposed-map stack contains compact icon-only Map, Trophy, and Settings buttons with generous native hit targets. It is a map-layer control, not a fourth pine. The stack's preferred position is derived from the actual exposed map and safe-area layout, not from a fixed phone coordinate.

As the upper edge of the main route or lower feature pine approaches, the entire stack translates upward continuously so the glass capsule stays completely inside the exposed map. It fades when the full stack cannot fit and is absent at the normal full-height and true MAX states. It does not remain painted through a growing pine. When the upper quick pine or another focused surface owns the region, the stack is hidden while that surface is open.

Each left button grows the same upper quick pine from the button that opened it. The opening origin is preserved as transient state, the same base morphs between Map, Trophy, and Settings content without navigation, and closing the pine morphs back toward its originating button rather than toward the Library control. The main route pine remains the lower sibling; the Library control beside Start never opens this upper pine.

Map content in the upper pine is a compact, horizontally swipeable set of the nine real modes above. The cards are a selection surface, not miniature maps. Trophy/Competition has only its structural quick pine and remains visually empty until a separate approved product contract exists. It is not disabled, but it has no invented copy, metrics, cards, network calls, or backend behavior. This same empty-interior rule applies to any other unnamed or not-yet-designed map-adjacent feature.

## WeatherKit Display Contract

Weather is automatic, display-only map information. When the Weather Info preference is enabled, the map requests current temperature and condition for the relevant location through Apple WeatherKit and presents the latest valid result. The service owns location-to-forecast lookup, entitlement/capability, network access, caching, attribution, and refresh cadence.

A cached last-known value may remain visible only temporarily and no later than the provider response expiration while the service is refreshing or briefly offline. WeatherKit data is never written to the durable activity manifest, Library history, backup, or a secondary weather database. If no still-permitted value exists, Weather hides or reports unavailable in a noninteractive control. WeatherKit failure, missing capability, denied location, rate limits, or network loss never blocks map interaction, route recording, offline metrics, or map mode changes. Weather Info disabled removes the display without changing other map state.

## States and Failure Behavior

| State | Visible result | Behavior |
|---|---|---|
| Normal online map | Current selected provider mode, overlays, controls, and required attribution | Camera, pan, follow, heading, and mode changes operate on the same map session. |
| Offline with installed vector or layer data | Installed capabilities remain visible | The map uses only legally installed data. Network-only layers show their real unavailable or stale state. Recording distance, speed, and accepted route samples continue independently. |
| Offline without installed map data | Map reports unavailable or reduced presentation | No bundled fake route or false layer success is shown. Core Location recording remains usable. |
| Provider unavailable | The affected mode or map source reports the real requirement or unavailable state | Other supported layers remain usable where possible; camera, overlays, and recording identity are preserved. |
| Partial regional coverage | Transit, traffic, satellite, terrain, or 3D reports limited coverage or missing capability | The mode does not fabricate vehicles, traffic, imagery, buildings, or elevation. Explore and available overlays continue. |
| Traffic or transit stale | The layer identifies degraded freshness or is withheld | The route and map remain active; stale real data is not presented as current. |
| Location permission denied or restricted | Location focus/follow reports the permission state | The map remains interactive; recording does not create fake movement. Recovery actions belong to Settings and the recording service. |
| Location temporarily unavailable | Existing camera and overlays remain | Follow waits for a valid location and reports degraded status rather than jumping to an invented position. |
| Heading unavailable | Direction falls back to a supported neutral orientation or unavailable state | No false heading is shown; route, camera, and other modes continue. |
| Weather unavailable | Weather hides or reports unavailable without interaction | Cached data may be used when valid; recording and map layers continue. |
| Offline-area request deferred | No selection rectangle, progress, or installed claim is shown by this contract | The service boundary remains ready for a later approved selection UI. |
| Map mode change in progress or failed | Existing map and overlays remain while the affected layer settles or reports failure | Pine geometry, workout state, camera, and route identity never reset. |
| Route geometry unavailable for thumbnail | Honest missing snapshot state | The activity and private raw track remain intact; no decorative route line is substituted. |

## Motion and Accessibility

- Map panning and boundary manipulation, when the approved offline-area UI exists, remain one-to-one with the user's finger and interruptible.
- Mode changes use restrained native transitions that preserve the map identity rather than crossfading into a second map.
- The upper stack follows map exposure continuously during pine drag. It does not wait for a resting detent before moving or disappearing.
- The native iOS 26 map surfaces use stable Liquid Glass identities. iOS 16–25 uses the existing private renderer with the same frames and transitions.
- Reduce Motion restrains large camera and glass travel while preserving direct manipulation, clear selected states, and essential map changes. Reduce Transparency uses readable opaque surfaces without backdrop capture.
- Every icon-only control has a meaningful VoiceOver label and current state. Weather is announced as information, not an action; download describes its offline-area purpose without promising a download; location exposes follow state; mode cards expose selected mode and capability state.
- Dynamic Type keeps attribution, failure messages, mode names, and controls readable within the iPhone safe area. Horizontal mode content scrolls rather than truncating essential labels. Native hit targets remain larger than their compact visual geometry.
- Color is never the only signal for selected, unavailable, stale, following, or failed states.

## Responsive Geometry and Platform Boundary

The map fills the actual iPhone destination and respects safe areas and device bounds. The HTML's 390 × 844 canvas is a visual reference only; controls, attribution, overlays, and quick stacks derive their geometry from the real exposed map and pine layout guides.

The route feature is iPhone-only. Native Liquid Glass is used where the public iOS 26 APIs exist; iOS 16–25 uses the selected existing private glass renderer. No new F28 map interface is added to macOS. Shared route, map-mode, installed-region metadata, and raw-track data remain compatible with a future macOS surface without implying that a macOS UI exists now.

## Files

- `TimeMaster/Services/Outdoor/` — map provider normalization, camera/follow/heading, route overlays, offline-region capability, attribution, and WeatherKit boundaries.
- `TimeMaster/Views/Outdoor/` — the permanent map host, map-side controls, exposed-map quick stack, upper Map pine, and map accessibility geometry.
- `TimeMaster/Models/OutdoorActivity.swift` — route and planned-route identities consumed by overlays and snapshots.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` — finalized activity route references and recovery-preserved identity consumed by map details.
- `TimeMasterCore/Sources/Models/OutdoorActivityManifest.swift` — durable route references and settings metadata that must survive migration and backup.

## Dependencies

- RF28-A — replaces the old single-provider map and fixed-current-area offline surface while preserving installed data and route identities.
- F28-B — provides the persistent pine geometry, safe-area layout, Liquid Glass policy, and direct drag behavior that constrain exposed map space.
- F28-C — supplies accepted location samples, recording route state, offline metrics, permission, and recovery ownership.
- F28-F — consumes real route geometry, thumbnails, saved type metadata, and finalized activity details.
- F28-G — supplies Weather Info, Auto-download Route Area, location/privacy recovery, backup/import, and capability-state preferences.
- F26 — defines native Liquid Glass on iOS 26 and the older-system private renderer policy.
- Apple Core Location and Core Motion — location and heading state used by focus, follow, Direction, and recording boundaries.
- Apple WeatherKit — display-only current weather capability and cache boundary.
- MapLibre Native and approved production providers — normalized vector, raster, elevation, transit, traffic, satellite, cycling, attribution, and legal offline capabilities.

## Reference

- `tmux_route_recording_prototype (1).html` — authoritative permanent-map, provider-boundary, map-control, mode-selector, weather, quick-stack, and deferred offline-area contracts.
- `features/F28-better-maps-recording/DOCKS.md` — parent map, mode, weather, offline, geometry, and failure decisions.
- `features/F28-better-maps-recording/RF28-A-outdoor-remake-migration/DOCKS.md` — map migration, provider normalization, installed-region, and old-interface removal decisions.
