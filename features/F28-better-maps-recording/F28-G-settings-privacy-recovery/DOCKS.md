# F28-G — Settings, Privacy, and Recovery

F28-G owns the persisted quick settings used by the iPhone route feature, their current-session and future-session effects, endpoint privacy, migration defaults, recovery entry, backup/import, and unusual capability states. The compact Settings surface is an upper quick pine, not a pushed Settings page. F28-C owns sensor and recording truth, F28-D owns map and WeatherKit services, F28-E owns Music playback and its shared library, and F28-F owns Finish, Establish, Library, Profile, export execution, and deletion.

## What We Build

- A dense, vertically scrollable Settings quick pine opened by the exposed-map Settings control. It keeps the map behind it and closes through the same upper-pine back control.
- Persisted preferences for every quick-setting row shown in the HTML, with honest defaults and real service/domain effects rather than transient prototype toggles.
- Clear separation between preferences that can affect the current route session safely and defaults that apply only to future workouts or future publication.
- Per-workout privacy overrides for visibility, endpoint hiding, comments, and played-track display, without destroying public metadata when visibility changes.
- A complete private-track invariant: endpoint hiding affects a public/Profile representation or an explicitly requested privacy-applied copy, while the locally stored private route remains complete and unchanged.
- Recovery entry for interrupted, paused, recording, finished-but-not-established, and otherwise recoverable activities, restoring the original activity identity rather than creating a new recording.
- Backward-compatible migration of finished and unfinished activities, including the preserved legacy Run & Walk type and safe defaults for newly introduced fields.
- Backup and import of the expanded outdoor manifest, raw route, planned-route references, publication/privacy fields, playback references, route preferences, and portable offline-region metadata.
- Real haptic and audio-cue preferences, WeatherKit capability handling, offline behavior, and iPhone-only platform boundaries.

## Quick Settings Surface

The Settings quick pine is grouped into Workout, Recording, Maps & Offline, Music, Privacy, and Feedback & Export. It remains one compact scrollable surface inside the upper morphing pine; it is not a dashboard, modal sheet, or second navigation destination. Native toggles, segmented choices, picker-like values, VoiceOver labels, and Dynamic Type preserve the hierarchy without treating HTML state as product data.

| Group | Setting and HTML default | Current-session effect | Future-session and durable effect |
|---|---|---|---|
| Workout | **Units — Metric** | Updates distance, speed, pace, and related displays in the open route session where the values are already available. It does not rewrite stored route points or historical summaries. | New sessions and their live/finish/detail displays use Metric until the user changes it. The preference is persisted. |
| Workout | **Auto Pause — On** | Changes automatic stationary handling for an active recording when the recorder can apply the change safely. The existing twenty-second stationary rule and movement confirmation remain intact; a manual pause always blocks automatic resume until the user resumes explicitly. | New sessions start with Auto Pause enabled. The preference is persisted and does not retroactively alter pause intervals already recorded. |
| Workout | **Keep Screen Awake — Off** | Changes display idling for the current recording where the platform allows it. It never changes recording ownership, location collection, background behavior, or recovery. | New sessions inherit the persisted choice. |
| Recording | **GPS Accuracy — Precise** | Requests the selected location-quality policy for the current location session when safe. A quality change cannot rewrite or reclassify accepted samples. | New sessions use the persisted Balanced or Precise choice. |
| Recording | **Elevation Source — Hybrid** | Changes the source strategy for subsequent elevation processing when safe. Already accepted elevation and route samples remain unchanged. Hybrid uses quality-filtered absolute altitude with barometric relative changes when supported; GPS and Barometer remain selectable, with GPS elevation as the degradation path when barometer data is lost. | New sessions inherit Hybrid, GPS, or Barometer. The setting remains usable offline and is independent of map rendering. |
| Recording | **Speed Smoothing — On** | Changes only live speed presentation for subsequent readings. It reduces GPS jitter without making acceleration or stopping feel artificially delayed; accepted distance and existing metrics are not rewritten. | New sessions inherit the persisted smoothing choice. |
| Maps & Offline | **Offline Maps — Manage** entry | Opens the real installed-region/offline service when that destination is available. It does not fabricate storage totals, tiles, regions, or progress inside the quick pine. | Installed-region metadata and provider capabilities remain durable through the offline service. The map-area selection interior is intentionally deferred as described by F28-D. |
| Maps & Offline | **Auto-download Route Area — Off** | When enabled during an active route session, the service may prepare eligible nearby route data subject to network, storage, provider rights, and current-route capability. It never blocks recording or implies that every layer can be cached. | New sessions inherit the persisted choice. Provider-specific legal rights still govern what can be prepared. |
| Maps & Offline | **Weather Info — On** | Shows or hides the display-only weather presentation for the current map session. It never turns weather into a button or blocks recording. | New sessions inherit the persisted choice. WeatherKit and cache capability still determine whether a value is visible. |
| Music | **Music Sections — Manage** entry | Opens or focuses the existing Music Settings section system when available. It does not create a second music catalog or alter the route pine's temporary playback state merely by opening the entry. | Music memberships, providers, accounts, artwork, and playable references remain owned and persisted by the existing Music Settings system. |
| Music | **Audio Cues — Quiet** | Uses the real audio-session/cue service for subsequent workout announcements in the current session. Off produces no cue, Quiet uses restrained announcements, and Normal uses the normal product level. | New sessions inherit Off, Quiet, or Normal. An unavailable audio session reports the capability honestly and does not fabricate sound. |
| Privacy | **Default Visibility — Private** | Seeds the visibility choice for an unfinished Finish/Establish flow when the user has not made a per-workout choice. It does not silently change an already established activity. | New established activities default to Private. Public remains an explicit per-workout choice and creates a local Profile post only after establishment. |
| Privacy | **Hide Start & Finish — On** | Seeds the endpoint choice for the current unfinished Establish flow and any explicitly requested privacy-applied export. It does not alter the complete stored route. | New public representations inherit the persisted default unless overridden. The available distances are 100 m, 200 m, and 500 m, with 200 m as the default. |
| Privacy | **Allow Comments — On** | Seeds the current Establish or public-detail draft when no per-workout value has been chosen. It does not create comments or remote delivery. | New public activities inherit the persisted default. The preference is publication metadata for the future social boundary. |
| Privacy | **Show Player Tracks — On** | Seeds the current Establish or public-detail draft. It does not change the private playback history already captured for the route. | New public representations inherit the persisted default. The complete local played-track history remains available to the activity owner; public display is a separate preference. |
| Feedback & Export | **Haptics — On** | Enables haptic feedback for pine interactions, selections, and workout actions for the current session. Turning it off removes those optional cues without removing state changes. | New sessions inherit the persisted choice. Native hit targets and visible state changes remain available with haptics off. |
| Feedback & Export | **Export Format — GPX** | Sets the preferred format for the next Share/Export action in the current route flow. Both GPX and FIT are functional formats; a failed export does not change activity state. | New and later export actions inherit the persisted GPX or FIT choice until changed. It is a preference, not a second exporter surface. |

A setting change is persisted through the app's durable preference boundary rather than kept as HTML-like in-memory state. Recording-quality changes are forward-looking for accepted data: they may change subsequent collection or presentation where safe, but never rewrite accepted samples, stored distance, raw route, or historical summaries.
 
## Settings Interaction and Motion

The Settings control is one of the three exposed-map quick buttons. It opens the shared upper quick pine from that button's origin at the compact quick-pane geometry; it does not push a page, replace the map, or move the lower route pine. The originating control remains transient state so closing the upper pine morphs back toward Settings rather than toward the Library control. The map stays behind the glass surface wherever it remains exposed.

The settings list scrolls inside the pine and fades at its top and bottom boundaries. Opening, closing, and row feedback use restrained opacity, scale, and glass morphs tied to the originating control. A quick-setting row changes its own value without resetting the list position or the selected route/map/music state underneath. Manage Offline Maps and Manage Music provide tactile press feedback and then enter their real service boundaries; they are not fake toggles. The quick pine remains dismissible through its back control, and its content does not become a new navigation stack.

During direct pine resizing, the upper surface follows the finger one-to-one and remains interruptible. Reduce Motion removes large spring travel and decorative effects while preserving the resize, scroll, selection, and state transitions. The settings surface remains a sibling to the lower route or feature pine and never paints through it.

## Privacy and Publication Invariants

Visibility is a durable activity property with Private and Public values, and an explicit visibility change takes effect immediately and remains durable. The default applies to new establishment only; an established activity changes visibility only through an explicit Library or Profile-capable detail action. Public activities appear as posts in the user's local Profile. Remote social accounts, comment delivery, and server publication are outside this version, although the durable metadata remains ready for a future publication boundary.

When a Public activity becomes Private, the system retains its description, reusable tags, comments preference, endpoint distance, and player-track visibility preference. Returning it to Public restores those fields intact. Private migration records begin with no public metadata; public metadata retention becomes true only after the user first saves Public metadata. Changing a default never destroys or silently rewrites an existing activity's fields.

Hide Start & Finish is an endpoint presentation rule, not destructive redaction of the source route:

- The user chooses 100 m, 200 m, or 500 m; 200 m is the product default.
- The complete private route remains stored locally for recovery, private detail, and a normal private export.
- Public/Profile geometry applies the selected endpoint hiding before presentation or export.
- A private export contains the complete route unless the user explicitly requests a privacy-applied copy.
- Endpoint privacy is durable metadata and remains available when a workout changes visibility.

Allow Comments records the future-publication preference without inventing a comment system. Show Player Tracks controls whether played-track information is included in a public representation; it does not delete the local historical references. Reusable user-created tags and recent-tag suggestions belong to Establish and Library, while this surface supplies only the durable defaults and preserves them across visibility changes.

## Permission and Recovery States

| State | Visible result and behavior |
|---|---|
| Location not determined | The route can open normally. Permission is requested only when recording actually starts, not merely when the map or Settings pine appears. |
| Location denied or restricted | The feature remains in place with a concise explanation and an appropriate Settings recovery action. It creates no fake route, distance, speed, or weather position. |
| Location temporarily unavailable | Existing route and metrics remain. Recording waits for accepted samples and reports degraded status; recovery does not create a new activity. |
| Location recovered | The same active session resumes accepted collection under the selected quality policy. Previously accepted samples and pause state remain intact. |
| Recording or paused activity recoverable | A recovery entry is offered when the route feature opens. It restores the original manifest, raw track, type, planned-route reference, pause state, title draft, metrics, and music history. |
| Finished but not established | Recovery restores the same in-place Finish state and offers Resume, Establish, Share/Export, or Delete according to the owning F28-F contract. It does not silently establish or discard the activity. |
| Process interruption, backgrounding, or screen lock | Durably appended accepted route samples and the session manifest remain recoverable under the platform's active location-session rules. Keep Screen Awake changes only display idling. |
| Recovery data incomplete or a new optional field is absent | The activity decodes with safe migration defaults. Existing identity, raw track, type, planned route, pause state, and summaries remain authoritative. |
| Offline | Location-based recording metrics continue without internet. The map uses legally installed data where available; WeatherKit and network-only map layers use cached or unavailable states. An offline download waits for the real service and never reports false progress. |
| No installed offline regions | Manage Offline Maps reports an honest empty installed-region state. The route remains recordable, and the deferred area-selection UI is not replaced with an invented rectangle or fixed-area screen. |
| Weather disabled, unavailable, or stale | Weather Info hides the display when disabled. WeatherKit capability, location, network, or refresh failure produces cached last-known data when valid or an unavailable state; recording continues. |
| Music library empty | Manage Music opens the real empty Music destination without placeholder tracks. Playback and route history remain empty until a real playable item exists. |
| Music provider unavailable | The existing Music system reports the provider/account requirement honestly. Quick settings do not fabricate tracks, accounts, or playback state. |
| Library empty or filter empty | The owning Library surface shows its real empty Library, Starred, or filter-specific state while keeping Start reachable. Settings does not fabricate cards or records. |
| Export failure | Share/Export reports an in-pine error and preserves activity visibility, public metadata, private route, and established state. The preferred format remains a preference rather than a false success. |
| Backup/import unavailable or malformed | The operation reports the real failure and leaves existing activities untouched. No partial activity or fake installed region is created. |
| Duplicate import | Existing activity identity wins. Duplicate-skip behavior avoids replacing an existing activity merely because optional fields differ. |

Permission recovery belongs in the real system settings boundary and never hides an active recovery manifest. Weather and map capability failures remain display/service states; they do not become recording failures.

## Migration Defaults and Legacy Data

Every existing finished outdoor activity migrates into the F28 Library as an established Private activity. Its existing identifier, raw track, title, timestamps, elapsed and moving time, distance, pauses, laps, planned-route reference, and summary values remain authoritative. Migration is idempotent and does not duplicate records, regenerate identifiers, or repeatedly reset user choices.

Migrated finished activities use these defaults:

- Visibility is Private.
- Star is off.
- Description and reusable tags are empty.
- Comments use the current product default, with no fabricated historical comments.
- Endpoint hiding uses the current privacy default, initially 200 m.
- Played-track history is empty because historical playback cannot be reconstructed honestly.
- The complete raw route remains private and unchanged.
- Public metadata retention is false until the user first saves Public metadata.
- The existing combined Run & Walk value remains the legacy type and is never inferred or silently reclassified as Run or Walk.

New records use distinct Run, Walk, and Bike types. The legacy Run & Walk value remains decodable, visible under its explicit legacy label, and available in All Types without becoming a new-recording choice.

Existing unfinished activities remain unfinished and recoverable. Migration restores the same identity and raw track rather than making a new activity. Their recording, paused, planned-route, metric, and title-draft state remains available to the route feature.

## Backup and Import

Backup includes the expanded outdoor manifest, raw track files, planned-route records and references, Public/Private metadata and retention state, reusable tags, endpoint privacy distance, played-track references, portable artwork references where available, route recording preferences, and offline-region metadata that is safe to restore. Provider-protected tile or imagery payloads are not represented as portable success merely because region metadata exists; restored availability is reconciled with the provider's current rights and capabilities.

Import preserves stable activity identity and duplicate-skip behavior. An existing activity is not overwritten simply because an imported record contains newly introduced optional fields. Missing optional fields decode to the migration defaults above. A failed import leaves existing activities, raw routes, publication metadata, and installed-region state unchanged.

## Designed UI, Deferred UI, and Empty UI

The designed Settings UI is the compact scrollable quick pine and the complete row contract above. Manage Offline Maps is a real entry to the service-owned installed-region flow, and Manage Music is a real entry to the existing Music Settings system; neither row invents a duplicate destination, storage model, provider account model, or fake progress interior.

The geographic selection rectangle, resize handles, confirm/cancel controls, and progress presentation for downloading an offline area are intentionally deferred because the authoritative HTML does not define them. F28-D keeps their service boundaries without presenting invented controls here. Trophy/Competition, Trips, Rate, Route, and any other named feature without an approved interior remain structurally empty when their parent surface requires them; empty does not mean a fabricated dashboard, explanation, network call, or storage model.

Weather is informational rather than designed as an action. The quick Settings Weather Info switch controls whether that information may appear; it never makes the weather control tappable.
 
## Responsive Geometry and Platform Boundary

The quick pine uses the actual iPhone safe area and device bounds rather than the prototype's fixed canvas. Its row groups remain internally scrollable as height becomes constrained, while the map and the lower route/feature sibling keep their own live geometry. Compact visual controls retain native hit targets, and labels or values are reflowed or scrolled rather than clipped into an unreadable state.

F28 settings and recovery are iPhone-only. Native Liquid Glass applies on iOS 26 and later; iOS 16–25 uses the selected private glass renderer with the same layout and behavior. macOS receives no new F28 settings or recovery interface, although shared preferences, activity manifests, raw tracks, and migration metadata remain compatible with a later macOS surface.

## Haptics, Audio, Accessibility, and Motion

Haptics are optional feedback for pine resizing, control selection, mode and type confirmation, and workout actions. The visible press, selected, unavailable, and recovery states remain clear when Haptics is off. Audio Cues are Off, Quiet, or Normal and use the real playback/audio-session boundary; a missing capability reports no cue rather than simulating one.

The quick pine remains a scrollable iPhone surface with meaningful VoiceOver labels for every toggle, segmented value, managed destination, current value, and failure state. Dynamic Type keeps labels and values readable and allows internal scrolling when content cannot fit. Selected, disabled, stale, and unavailable states are never communicated by color alone. Reduce Motion uses restrained reflow and crossfade while preserving direct pine drag behavior; Reduce Transparency uses readable opaque surfaces without backdrop capture.

On iOS 26 and later the containing upper pine uses native Liquid Glass. On iOS 16–25 it uses the existing private glass renderer while preserving geometry, hierarchy, and accessibility. The F28 settings and recovery interface is iPhone-only; macOS receives no new F28 settings or recovery UI, while shared data remains compatible with a later macOS product.

## Files

- `TimeMasterCore/Sources/Models/OutdoorActivityManifest.swift` — durable visibility, public metadata, endpoint privacy, tags, played-track references, migration fields, and recovery identity.
- `TimeMasterCore/Sources/DatabaseManager.swift` — single-writer activity, route, preference, backup, import, and migration persistence.
- `TimeMaster/Models/OutdoorActivity.swift` — iPhone-facing activity state, legacy Run & Walk compatibility, and recoverable-session state.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` — recovery entry, finalization handoff, visibility metadata, and durable activity mutation ownership.
- `TimeMaster/Services/Outdoor/` — location permission/recovery boundaries, route preferences, WeatherKit capability/cache, offline-region service, privacy projection, and GPX/FIT export services.
- `TimeMaster/Views/Outdoor/` — Settings quick pine, recovery entry, in-pine capability/error states, and accessibility behavior.
- `TimeMaster/Views/Profile/`, `TimeMaster/Views/History/`, `TimeMaster/Views/Analytics/`, and `TimeMaster/Views/Home/` — consumers of migrated and recovered activity identity.
- `TimeMaster/Views/Settings/` and existing Music Settings models/store — managed preference and Music entry boundaries without a duplicate settings system.

## Dependencies

- F28-B — supplies the upper quick-pine geometry, direct motion, Liquid Glass policy, and accessibility container.
- F28-C — owns accepted location samples, recording quality, pause/resume, elevation, process interruption, and recovery session truth.
- F28-D — owns map modes, installed-region capability, follow/location camera, WeatherKit display, attribution, and deferred area-selection service boundary.
- F28-E — owns shared Music Settings, playback/audio session, temporary imports, and played-track history.
- F28-F — owns Finish/Establish defaults at the point of choice, Library detail edits, local Profile visibility, export presentation, and deletion safety.
- F09 — provides file-backed persistence and single-writer behavior.
- F24 — keeps the full-screen route destination and app-surface exit outside this quick pine.
- F25 — remains the single Music Settings and local playback data source.
- F26 — defines cross-version Liquid Glass and private older-system behavior.
- Apple Core Location, Core Motion, WeatherKit, and the system audio/haptic services — real capability boundaries for recording, weather, cues, and feedback.

## Reference

- `tmux_route_recording_prototype (1).html` — authoritative quick-settings rows/defaults, permission and service-boundary comments, privacy controls, recovery behavior, haptic/audio cues, and platform rules.
- `features/F28-better-maps-recording/DOCKS.md` — parent defaults, full-private-track invariant, publication, migration, backup, and unusual-state decisions.
- `features/F28-better-maps-recording/RF28-A-outdoor-remake-migration/DOCKS.md` — migration defaults, unfinished recovery, backup/import contents, and iPhone-only boundary.
