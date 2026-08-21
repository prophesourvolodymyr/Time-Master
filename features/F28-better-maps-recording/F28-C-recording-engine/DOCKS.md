# F28-C — Recording Engine

F28-C defines the real iPhone outdoor recording session behind the F28 route pine. It owns Run, Walk, Bike, and legacy Run & Walk type identity; authorization and start flow; accepted location samples; offline metrics; units; pause and resume precedence; elevation; background operation; durable checkpoints; interruption recovery; and the accepted-movement rule that decides whether a finished session can exist. F28-B owns the pine geometry and visual transitions around these states. F28-D owns map rendering and provider data. F28-E owns Music playback and played-track events. F28-F owns Finish presentation, Establish, Library, and deletion. F28-G owns persisted setting screens, privacy defaults, migration orchestration, and recovery entry presentation.

## What We Build

- A real, offline-capable recording session for new Run, Walk, and Bike activities.
- A preserved legacy combined Run & Walk activity type for existing records, with stable identity and label.
- Core Location/GNSS as the authoritative movement source, independent of map tiles, routing, traffic, or network reachability.
- Quality-filtered route points and durable route-distance accumulation.
- Elapsed time, moving time, instantaneous speed, maximum speed, total distance, pace, elevation gain, highest elevation, pause intervals, and recovery state.
- Configurable Balanced or Precise GPS quality, restrained live-speed smoothing, Auto Pause, Keep Screen Awake, and Metric or Imperial display preferences.
- A default Hybrid elevation source combining quality-filtered absolute GPS altitude with barometric relative changes when available, with honest GPS-only and Barometer selections.
- A session that remains owned by the same activity identity through pane resizing, feature changes, backgrounding, screen locking, process interruption, Finish, and recovery.

HTML values, timers, simulated movement, placeholder routes, and demo records are not recording data. The engine supplies real state to the route pine and persists it through the application’s file-backed single-writer data boundary.

## Activity Types and Identity

New recording offers exactly:

- **Run** — a distinct running activity type and native/system running symbol.
- **Walk** — a distinct walking activity type and native/system walking symbol.
- **Bike** — a distinct cycling activity type and native/system cycling symbol.

A neutral route entry defaults to Run. Home and Workout shortcuts may preselect Run, Walk, or Bike before the route session opens. The Type wheel’s centered value is only a visual preview; F28-C receives the committed value after the user accepts it, and the recording starts with that committed type.

Existing combined Run & Walk records retain their legacy type value, label, badge, summaries, and raw route. They remain visible as a distinct legacy type in historical Library filtering and are never silently classified as Run or Walk from speed, distance, title, or route shape. Legacy Run & Walk is not a new-recording choice.

The type is part of the durable activity identity from session creation through recovery and finalization. Changing a pine or opening Music never changes it.

## Recording Session Lifecycle

The engine exposes one durable session identity with these product states:

| State | Engine behavior | Route-pine consequence |
|---|---|---|
| Not started | No recording stream and no location request solely for showing Start | Start remains available; no fake metrics or route |
| Starting / awaiting authorization or first fix | Permission and location acquisition are reported honestly; no movement is fabricated | Start or an in-pine status explains what is needed |
| Recording | Accepted samples update route, distance, speed, time, moving time, and elevation; checkpoints are durable | F28-B shows live metrics in the same main pine |
| Manually paused | The same session and identity remain; movement and active timers stop according to pause policy; no automatic resume | Stop becomes Resume and a visible Stopped status remains |
| Automatically paused | The engine has observed the configured stationary rule; accepted movement is required before automatic resume | The paused state is distinct from normal recording and is announced in the pine |
| Temporarily degraded | Location or elevation input is unavailable or below quality requirements; prior accepted values remain | Degraded status is reported without fake movement |
| Finished and resumable | Live collection has stopped, but the finalized-in-progress session can be resumed from the same identity | F28-F presents Finish and Resume in the same pine |
| Established | The final activity is persisted as Library data by F28-F | The route feature can return to Start without losing the activity |
| Recoverable | A durable unfinished manifest and raw track can be reopened after interruption | F28-G presents recovery; F28-C restores the same session |
| Discarded short session | Finish was requested before three metres of accepted movement | No Finish or Establish state is created; the route pine returns to Start with a concise reason |

The route session remains alive when the user changes pine focus, resizes the main or sibling pines, opens a quick pine, changes map mode, or opens the Music Editor. A visual transition never starts a new activity or clears accumulated metrics.

## Permission and Start Flow

The route feature can show Start without location authorization. Location permission is requested at the moment the user begins recording, not merely when opening F28 or browsing Type, Music, Rate, Route, Library, or map controls.

At Start:

- The engine requests the authorization required by the platform and active-background recording policy.
- The selected committed Run, Walk, or Bike type becomes the session type only when recording begins.
- The engine reports authorization and first-fix progress inside the route feature. It never substitutes simulated movement, map motion, or a placeholder coordinate.
- If authorization is denied or restricted, recording does not begin and the route remains empty. The in-pine explanation is concise, and an appropriate settings recovery action is available without leaving behind a fake session.
- If location is temporarily unavailable, the session reports degraded acquisition and waits for an accepted sample. Existing accepted route and metrics remain unchanged.
- If authorization is later recovered, the same route feature can retry acquisition without creating a second activity identity.
- A device without network access may take longer to obtain its first high-quality GNSS fix. Once valid fixes exist, recording does not depend on internet connectivity or map availability.

The engine has no permission shortcut hidden in map, Weather, Music, or quick settings. Keep Screen Awake changes only display idle behavior and never grants, revokes, or owns recording permission.

## Accepted GPS Samples

Core Location/GNSS samples are the only authoritative source for accepted movement. The engine evaluates every incoming sample before it can affect the raw route, accepted distance, speed, moving time, or elevation totals.

A sample is eligible only when it has a valid coordinate, a usable timestamp, and quality suitable for the current GPS preference. The engine rejects or excludes samples that are:

- Missing, invalid, or outside valid geographic coordinate bounds.
- Inaccurate beyond the quality requirement selected for the session.
- Duplicated, timestamped identically to the preceding accepted sample, or timestamped earlier than it.
- Carrying an invalid negative speed or another physically implausible speed.
- A movement jump inconsistent with its elapsed time, reported accuracy, or plausible activity motion.
- Stationary or too small to cross the selected movement-quality threshold for an accepted distance segment.

Rejected samples do not erase or rewrite earlier accepted points. They do not add distance, create elevation gain, produce a speed spike, or trigger a false route extension. The last accepted coordinate and metrics remain stable until a later sample passes the quality boundary.

An accepted segment uses the distance between accepted coordinates and the forward timestamp interval. Distance is accumulated from accepted segments, not from map panning, route snapping, provider routing, tile availability, screen pixels, or simulated values. The full private route remains available to persistence even when a public display later hides endpoints.

Balanced GPS quality favors dependable samples and reasonable power use. Precise favors tighter acquisition and more demanding sample quality. Either preference still rejects invalid data. Changing quality affects future acceptance and safe current-session behavior; it never rewrites already accepted route points or retroactively changes distance.

Raw accepted samples and derived summaries have separate meaning: the raw route remains the durable source, while displayed speed, pace, and summaries are derived from accepted data and the selected units.

## Offline Metrics and Unit Conversion

Speed and distance remain functional with no internet connection. The map is a presentation layer and is never a prerequisite for movement telemetry. Traffic, routing, satellite layers, transit, weather refresh, and tile downloads may be unavailable without changing the recording engine’s accepted movement behavior.

The durable measurement basis is metric/SI so activity data is stable across preference changes:

- Route and distance are stored from accepted physical movement in metres.
- Sensor and sample calculations use their native physical units.
- Time is stored with sufficient precision for elapsed and moving summaries.
- Elevation values and accumulated gain retain the accepted physical altitude basis.
- Display formatting converts the same canonical values without mutating the activity.

Metric presentation uses kilometres, kilometres per hour, metres, and pace per kilometre. Imperial presentation uses miles, miles per hour, feet for elevation display, and pace per mile. Conversion happens at the display boundary; changing Metric/Imperial never re-records, rounds, or changes the underlying route or summaries. Units apply to live metrics, Finish, Library detail, accessibility values, and export presentation where the format supports it.

The live pane shows elapsed time, current speed, total distance, selected units, recording/paused status, Music, Finish, Stop/Resume, and the intentionally unfinished heart control. Numeric updates are restrained and do not replace the route pine. A paused session reports zero current speed while preserving the accumulated distance and time values.

Speed smoothing is a persisted preference for the displayed current speed. It reduces GPS jitter while remaining responsive to acceleration and stopping; it does not alter accepted route points, canonical distance, maximum-speed evidence, or the three-metre decision. A change to smoothing affects subsequent display updates and does not rewrite prior metrics.

Pace is unavailable rather than fabricated when accepted distance is insufficient for a meaningful value. The same real finalized session values feed the compact and expanded Finish layouts.

## Manual Pause, Auto Pause, and Resume Precedence

Manual and automatic pause are separate causes attached to the same session. Both preserve activity identity, accepted samples, route, distance, elevation, Music history, title draft, and pine state.

### Manual Stop/Pause

The live Stop control is reversible:

- The first tap pauses the same workout session, freezes active movement collection, brings current speed to zero, and shows a clear Stopped status.
- The control changes to Resume.
- Resume explicitly continues the same elapsed, moving-time, distance, route, elevation, and state. It never resets counters or starts a new activity.
- Manual pause does not silently resume because a new location sample appears.
- If manual pause is active, the user’s explicit Resume is required before recording may continue.

The workout Stop/Resume control is unrelated to music playback. It never pauses, stops, removes, or recreates the compact player.

### Auto Pause

Auto Pause is a persisted setting and is configurable independently of manual Stop. When enabled, the engine uses the established twenty-second stationary rule: after roughly twenty seconds without accepted movement, it enters automatic pause. The stationary decision uses accepted movement quality, not a map animation or a single noisy speed value.

Automatic resume requires movement confirmation from accepted samples. A stray low-quality or implausible sample cannot resume the session. When Auto Pause is disabled, stationary periods do not automatically change the recording state.

### Precedence

Manual pause always takes precedence over automatic resume. Once the user has pressed Stop, incoming movement cannot resume the workout until Resume is explicitly pressed. When no manual pause is active, an automatically paused session may resume only after the accepted movement confirmation. A manual Resume clears the pause condition and returns the session to recording if authorization and usable location are available.

Pause intervals, their cause, and the resulting elapsed and moving-time behavior are durable. A pine resize, Music focus, background transition, or temporary sensor outage cannot be mistaken for a user pause.

## Background, Screen Lock, and Keep Awake

An active session continues under the platform’s approved background location-session rules and the app’s existing background location configuration. It remains the same session while the user backgrounds the app, locks the screen, opens another app, or returns to F28. Accepted samples continue when the platform delivers them and are durably appended.

Keep Screen Awake is a display preference only:

- When enabled, the active route surface may prevent display idle during the workout.
- When disabled, recording continues through normal screen dimming and screen lock policy.
- The setting does not change Core Location ownership, background execution, authorization, pause precedence, or persistence.

When the app is interrupted, backgrounded, suspended, or terminated, the latest accepted raw track, manifest, metrics, pause state, type, and recording state are checkpointed through the file-backed single-writer boundary. Recovery reopens the existing identity rather than starting a replacement activity. A temporary loss of map renderer, map provider, weather, traffic, or offline pack never stops accepted movement collection.

## Elevation Pipeline

Hybrid is the default elevation source. It combines two real on-device signals without making the map renderer responsible for workout totals:

- Quality-filtered `CLLocation` absolute altitude and vertical accuracy provide trusted altitude anchors.
- Core Motion barometric relative altitude supplies smoother short-term climb and descent changes where the device supports it.
- Barometric drift is periodically re-anchored against the latest accepted absolute altitude when one exists.
- The Hybrid stream filters noisy reversals and ignores vertical changes below the selected quality threshold instead of summing every oscillation.
- Highest elevation comes from accepted absolute altitude, not an unbounded barometric drift.

The user may select:

- **Hybrid** — the default and recommended source.
- **GPS** — filtered Core Location absolute altitude without barometric contribution.
- **Barometer** — relative barometric movement anchored to the latest accepted absolute altitude when available. If no anchor exists, the product reports the limitation honestly rather than inventing an absolute elevation.

If barometer data disappears during Hybrid or Barometer recording, the engine degrades to quality-filtered GPS elevation when available and retains the activity. If the device has no barometer, GPS elevation remains the fallback. Loss of elevation input never deletes the accepted route, distance, time, or workout identity.

Elevation processing works offline. Downloaded terrain or DEM data may enrich a map profile or context through F28-D, but it is not required for live elevation totals and does not blindly replace sensor telemetry. Total gain, descent, and highest elevation are derived from the accepted sensor pipeline and persist with the activity.

## Three-Metre Rule and Ownership Boundary

F28-C owns the authoritative accepted-movement threshold. The decision uses accepted Core Location/GNSS distance, after invalid, inaccurate, duplicate, reversed, implausible, and below-threshold samples have been excluded. Map movement and screen pixels never count.

When Finish is requested:

- F28-C stops live collection long enough to evaluate the finalized accepted movement total.
- If valid accepted movement is less than three metres, the session is discarded immediately rather than becoming a result or Library activity.
- No Finish details, Establish chooser, public metadata, or Library record is created for that short session.
- The same route pine returns to Start and the feature reports a concise reason such as “Workout not saved — less than 3 m recorded.”
- At three metres or more, F28-C exposes a valid finalized session to F28-F. F28-F owns the summary, Establish, and later persistence presentation, but it cannot override the three-metre predicate.

This boundary is intentionally owned by the recording engine so every caller uses the same accepted-distance definition.

## Finish, Resume, and State Continuity

Finish is an engine state transition, not navigation. It stops live sample collection while retaining the current session identity and all accepted data. F28-B keeps the same main pine position and geometry; F28-F binds the finalized model to the in-place summary.

A valid finalized session remains resumable until the user establishes it, discards it, or completes the product’s final persistence action. Resume returns to the same live workout with:

- Every accepted raw point and accumulated distance.
- Elapsed and moving time and pause intervals.
- Elevation gain, highest elevation, and highest speed accumulated before Finish.
- Committed activity type and planned-route identity.
- Music playback history and title draft through their owning domains.
- Map camera, route presentation, pane focus, and unfinished UI state.

Resuming never creates a second activity or starts counters at zero. Establishing or deleting follows F28-F’s product flow; the engine supplies the same finalized model and does not fabricate a new route.

## Interruption Recovery

Recovery is an identity-preserving reopen of an unfinished activity, not an import into a new recorder.

A durable unfinished manifest and raw track retain:

- Stable activity identifier and Run, Walk, Bike, or legacy Run & Walk type.
- Recording, manually paused, automatically paused, finished-but-unestablished, or otherwise recoverable state.
- All accepted route points and the latest accepted coordinate.
- Elapsed time, moving time, distance, speed summaries, pause intervals, and elevation state.
- Planned-route reference and existing title/session fields.
- The latest safe quality, smoothing, unit, and elevation-source context needed to display the session honestly.

Opening recovery restores the existing recorder owner, route, pause cause, metrics, and type. It does not infer new movement from time elapsed while the app was unavailable, and it does not append a duplicate point merely because the same manifest is opened twice. If the last sample is incomplete, recovery keeps the last complete accepted checkpoint and waits for a new valid sample.

New optional fields decode safely when absent. Historical sessions do not receive fabricated played-track or elevation data. Recovery remains available after a visual route-feature interruption and returns to the same full-screen map composition.

## Errors and Degraded States

| Condition | Recording-engine behavior | Product presentation |
|---|---|---|
| Location not determined before Start | No location request merely for opening F28; Start remains available | Start is unchanged until the user begins recording |
| Permission denied or restricted | No session with fake movement; no accepted route | Concise in-pine explanation and an appropriate Settings recovery path |
| Waiting for first fix | Session reports acquisition state and accepts nothing until a valid sample arrives | Existing zero metrics remain honest; no placeholder route |
| Temporary GPS unavailable | Keep accepted route and metrics; wait for the next acceptable sample | Degraded status without resetting or ending the activity |
| Invalid or low-quality sample | Reject it from route, distance, speed, moving time, and elevation | Prior accepted values remain stable |
| Offline | Continue accepted GPS metrics and local elevation; network-only map/weather layers may be cached or unavailable | Recording continues without claiming network data |
| Barometer unavailable or lost | Use filtered GPS elevation where available; preserve existing totals | Elevation source degrades honestly without losing the activity |
| Screen locked or app backgrounded | Continue under active location-session rules and durable checkpoints | Keep Awake affects only display idling |
| Process or app interruption | Preserve latest durable state and expose recovery | Reopen restores the same session identity |
| Finish below three metres | Discard immediately; never create result or Establish | Return to Start with a concise short-session reason |
| Finish at or above three metres | Freeze live collection and expose a finalized session | F28-F presents the same-pine Finish state |

No provider failure, map-layer error, WeatherKit outage, missing tile, music availability state, or pane transition is converted into a recording error unless it actually affects the native location/elevation session.

## Persistence Invariants

- Accepted raw points are authoritative private route data and are appended durably; route snapshots or map thumbnails never replace them.
- Distance is derived from accepted points and remains independent of map provider, route snapping, traffic, routing, and network state.
- Elapsed time, moving time, pause intervals, accepted distance, speed summaries, elevation summaries, type, and session state are internally consistent across restart and recovery.
- Manual pause cannot be auto-resumed by an incoming sample. Automatic pause cannot erase accepted data or change into manual pause without a user action.
- Changing units changes display only. Changing smoothing changes future display filtering only. Changing GPS quality changes future acceptance policy only. None of these preferences rewrites prior raw points or derived history.
- Changing elevation source affects subsequent elevation processing only; it does not erase accepted route, distance, time, or earlier elevation values. Barometer loss degrades safely.
- The three-metre boundary always uses accepted movement and is evaluated before a Finish result can exist.
- Finish stops collection before a valid finalized model is handed to F28-F. Resume reuses the same identity and data.
- A visual pine change never resets the engine. Main/sibling detents, MAX, quick panes, Music focus, map modes, camera changes, and screen lock preserve the workout.
- Reopening recovery is idempotent. It does not duplicate activities, regenerate identifiers, duplicate accepted points, or silently reset pause/type/route state.
- Existing legacy Run & Walk identity remains decodable and visible. New records never inherit legacy type merely because an old session was recovered.
- Backup/import preserves the expanded recording manifest, raw track, planned-route references, and recording settings through the F09 data boundary while retaining duplicate-skip behavior.

## Preferences and Service Boundaries

The following are durable route-recording preferences, presented by F28-G and consumed here:

- Metric or Imperial units.
- Auto Pause enabled or disabled.
- Keep Screen Awake enabled or disabled.
- Balanced or Precise GPS quality.
- Hybrid, GPS, or Barometer elevation source.
- Restrained speed smoothing.

Preference changes apply to the current session only where safe and to future sessions durably. They never change accepted historical samples. Audio cues, haptics, privacy, WeatherKit display, export format, and Music playback are neighboring domains; this engine emits the real workout events those domains consume without inventing their UI or storage.

## Dependencies and Conceptual Sibling Links

- **F28-B Route Pine System** — Start-to-live and live-to-Finish morphing, main/sibling detents, map-backed presentation, status labels, accessibility focus, and no-navigation continuity.
- **F28-D Map Platform** — permanent map instance, camera, route overlay, map modes, terrain/DEM context, offline-region state, and provider degradation. The engine does not depend on its tiles or renderer for metrics.
- **F28-E Music Workout Editor** — real playback, track-change events, compact player, and played-track history. Workout Stop/Resume remains independent of playback.
- **F28-F Finish, Establish, and Library** — finalized summary, Resume action, Establish, local Public Profile metadata, Library persistence, export, and deletion safety.
- **F28-G Settings, Privacy, and Recovery** — persisted recording preferences, recovery entry, migration defaults, and unusual-state messaging.
- **F09** — file-backed single-writer persistence and backup/import invariants.
- Apple Core Location/GNSS — authorization, background location, accepted coordinates, timestamps, speed, altitude, and accuracy.
- Apple Core Motion — barometric relative altitude where supported and device-motion context where appropriate.

## Files and Reference

- `TimeMasterCore/Sources/Models/OutdoorActivityManifest.swift` — durable activity identity, recording state, type, metrics, pause, elevation, route, and recovery fields.
- `TimeMasterCore/Sources/DatabaseManager.swift` — single-writer activity, raw-track, checkpoint, and migration persistence.
- `TimeMaster/Models/OutdoorActivity.swift` — iOS-facing Run, Walk, Bike, and legacy Run & Walk compatibility.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` — active-session ownership, recovery, finalization handoff, and Library integration.
- `TimeMaster/Services/Outdoor/` — location authorization, accepted-sample filtering, metrics, pause policy, elevation, background operation, and recovery services.
- `TimeMaster/Views/Outdoor/` — live metric and status consumers inside the route pine.
- `features/F28-better-maps-recording/tmux_route_recording_prototype (1).html` — authoritative Start-to-live, Stop/Resume, Finish, three-metre, metric, offline, elevation, and interruption reference. Its changing values and route are presentation scaffolding only.
- `features/F28-better-maps-recording/DOCKS.md` — parent product decisions, including 200-metre default endpoint privacy and migration context.
- `features/F28-better-maps-recording/RF28-A-outdoor-remake-migration/DOCKS.md` — existing recorder behavior, migration constraints, and F28 child ownership.
