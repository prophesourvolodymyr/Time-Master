# RF28-A — Outdoor Remake Migration

RF28-A is the documented bridge from the existing Cycle 11 outdoor implementation to the complete F28 iPhone route-recording replacement. It preserves valuable local recording data and proven services while removing every old outdoor interaction surface from the active application.

## Why This Revolution Exists

The current app has a working local GPS recorder and file-backed route history, but its interaction model is a stopped map entry followed by a separate recorder card and a separate result sheet. It does not match the approved permanent-map, morphing-pine workflow.

The map can render a route and download a fixed current-area pack, but it does not own a provider-neutral layer model for terrain, satellite, 3D, transit, traffic, cycling, dark, and direction presentations.

The current model combines Run and Walk, lacks local publication metadata, has no played-track history, has no quality-filtered elevation totals, and cannot represent the new Library detail state.

The current Music Settings library and local player are separate from outdoor recording. They do not record per-route playback history or provide the exact in-route editing and sibling-pine behavior.

The old unfinished-activity recovery path exposes recoverable manifests, but reopening from Home can create a new recorder rather than reliably restoring the previous in-memory recording owner and pause state.

## Problems Reported by the User

- The cycling, running, and walking workflow needs a complete remake rather than a visual patch.
- Every existing outdoor UI must be removed from the active product.
- The map must be improved according to every product comment in the authoritative HTML.
- The HTML logic must be implemented in native Swift rather than treated as a mood board.
- The interface must use morphing Liquid Glass bases, animated icons, continuous native motion, and a frosted map-backed composition.
- The work is iPhone-only; macOS route UI comes later.
- The new workflow must be fully connected to real recording, map, persistence, music, Profile, export, and recovery behavior.

## Problems Discovered During Audit

- The existing activity taxonomy has only Run & Walk and Bike.
- Planned route creation is not connected to a real GPX import or route-authoring UI.
- The current route picker’s GPX action is a stub.
- Planned-route persistence exists, but normal product flows do not create or delete those records.
- The existing recorder’s visible Resume action does not correctly handle a manually requested resume from the automatic-pause state.
- Auto-pause behavior is fixed in recorder logic and is not controlled by persisted settings.
- Unfinished manifests reload into the store but are not reliably restored as the active recorder session.
- Finishing can save activities below the approved three-metre accepted-movement threshold.
- Elevation samples are stored, but elevation gain, highest elevation, barometer fusion, and noise rejection are absent.
- MapLibre is coupled directly to one remote OpenFreeMap style and has no app-owned map-mode or provider abstraction.
- The current offline manager downloads one hard-coded area around the current location and lacks the approved geographic-selection contract, installed-region lifecycle, cancellation, storage accounting, and provider-rights validation.
- Route snapping is duplicated in the app and core, and the app copy performs avoidable repeated length calculation.
- There is no WeatherKit service or weather cache.
- There are no persisted route units, GPS quality, elevation source, smoothing, auto-pause, keep-awake, weather, privacy, haptics, cue, or export preferences.
- The current summary and detail views are separate sheets rather than states of the recording pine.
- Public/Private, star, tags, comments permission, hidden endpoints, public metadata retention, local Profile publication, and played-track history do not exist in the activity manifest.
- Export supports GPX and CSV, while the approved route workflow requires GPX and FIT.
- The current backup contains activity manifests and raw tracks but does not preserve every planned route and does not know the new route metadata.
- The existing Music Settings store and player are not shared as one long-lived dependency with route recording.
- Music destination memberships can retain stale workout/type keys.
- Deleting a Music library item does not consistently remove an unreferenced local file.
- Music playback queue, current item, and route-session play events are transient and cannot populate historical route details.
- Existing provider adapters do not authenticate, search, import, or play remote provider items.
- The authoritative F28 folder originally had no DOCKS file, no feature index entry, and no CYCLES implementation plan.

## Old Implementation Being Replaced

The old implementation was recorded in Cycle 11 rather than a numbered feature folder. Its active interface consists of:

- A route recorder sheet.
- A card-like live recording overlay.
- A route picker with an unfinished GPX action.
- A separate post-finish summary sheet.
- Separate History and Profile activity detail sheets.
- A separate fixed-current-area offline-map Settings screen.

Its durable data consists of one activity manifest and one line-oriented raw track file per activity, plus separately persisted planned routes.

## Old Structure Preserved

- Cycle 11 remains historical documentation of the first implementation.
- A remote preservation branch captures the complete pre-F28 source state before active files are removed.
- Existing activity identifiers remain stable.
- Existing raw tracks remain authoritative private route data.
- Existing titles, timestamps, elapsed and moving time, distance, average and maximum speed, targets, pause intervals, laps, recording state, and planned-route references remain intact.
- Existing GPX behavior remains available through the new export flow.
- Existing valid location-sample filtering, file-backed append behavior, background location configuration, and recovery files are reused and corrected.
- Existing MapLibre rendering and offline-pack logic remain implementation inputs behind the new provider-owned map and offline boundaries.
- Existing Music Settings models, membership ordering, local import, local playback, artwork, and collections remain the one music data source.
- Profile, History, Analytics, Home, Workout, Backup, and Settings continue to consume outdoor data through updated integration points.

## Active Behavior Removed

- The old recorder sheet composition.
- The old recorder control card.
- The old route picker UI.
- The GPX stub action.
- The separate result sheet.
- The old Profile and History route-detail sheet.
- The old fixed current-area offline-map settings interface.
- Any navigation path that turns a route workflow state into a new page or result modal.
- Any hard-coded placeholder activity, map route, weather value, music row, or Library record.

Removing these from active source does not delete existing user activities or their raw tracks.

## New Structure

- **F28-B Route Pine System** owns permanent-map composition, main and sibling pine geometry, detents, MAX, dismissal, cross-version glass, Start, and accessibility.
- **F28-C Recording Engine** owns accepted movement, Run/Walk/Bike types, offline metrics, pause/resume, elevation, background behavior, three-metre validation, and recovery.
- **F28-D Map Platform** owns provider-normalized modes, route overlays, camera/follow state, weather placement, offline capabilities, and the deferred geographic-selection contract.
- **F28-E Music Workout Editor** owns the route presentation of the shared Music library, real playback, temporary imports, drag intent, player pine, and per-route track history.
- **F28-F Finish, Establish, and Library** owns result morphing, resume, local publication, Profile visibility, Library filtering, Starred, details, privacy, export, and deletion.
- **F28-G Settings, Privacy, and Recovery** owns persisted quick settings, endpoint hiding, WeatherKit preferences, recovery entry, backup, migration defaults, and unusual states.

## Data Migration

Every existing finished activity is treated as already established and migrates into the new Library with these defaults:

- Visibility is Private.
- Star is off.
- Existing title and summary values are retained.
- Description and tags are empty.
- Comments preference uses the current default but has no historical comments.
- Hidden endpoints use the current default preference, with 200 metres as the initial default.
- Played-track history is empty because historical playback cannot be reconstructed honestly.
- Existing full raw route remains private and unchanged.
- Public metadata retention begins false until the user first saves Public metadata.
- Existing Run & Walk remains the legacy type.

Existing unfinished activities remain unfinished and recoverable. They are not marked established by migration.

New Run, Walk, and Bike records use distinct stored types. The preserved legacy Run & Walk value remains decodable and visible without becoming a choice for a new recording.

Migration is idempotent. Reopening the app cannot duplicate activities, regenerate identifiers, or repeatedly reset visibility and metadata.

## Profile and Publication Migration

No existing activity appears as a Profile post after migration because every migrated activity begins Private. The user may publish one by changing it to Public in the F28 Library detail.

Public publication remains local. Profile reads the Public subset of the same established activity store. A future social publication service receives stable activity identity and durable metadata but is not simulated in this feature.

Profile aggregates may continue to use all local activity data. Profile route cards use Public activities only.

## Map Migration

The existing MapLibre view is replaced by one long-lived map host. Existing route points and planned-route overlays keep their identities while the map host gains app-owned mode and provider state.

The remote Liberty style ceases to be the product’s only implicit map dependency. Every mode declares its source capabilities, attribution, network requirements, cache rights, and failure behavior.

Changing modes never rebuilds the route session or loses camera state. Unsupported offline layers degrade without invalidating an installed vector region or interrupting recording.

The old fixed-area offline UI is removed. Existing installed packs remain discoverable by the new offline service. The future direct-manipulation selection interface remains deferred because its final visible controls were intentionally not defined in the authoritative specification.

## Music Migration

The route editor shares the existing Music Settings catalog and memberships. It does not copy library data into the activity store.

Run, Bike, Walk, and More route sections gain stable shared destination identities. Existing valid Music memberships remain ordered. Orphaned destination keys and stale memberships are cleaned without deleting referenced audio.

Legacy local Music files and provider-neutral items retain stable references. Route activities store only the durable playback references and display metadata necessary to render their played-track history.

Temporary cross-section imports live only for the route session and never appear as a permanent Music Settings mutation.

## Backup Migration

Backup includes:

- Expanded activity manifests.
- Raw track files.
- Planned route records.
- Public/private metadata and retention state.
- Tags and privacy distance.
- Played-track references and artwork references where portable.
- Route recording preferences.
- Offline region metadata that is safe to restore, without pretending provider-protected tile data can always be copied.

Import preserves duplicate skipping and never overwrites an existing activity merely because its new optional fields differ.

## Migration Order

1. Preserve the pre-F28 implementation on a remote branch.
2. Add the F28 product and migration documentation and register the feature in the project plan.
3. Expand backward-compatible core types, schemas, exports, and migration behavior.
4. Repair recorder recovery and add accepted-movement, preferences, and elevation behavior.
5. Establish map provider, weather, camera, offline, and overlay boundaries.
6. Establish the shared Music route-session and playback-history boundaries.
7. Build the permanent map and reusable pine system.
8. Connect Start, live recording, sibling features, Finish, Establish, Library, and details.
9. Replace all old app entry points and detail flows.
10. Extend backup/import and remove obsolete active UI source.
11. Exercise the complete iPhone flow and correct behavior or geometry mismatches.
12. Hand every implemented F28 child to the human for verification.

## Affected Files

The migration affects the outdoor models, core manifests, database manager, schema manager, migration manager, recorder, metrics, map, offline, weather, export, backup, Music library/store/player, full-screen app presentation, Home and Workout entry points, History, Profile, Analytics, Settings, project configuration, entitlements, tests, feature documentation, and cycle dashboard.

The authoritative HTML remains unchanged unless the user explicitly revises the product specification.

## Dependencies

- F09 file-backed data remains the persistence foundation and must retain single-writer behavior.
- F24 slot navigation remains outside the full-screen route feature.
- F25 Music remains the single music library and playback domain.
- F26 defines the approved iOS 16 through iOS 26 glass policy.
- F27 supplies the Home route entry points.
- Apple WeatherKit capability must be enabled for live weather responses.
- Production map providers must supply the approved data, attribution, licensing, and offline rights for provider-backed modes.

## Final Desired Behavior

A user can open one full-screen map, choose Run, Walk, or Bike, optionally prepare music, start recording, move between every defined pine state without navigation, pause and resume, use the map and music concurrently, finish, inspect real statistics, resume an accidental finish, establish the workout as Private or locally Public, find it in the same-pine Library, publish or hide it from Profile without losing metadata, export it, recover it after interruption, and delete it only through the approved safety interaction.

The map, route session, music, and persistent identity remain continuous throughout. No prototype data, disconnected screen, fake backend, or obsolete outdoor UI remains active.
