# F28-E — Music Workout Editor

F28-E is the iPhone route-feature presentation of the existing Music Settings library. It is a lower feature pine inside the permanent-map route composition, not a second Music database and not a new page. Before and during a workout, the same editor exposes the user’s real local music, shared section memberships, collection contents, playback state, and provider availability.

## What We Build

- One shared Music Editor opened from the Start pine, the live workout pine, or the compact player’s edit control.
- Run, Bike, Walk, and More as real destination sections supplied by the existing Music Settings section system.
- A main editor section chooser and an inline search-tray source chooser, both using the native iOS wheel/carousel interaction.
- Real local tracks, albums, playlists, folders, artwork, durations, membership ordering, and playback rather than prototype rows.
- Content-driven Music pine sizing from the selected section’s measured content, including expanded collections and the inline search tray.
- Inline search inside the Music pine, with no popup, separate sheet, or second pine.
- Direct local reorder and folder/collection creation with distinct insertion and dwell intent.
- Temporary playable references when a search-tray item is dragged into the current workout section; the Settings library remains unchanged.
- A fixed-height compact player sibling backed by the real local playback service.
- Durable per-activity played-track history connected to the route session and finalized workout detail.
- Honest empty, unavailable, offline, permission, missing-file, and playback-failure states without fabricated music data.

The existing Music Settings system remains the owner of library identity, membership persistence, local file adoption, collection membership, official provider boundaries, artwork references, and provider-neutral playback items. F28-E owns only the route presentation, route-session additions, and playback events needed by the outdoor activity. Detailed route pine geometry, map continuity, and sibling constraints conceptually belong to F28-B; Finish and Library consume the track history described here.

## Architecture

The Music Editor observes the one persisted Music Settings catalog and its ordered memberships. A track or collection keeps one stable identity when it appears in General, Run, Bike, Walk, More, or another existing destination. Adding the same item to a destination does not copy its audio or create a route-specific library record.

The editor has two independent section identities:

- **Editor destination.** The section whose ordered tracks and collections are being edited for the current route session. Changing it replaces the visible library content and remeasures the pine.
- **Search-tray source.** The section searched by the inline tray. It may be Bike while the editor destination remains Run. Changing it never changes the editor destination, moves ownership, or rewrites Settings membership.

The route session may hold temporary references that point back to real source items. These references retain source identity and artwork/playback metadata, but are not persisted as Music Settings membership. They remain available while the route session is active, including when the editor is resized, closed, reopened, or recovered with the workout. Session reset removes them and never removes the source item.

The player observes the existing local playback queue and transport. It does not own a second queue, a second artwork cache, or a separate provider configuration model. A route session records stable played-item references and the display metadata required for later historical rendering; it does not invent history for tracks that were not observed.

Remote providers are official integration boundaries. A configured provider may supply searchable and playable items according to its account, permission, capability, and playback rules. An unconfigured, unauthorized, unsupported, expired, or unavailable provider reports that state in the Music surface rather than showing sample content or claiming playback.

## Pine Geometry and Presentation

The Music Editor is a closable lower sibling pine above the permanent map. Its bottom edge remains anchored while its top glass edge follows a direct handle drag. It opens at a measured content fit rather than a fixed 70-percent height: a small section is shorter, a larger section is taller, and both are clamped to the route’s practical minimum and maximum. With enough content to reach the maximum, additional rows scroll inside the pine instead of pushing the iPhone canvas.

Content measurement includes visible track rows, collection rows, expanded collection children, and the inline search tray. Opening search adds only the tray’s measured need; it does not jump to a large detent or leave empty glass. A direct user resize takes priority over automatic fitting until the editor is reopened. The normal lower-feature detents remain compact, medium, and expanded, with the Music editor able to move toward the compact approximately 30-percent state and up to the normal full-height state. A deliberate continuation from compact toward zero closes the editor pine. A handle tap alone never closes it.

The Start or live-workout pine remains a visible, usable sibling immediately above Music. Growing Music compresses that sibling only as needed, without hiding it. Growing the workout sibling compresses Music instead of disabling it. Both surfaces remain interactive and the map remains behind the stack. The Music content coordinate space and scroll position remain fixed while the moving glass boundary clips or reveals content; rows do not slide with the top edge.

When the route or workout pine is in true MAX, the Music Editor appears as a bottom slide-over drawer over the flat MAX surface. The MAX pine does not shrink or reflow. Dismissing the drawer reveals the same MAX content and state. The compact player is a separate fixed-height lower sibling and is excluded from the closable lower-pine dismissal gesture.
On iOS 26 and later the Music surfaces use native Apple Liquid Glass. On iOS 16 through iOS 25 they use the existing private renderer with the same geometry, clipping, motion, and accessibility behavior; reduced transparency uses the approved readable fallback rather than a second design.

## Sections and Section Choosers

The editor section chip shows the committed destination and opens an inline native wheel containing Run, Bike, Walk, and More from the shared Music Settings system. The centered wheel value is a preview until the user commits it; committing morphs the wheel back into the compact chip and loads that section’s real content. A missing or empty section remains an honest empty destination.

The search tray contains its own section chip and native wheel with the same four section identities. Its centered value changes only the tray source. The editor can remain on Run while the tray browses Bike, and returning to the tray restores its last source selection for the current editor session. The two wheels expose their own selected values and never silently synchronize the other section.

There is no persistent Run/Bike/Walk/More destination strip under the library. Section changes occur through the editor chip or the tray chip, while row dragging remains dedicated to reorder, folder intent, or temporary tray import.

## Music Editor States

| State | Visible result and behavior |
|---|---|
| Editor closed | The Start or live-workout pine remains visible. Existing playback and the fixed player continue independently. |
| Editor open | The selected real section, collections, rows, header controls, and measured pine are visible inside the lower sibling. |
| Editor section chooser | The compact chip morphs into the native wheel. The centered section is previewed, then committed back into the chip. |
| Empty section | The section shows its real empty state and available local/search actions without placeholder tracks. |
| Collection closed | A real album, playlist, or folder row shows its artwork mosaic, name, duration, and expansion affordance. |
| Collection expanded | Contained real tracks appear inline. Expansion is not navigation; collection expansion and editor scroll position survive sibling focus changes. |
| Search tray closed | The editor library occupies the content area and the corner control only opens the tray. |
| Search tray open | The tray is measured inline in the same pine. Its query, explicit Search action, source-section chip, and real results are visible. |
| Search editing | The query receives focus. Search executes only from the tray Search action or Return, never from tapping the corner toggle. |
| Search results | Each result shows real artwork and a fixed-width title viewport. Long titles move horizontally under soft edge fades; the tray geometry does not widen. Collections may expand their real children inline. |
| No search results | The tray reports no matching real items and keeps the current editor destination unchanged. |
| Item dragging | A lifted representation follows the finger. Insertion, folder, or tray-import feedback identifies the current destination before release. |
| Playback active | The fixed compact player is present and transport state reflects the real backend. Pausing leaves it present. |
| Provider unavailable | The affected provider or item says what configuration, account, permission, network, or capability is missing. No fake item, URL, artwork, or success state appears. |

## Playback and Track History

Tapping a real playable row, collection child, or search result starts that item through the existing local playback system or a configured official provider path. The row remains a normal play target even when it also supports dragging. A deliberate movement after the drag threshold lifts the row; a simple tap plays it. Provider items that cannot be played in the current account or offline state remain visibly unavailable rather than entering a false player state.

Starting playback inserts a fixed-height compact player from the bottom. The player has a real artwork slot, a lower dark artwork fade, the current title with horizontal marquee behavior when necessary, progress, previous, play/pause, next, and an edit control. Transport controls are bare system-style icons without individual button bases or an enclosing transport pill. The player height does not change with title length or transport state.

The Music control is a close toggle in both the pre-workout Start pine and the live-workout pine: tapping Music while this editor is focused closes only the editor, while playback and the fixed player continue.
The player cannot be dismissed by swiping or dragging. Pausing, changing sections, closing the editor, pausing the workout, or using the workout Stop/Resume control never removes it. Only the explicit Stop Playback control inside the Music Editor removes playback and the player. The player edit control always opens or focuses this same editor. If it is already open, the editor preserves its destination section, scroll offset, expanded collection state, and current pane height; the close-toggle rules still clear an open search tray when the Music Editor itself is closed.

At workout start, the route session records the currently playing real track when one exists. It records each subsequent real track change observed during the active workout, including row playback and previous/next transitions, with stable item identity, title/artist or other display metadata available from the source, and artwork reference. The finalized activity receives the ordered history and count. A track that was never played during the route is not added, and missing historical artwork degrades to its honest unavailable representation without changing the route identity.

## Drag, Reorder, Folder, and Import Intent

A dedicated row handle is the strongest drag affordance, but a deliberate press-and-drag from the row body also lifts the same item after a small movement threshold. A normal tap remains playback. The origin row fades and the lifted item has a readable artwork/title representation.

Within a compatible editor list, the drop position determines the intent:

- Near the upper insertion zone of a target row, an insertion line means place before it.
- Near the lower insertion zone, an insertion line means place after it.
- In the center zone, the item first receives ordinary insertion feedback. Holding over a compatible sibling row for the short folder dwell, approximately 360 milliseconds, changes feedback to a folder/collection merge target.
- Dropping after the dwell creates or updates a collection containing the intended tracks. Merely crossing a row center, moving through it, or lifting before the dwell never creates a folder.

The reorder/folder decision uses position, dwell, movement velocity, and hysteresis so small finger motion does not oscillate unpredictably between intents. A folder intent is available only where the existing Music Settings rules permit a compatible collection merge; otherwise the destination remains insertion. Stable item identity and persisted ordering remain owned by Music Settings for lasting in-library edits.

Dragging a result from the search tray into the current editor library is a separate temporary-import interaction. The tray result follows the finger, the editor viewport indicates it can receive the item, and the drop gives before/after feedback or appends when no row is targeted. The temporary reference is playable in the current route session and records the source section and destination section for that session. It never moves or duplicates ownership, never mutates permanent Settings membership, and is removed when the route session resets.

## Search and Collection Behavior

The corner Search control is only an inline tray toggle. It does not execute a query, create a popup, or open another pine. The tray’s explicit Search action and Return while editing execute against the real Music Settings library exposed by the selected tray source. Reopening the tray keeps the current route-session query/source state unless the Music Editor was closed; closing the editor clears tray-open state so it cannot reappear unexpectedly.

Search results are intentionally minimal: real cover artwork and real item name in a fixed viewport. A long title uses a restrained horizontal marquee beneath soft fades and never changes the result card geometry. A real album, playlist, or folder result can expand its contained search results inline while preserving the query and tray source.

A collection row expands and collapses in place with its real children. The editor retains the selected destination, collection expansion, and scroll position when the workout pine is focused, the player edit control reopens Music, the editor is resized, or the sibling stack reflows. A route-session-only imported row follows the same playable and reorderable presentation but is visibly governed by session lifetime rather than permanent Settings membership.

## Failure, Offline, and Recovery States

- Local tracks and local route playback remain usable without network access when their files and permissions are available. Music playback and route recording do not depend on map tiles, traffic, routing, or provider network access.
- A missing local file, revoked permission, unsupported format, or playback error leaves the source item and membership intact, reports the unavailable item in place, and does not add a false track-history event.
- An unconfigured or unauthorized official provider exposes its real unavailable/configuration state. Search, artwork, and playback are not simulated with placeholder records.
- A network interruption may leave already available local content playable while provider-backed rows report unavailable or retry-needed state. The workout and existing playback session remain intact.
- An empty library, empty destination, or empty collection has a calm real empty state. Search and local import actions remain available where the shared Music Settings contract supports them.
- A canceled drag, a drop outside a valid target, or a failed temporary import leaves both the source section and editor membership unchanged.
- A failed reorder or folder persistence operation leaves the previous durable order and collection membership visible rather than claiming success.
- If the app is backgrounded, interrupted, or reopened during a recoverable workout, the route session restores the same editor destination, pane arrangement, collection state, playback state where the platform permits, temporary imports, and accumulated track history. A later route-session reset clears only temporary imports; finalized activity history is durable.

## Animation and Motion

Direct resizing of the Music pine is one-to-one with the finger and remains interruptible. Release settles to the nearest valid detent using a restrained, velocity-aware spring. The Start/live-workout sibling and exposed map region reflow continuously with the moving edge.

Automatic content fitting animates when section content, collection expansion, or tray content changes. Tray opening and closing use a short inline reveal and add only measured height. Collection expansion uses a scoped height/opacity transition. Search result title movement is restrained and stops for short titles.

The section chip morphs into its wheel and back without navigation. The fixed player inserts from the bottom with a scoped spring, while its transport progress follows the real playback clock. Drag feedback appears at the target, the lifted representation follows the pointer, and the created collection settles with a short confirmation transition. Press feedback stays subtle and does not turn transport icons into pills.

Reduce Motion removes large spring travel, automatic marquee motion, decorative symbol effects, and nonessential drag flourishes while retaining direct state changes, clear insertion/folder feedback, and one-to-one direct manipulation. Reduced Transparency uses readable opaque surfaces while keeping the same pine geometry and clipping.

## Accessibility

The editor, player, section chips, search toggle, explicit Search action, Stop Playback, collection expansion, transport controls, drag handles, rows, and unavailable states have meaningful labels and current values. VoiceOver identifies the editor destination and tray source independently, announces the centered wheel preview and committed section, and exposes collection expanded/collapsed state.

The native iOS wheel control owns selection, snapping, focus, and adjustable accessibility actions. Row playback and drag affordances remain separately reachable so a VoiceOver user can play an item without beginning a drag. Reorder and folder actions expose an equivalent accessible move/group operation; the 360-millisecond pointer dwell is not the only way to express the intent.

Dynamic Type allows rows, titles, tray results, and provider messages to reflow or scroll inside their measured pine without hiding transport or Stop Playback. Artwork is not the only meaning signal; title, section, playback, unavailable, insertion, and folder states are labeled. Hit targets remain appropriate for iPhone use. Haptics follow the persisted route preference when available and never carry the only confirmation.

## Files

- `TimeMaster/Models/MusicLibraryModels.swift` — shared provider-neutral items, collections, destinations, memberships, and stable artwork references.
- `TimeMaster/ViewModels/MusicLibraryStore.swift` — shared Music Settings ordering, section content, local search, and durable in-library mutations.
- `TimeMaster/Utilities/MusicManager.swift` — local playback, queue and transport state, and route-session playback events.
- `TimeMaster/Services/MusicProviderAdapters.swift` — official provider account, capability, search, availability, and playback boundaries.
- `TimeMaster/Views/Outdoor/` — route Music pine, section wheels, inline tray, drag feedback, and sibling presentation.
- `TimeMaster/Views/Settings/MusicLibraryScreen.swift` and `TimeMaster/Views/Settings/MusicPlayerPane.swift` — shared Music Settings and compact-player presentation reused by this route.
- `TimeMaster/ViewModels/OutdoorActivityStore.swift` and the outdoor activity manifest — finalized played-track references consumed by F28-F.

## Dependencies

- F25 — the persisted Music Settings catalog, local import, collections, destination membership, artwork, provider boundaries, and local playback domain.
- F28-B — permanent map, Liquid Glass pine geometry, detents, MAX drawer behavior, sibling reflow, and cross-version glass policy.
- F28-C — active workout session lifetime, pause/resume, interruption recovery, and the boundary at which played-track events are recorded.
- F28-F — Finish and Library rendering of finalized track history and artwork references.
- F28-G — route-session recovery, persisted preferences, and migration/backup behavior.
- F09 — local file-backed persistence and single-writer behavior.

## Reference

- `features/F28-better-maps-recording/tmux_route_recording_prototype (1).html` — authoritative Music Editor, player, inline search, drag-intent, and route-session behavior.
- `features/F25-Music-Player-Update/DOCKS.md` — existing Music Settings product contract and provider rules.
- `features/F28-better-maps-recording/DOCKS.md` — parent route, playback-history, privacy, and cross-version decisions.
- `features/F28-better-maps-recording/RF28-A-outdoor-remake-migration/DOCKS.md` — migration boundary and shared Music data continuity.
