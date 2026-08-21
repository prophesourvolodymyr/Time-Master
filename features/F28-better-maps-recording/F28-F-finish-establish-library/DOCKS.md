# F28-F — Finish, Establish, and Library

F28-F owns the post-workout life of a real route: the in-place Finish result, resume, Establish visibility and metadata, the local Profile publication boundary, and the established-workout Library. It keeps the route feature on the permanent map and uses the existing main route pine rather than presenting a result page, navigation destination, or modal result sheet.

F28-F consumes the accepted workout and finalized track history from the recording and Music siblings. It owns the resulting activity identity, visibility metadata, Library queries, detail mutations, export/share decisions, and deletion safety. The route recorder, map renderer, Music Settings catalog, and quick preference surfaces remain sibling ownership; this document links to them without recreating their detailed behavior.

## What We Build

- A same-pine Finish morph from live workout to the real finalized-workout result.
- A real short-session boundary: accepted movement below three metres is discarded and never becomes a result or Library activity.
- Real distance, elapsed time, elevation gain, highest elevation, highest speed, average pace, workout title, type, route, and played-track history.
- Resume from an accidental Finish without losing the active route session or its draft metadata.
- An in-place Public/Private Establish chooser with reusable tags, description, endpoint privacy, comments preference, and player-track visibility.
- Local Public publication into the user’s Profile, with Private activities remaining in the local Library but absent from Profile posts.
- Retained public metadata when visibility changes from Public to Private and back again.
- A same-pine Library with an unfiltered Starred carousel, filtered and sorted activity grid, real route thumbnails, and stored type badges.
- A same-pine detail editor for title, star, visibility, description, tags, public preferences, played-track history, sharing/export, and deletion.
- Functional GPX and FIT sharing/export with privacy-aware route copies and durable private source data.
- Normal confirmation deletion and significant-route continuous destructive hold.
- Migration of existing activities into the new Library without changing route identity or legacy Run & Walk type.
- Empty, filtered-empty, unavailable, failed-load, failed-save, failed-export, and canceled-destructive-action states that do not fabricate success or data.

## Architecture

The Finish state is another content state of the long-lived main route pine. It receives one finalized workout model containing the stable activity identity, accepted raw route, summary metrics, saved title, stored workout type, pause/time information, elevation values, privacy metadata, star state, and ordered Music playback references. The Finish surface does not calculate a second summary from map pixels, placeholder values, or a separate temporary record.

Establish persists the finalized activity before the route feature returns to Start. Public fields are local publication metadata in this version. The local Profile reads the Public subset of the same established activity store; it does not receive a copied social record. Allow Comments is retained as a future social preference and does not claim that remote comments or delivery exist.

The Library grid and Starred carousel derive views from the canonical established-activity collection. They never duplicate records to implement filtering or sorting. A card and its detail editor retain the same stable activity identity, raw private route, played-track references, and metadata across every visibility, star, title, and public-preference edit.

The visibility boundary is reversible. Public-to-Private removes the activity from local Profile posts immediately while retaining the description, reusable tags, comments preference, endpoint-privacy preference, player-track visibility preference, and any other saved public metadata. Private-to-Public restores those retained values unless the user edited them while private. Migration starts retention false for activities that have never had Public metadata; it becomes true when Public metadata is first saved.

The detailed route-card rendering uses the real recorded route/polyline or a cached snapshot produced by the map system. The type badge uses the stored activity type and its matching native/system symbol. It never infers type from title, distance, pace, or route shape.

## Same-Pine Finish Presentation

Finish stops live collection and morphs the current main route pine in place at its current height, position, map camera, and exposed-map relationship. The permanent map remains behind the same pine. The route handle remains the one resize gesture; no second Finish handle or result-sheet drag is introduced.
On iOS 26 and later this same pine uses native Apple Liquid Glass. On iOS 16 through iOS 25 it uses the existing private renderer with the same geometry, clipping, motion, and accessibility behavior; reduced transparency uses the approved readable fallback rather than a second design.

At the compact result composition, the pine shows an editable workout title, primary distance and units, compact elevation gain, highest speed, pace, played-track summary, and Establish, Share, Resume, and Delete actions. A restrained More Info pill communicates that the same pine can reveal more information. As the user grows the pine through compact, medium, and normal full-height compositions, the title and primary distance reflow and the elapsed time, elevation gain, highest elevation, highest speed, average pace, and played-track artwork stack progressively appear. At normal full height the complete result information is available without leaving the pine.

The result values are real finalized values and observe the route’s unit preference. The played-track stack uses the real artwork references and ordered history from the active route session. A missing artwork reference is shown as unavailable while the track identity and count remain accurate. The route preview, when present in the result composition, comes from the finalized route or map snapshot rather than the HTML scaffold.

The current result height is preserved when Finish occurs. Finish does not jump to a default detent, recreate the map, reset the workout type, or discard the title draft. If the result remains unfinished, reopening the route feature restores the same unestablished activity and result state through the recovery boundary.

## Finish and Establish States

| State | Visible result and behavior |
|---|---|
| Live workout | Recording owns the route and metrics. Finish is available in the live pine and opens the same-pine result only after the accepted-movement rule is evaluated. |
| Short Finish, under 3 m | The activity is discarded immediately, no result or Establish is shown, the same route pine returns to Start, and a concise in-pine reason explains that less than three metres was recorded. No Library activity is created. |
| Compact Finish result | Real title, distance, compact statistics, played-track summary, More Info cue, Establish, Share, Resume, and Delete are visible. |
| Expanded Finish result | The same pine reveals elapsed time, complete elevation and speed statistics, average pace, route/media context, and real played-track artwork/history. |
| Establish unopened | The result remains resumable and deletable. No visibility is committed until the user chooses Public or Private. |
| Establish chooser | An in-place chooser owned by the Finish pine offers Public and Private. Establish is unavailable until one choice is selected. Closing it returns to the unchanged result height and data. |
| Private Establish | The finalized activity is stored as Private, including the complete private route, then the route feature returns to its original Start state. Public-only fields remain empty unless retained from an earlier publication. |
| Public Establish | Public metadata fields expand in place: description, reusable tags, endpoint privacy distance, comments preference, and player-track visibility. Saving stores the activity and local Profile publication, then returns to Start. |
| Resumed result | Resume returns to the same live route session with accepted samples, elapsed and moving time, pause state, type, title draft, music state/history, and pine state intact. |
| Library open | Start content is replaced by Starred and Library inside the same draggable route pine. The map remains behind it. |
| Library detail open | A selected card replaces the Library grid inside that pine. Detail back returns to the grid; it is not a pushed page. |
| Delete confirmation | The confirmation appears before any finalized activity is removed. A significant activity adds continuous hold progress; cancellation leaves the activity unchanged. |

## Establish and Reusable Privacy Metadata

The chooser presents Public and Private as explicit mutually exclusive choices. Private can be committed directly. Public reveals the metadata required for local Profile publication:

- An editable description.
- Reusable user-created tags, including recent tags offered for quick selection and the ability to create a new tag during Establish. A selected tag remains a reusable tag for later activities rather than a one-off label.
- Hide Start & Finish, with 100 metres, 200 metres, or 500 metres. The default is 200 metres. The complete private route remains stored locally; endpoint hiding affects the public representation or an explicitly privacy-applied export only.
- Allow Comments, stored as a publication preference for the future social boundary.
- Show Player Tracks, controlling whether played-track information is shown on the public representation while preserving the finalized private history.

The user can edit these fields later in Library detail. Public metadata is retained when the activity is made Private. Making it Public again restores the retained description, tags, endpoint distance, comments preference, and player-track visibility instead of resetting them. A Private activity with no previous Public save has no fabricated public metadata.

Establish saves a real finalized activity with its route, stats, title, type, privacy state, tags, and track history before returning the route pine to Start. The route session does not create a duplicate Library card on repeated app openings or visibility edits.

## Local Profile Publication

A Public established activity appears in the user’s local Profile route feed. A Private activity remains searchable in the route Library and is omitted from Profile posts. Changing visibility updates that subset immediately and durably while retaining one stable activity identity.

When no activity is Public, the Profile route area shows its real empty state while local aggregates and the Private Library remain available. A Profile read or publication failure reports an in-pine/unavailable state without changing Library visibility or activity identity.
Profile publication is local in this release. No social account, remote feed, comments delivery, remote likes, or server success is represented by the route UI. The Allow Comments preference is retained for a future publication service. Profile aggregates may continue to use complete local activity history, while Profile route cards use Public activities only.

Privacy-applied public geometry is a representation of the complete private route. The private raw track and original endpoint coordinates remain unchanged, and a later Private transition never destroys them. A public activity may be exported with its selected endpoint hiding without rewriting its stored private route.

## Library Presentation and Query States

The Library control beside Start replaces the Start and mode content inside the same route pine. The Library header has an exit arrow that leaves the full-screen route feature and returns to the app surface that launched it. The detail back control returns only to the Library grid and preserves the current Library query context.

Starred is a horizontal route-card carousel sourced from every starred established activity. It is independent of the Library grid’s type filter and sort order, so filtering or sorting the grid never removes, reorders, or narrows Starred. A user can star or unstar an activity from detail and the carousel updates from the canonical store.

The Library grid supports these stored type filters:

- All Types.
- Run.
- Bike.
- Walk.
- Legacy Run & Walk, when migrated records of that preserved type exist.

The grid supports Recent, Oldest, Distance, and Name ordering. Recent and Oldest use the persisted save date; Distance uses the stored distance; Name uses the stored title. The controls are independent, and changing one does not reset the other. The grid does not infer a missing type from route geometry or speed.

Each route card shows:

- The real recorded route geometry or a cached map snapshot.
- The stored activity name and distance.
- A circular type badge with the matching native/system Run, Bike, Walk, or legacy Run & Walk symbol.
- The same stable activity identity used by detail and Profile.

The card is a real route record, not a decorative line. Selecting it morphs to detail in the same pine and keeps route Library data authoritative.

## Library and Detail States

| State | Visible result and behavior |
|---|---|
| Empty Library | A calm empty Library state appears without fabricated route cards; the route Start composition remains reachable. |
| Empty Starred | Starred reports that no activities are starred while the Library grid remains independent. |
| Filtered empty | The selected type/filter combination reports that no activities match. Starred is unchanged. |
| Sorted Library | Cards reflect the selected persisted sort without duplicating or mutating activities. |
| Detail viewing | Real title, visibility, type badge/context, distance, elapsed time, elevation gain, highest elevation, highest speed, average pace, description, tags, public preferences, played-track history, Share/Export, star, and Delete are available according to the activity state. |
| Detail editing | Title, description, tags, star, visibility, endpoint distance, comments, and player-track preference edits are bound to the selected activity and saved through the Library store. Statistics and route geometry remain real recorded values. |
| Private detail | Private visibility is explicit. Public metadata controls remain available for retained fields and do not imply Profile publication. |
| Public detail | Public visibility and retained publication fields are shown. Profile inclusion follows the stored Public state. |
| Played-track history | Real artwork stack and track count/history appear when available. No historical tracks are invented for migrated activities. |
| Missing or deleted detail | If a selected identity is unavailable, the Library reports that the activity can no longer be opened and returns to a valid Library state without showing stale fabricated values. |
| Library load/save failure | The in-pine error identifies the unavailable operation, keeps the last known activity state, and does not claim that an edit or visibility change was persisted. |

The detail editor supports title changes, description changes, reusable tag selection or creation, star state, visibility, privacy metadata, comments preference, player-track preference, Share/Export, and Delete. It preserves the same route geometry and activity identity while editing. Tapping a card, editing a field, changing visibility, or returning to the grid never creates a second detail page.

## Sharing and Export

Share/Export uses the system share surface and produces functional GPX or FIT output. The selected export format comes from the route preference or the explicit export choice, while both formats remain supported. Export includes the real route and finalized activity fields required by that format.

Private sharing uses the complete private route unless the user explicitly requests a privacy-applied copy. Public/Profile sharing applies the selected endpoint hiding to the shared representation while leaving the stored private route unchanged. The privacy distance is exactly the selected 100, 200, or 500 metres.

A failed export, unsupported destination, unavailable share surface, or serialization error remains inside the Finish or detail pine with an actionable failure state. It does not change visibility, Profile publication, Library identity, track history, or established status. A canceled system share returns to the same content without mutation.

## Deletion Safety and Recovery

Every finalized-activity delete begins with an explicit confirmation. Normal activities can be deleted through the confirmation action. An activity lasting at least 60 minutes or covering at least 20 kilometres is significant and requires a continuous 1.2-second destructive hold after the confirmation appears. The hold shows progress and completes only while the contact remains on the destructive control; lifting, leaving, canceling, or losing the hold before 1.2 seconds cancels progress and preserves the activity.

Deletion applies to the real Library record and its route data through the persistence boundary only after confirmation succeeds. A successful Finish-result deletion returns the route feature to Start. A Library-detail deletion returns to the Library grid and removes the card from both the grid and Starred. A persistence failure leaves the activity and its metadata intact and reports the failure in place.

Resume is the reversible path for an accidental Finish. It does not create a new activity, reset accepted distance, or clear the title, route, elevation, playback history, pause state, or selected workout type. A short session below three metres is different: it is immediately discarded by the Finish movement rule, shows a concise reason, creates no result, and offers no Establish or finalized-workout delete flow.

If the app is interrupted while a workout is active, paused, finished but not established, or recoverable, reopening the route feature restores the existing activity identity and the applicable result/live state. F28-G owns recovery entry and persistence mechanics; F28-F owns restoring the same Finish/Resume/Establish meaning without silently establishing, duplicating, or deleting the activity.

## Migration

Existing finished outdoor activities enter the Library as Private, unstarred established records with stable identifiers. Their existing titles, timestamps, elapsed and moving time, distance, pauses, laps, planned-route references, raw route points, and stored summary values remain authoritative. Their complete raw routes remain private and unchanged.

Migrated records begin with empty description and tags, no fabricated played-track history, and no Public Profile post. The comments preference uses the current default but carries no historical comments. Hide Start & Finish uses the current default with 200 metres as the initial default. Public metadata retention begins false until the user first saves Public metadata. Existing combined Run & Walk records retain their legacy type and explicit legacy badge rather than becoming Run or Walk based on route shape or speed.

Migration is idempotent: reopening the app does not duplicate activities, regenerate identifiers, or repeatedly reset user metadata. Existing unfinished activities remain recoverable and are not marked established by migration; the recovery boundary restores them to the route session instead of creating a new Library activity.

After migration, a user may publish a migrated activity locally by changing it to Public in detail or through the approved Establish path. The first Public save creates the retained metadata boundary; later Private/Public changes preserve the fields described above.

## Geometry and Responsive Behavior

The feature is iPhone-only and remains a full-screen route destination over the permanent map. Finish, Establish, Library, and detail all occupy the existing main route pine’s safe-area-aware frame. Finish preserves the pine’s current bottom anchoring and map camera; its statistics reflow continuously as the pine grows instead of switching to a page.

The More Info cue is a compact pill beneath the Finish content and fades as expanded information becomes visible. Finish actions remain reachable at compact and expanded sizes. Establish content can grow the same pine enough to show the selected visibility fields and then scroll internally when Dynamic Type or narrow height requires it.

Library uses a horizontally scrollable Starred carousel and a scrollable multi-column route grid. Card artwork and type badges remain legible at narrow iPhone widths; titles truncate only within their card copy and never alter route-thumbnail geometry. Detail uses an internally scrolling content area so title, stats, metadata, artwork history, sharing, and deletion remain reachable without moving the map or creating a second surface.

Confirmation, Establish, and filter menus remain attached to the current route context. They do not move the route session to a new navigation layer. Safe-area insets, the home-indicator region, keyboard, and Dynamic Type are accounted for without covering destructive actions or silently changing the activity state.

## Animation Rules

Finish is a restrained same-surface crossfade and reflow from live metrics to finalized result content. The route pine’s stable glass identity and position remain continuous. Title, distance, compact side statistics, pace, expanded time, detail grid, and track artwork interpolate from the current pine expansion fraction. Numeric values change with short rolling transitions only when the real value changes.

The More Info cue appears as a quiet affordance rather than a second handle. Growing and shrinking the pine remains one-to-one during the drag and settles with the shared route spring. Resume morphs the same result back to the live-workout composition without resetting the pine or map.

The Establish chooser reveals from the Finish context with a restrained in-place transition. Public fields expand only when Public is selected; Private does not leave unused content behind. Visibility selection, tag selection, and Establish confirmation use subtle press and state transitions. Returning to Start after a successful Establish is a state morph, not a page transition.

Library and detail content use short opacity/scale transitions anchored to the same pine. Card selection morphs the grid into detail; detail back reverses that relationship. Filter and sort menus use compact attached transitions. Delete confirmation enters with a restrained scale/fade, and significant deletion communicates continuous hold progress without implying completion early. A canceled hold returns to its prior state.

Reduce Motion replaces large morph travel and decorative effects with restrained opacity and content reflow while preserving direct drag tracking, result information, visibility state, deletion progress, and focus changes. Reduced Transparency uses readable opaque surfaces while preserving geometry and hierarchy.

## Accessibility

Every icon-only action has a meaningful label and current state, including Back, Library exit, star, visibility, Delete, and route-type badges. The Finish result exposes title, distance, each statistic, played-track count, Establish, Share/Export, Resume, and Delete as distinct controls. VoiceOver focus follows the same-pine content replacement and does not announce Finish, Establish, Library, or detail as an unrelated new page.

The route pine exposes adjustable accessibility actions for compact, medium, expanded, and normal full-height presentations. Finish’s More Info cue is descriptive rather than the only way to expand; the existing pine adjustment remains available. Public/Private selection, endpoint distance, reusable tags, comments, and player-track preferences expose selected state independently of color.

The three privacy distances are read with their units and selected value. Significant deletion explains that a continuous 1.2-second hold is required and exposes an equivalent accessible confirmation action that cannot complete accidentally through a brief activation. Hold cancellation is announced without deleting. Export format, share failure, empty states, migration legacy type, unavailable Profile publication, and persistence failures are readable status messages.

Dynamic Type allows the Finish result, Establish fields, Library cards, detail statistics, metadata, and confirmation content to reflow and scroll internally. Route geometry and type badges remain supplementary to text labels. Hit targets remain appropriate for iPhone use, and haptics follow the persisted preference without replacing visible or spoken confirmation.

## Files

- `TimeMasterCore/Sources/Models/OutdoorActivityManifest.swift` — durable activity identity, stored metrics, visibility, public metadata, privacy distance, tags, star state, and played-track references.
- `TimeMasterCore/Sources/DatabaseManager.swift` — finalized activity, route, metadata, and deletion persistence.
- `TimeMaster/Models/OutdoorActivity.swift` — iPhone-facing activity and legacy Run & Walk compatibility.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` — Finish finalization, Establish, Profile subset, Library queries, detail edits, deletion, and migration-facing mutations.
- `TimeMaster/Services/Outdoor/PrivacyService.swift` and `TimeMaster/Services/Outdoor/ExportService.swift` — endpoint privacy representation and GPX/FIT generation.
- `TimeMaster/Views/Outdoor/` — same-pine Finish, Establish, Library, detail, confirmation, and empty/error states.
- `TimeMaster/Views/Profile/` and `TimeMaster/Views/History/` — local Public Profile route integration and shared activity identity consumers.
- `TimeMaster/Utilities/MusicManager.swift` and outdoor route-session state — finalized played-track history consumed by result and detail.

## Dependencies

- F28-B — permanent map, main route pine, detents, MAX, cross-version Liquid Glass, and same-pine presentation.
- F28-C — accepted movement, finalized metrics, pause/resume, three-metre validation, and active-session ownership.
- F28-D — route geometry, map snapshots, camera continuity, and provider-owned map data.
- F28-E — real playback events, stable track references, artwork metadata, and finalized played-track history.
- F28-G — persisted privacy defaults, endpoint-hiding service, recovery, migration defaults, backup, and unusual-state handling.
- F09 — file-backed activity persistence and single-writer behavior.
- F24 — full-screen route entry/exit and return to the launching app surface.
- F25 — shared local playback metadata and provider-neutral artwork references.
- Apple Core Location, Core Motion, and the approved local export/share services provide the finalized route inputs and system sharing boundary.

## Reference

- `features/F28-better-maps-recording/tmux_route_recording_prototype (1).html` — authoritative same-pine Finish, Establish, Library, detail, filter/sort, deletion, and accessibility interaction specification.
- `features/F28-better-maps-recording/DOCKS.md` — parent decisions for three-metre discard, Public/Profile semantics, privacy distances, migration, Library, export, and deletion thresholds.
- `features/F28-better-maps-recording/RF28-A-outdoor-remake-migration/DOCKS.md` — migration inputs, legacy Run & Walk preservation, and local Profile boundary.
- `features/F25-Music-Player-Update/DOCKS.md` — existing playback and provider-neutral source ownership.
