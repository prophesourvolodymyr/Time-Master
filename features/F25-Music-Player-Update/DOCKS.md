# F25 — Music Player Update

The Music setting is a compact, iPhone-first music library. It replaces the old list with connected sources, a shared General shelf, ordered workout destinations, and a small playback surface.

## What We Build

- One black Music screen with four independent pines: Uploads, General, Workout Type / My Workouts, and the conditional Player.
- A provider-neutral persisted library. Every music item has a stable app identity, a source reference, metadata, artwork reference, duration, collection kind, and optional contained tracks. Provider audio is never copied locally.
- Ordered membership for General, every workout type, and every existing user workout. The same provider or local reference may appear in multiple destinations without audio duplication.
- Local Files import through the native picker. Existing Music Manager files are adopted into General.
- Official-integration boundaries for Spotify, YouTube Music, SoundCloud, Dropbox, and Google Drive. Their current build state is unavailable until each provider is registered and configured; the UI says so rather than manufacturing remote data.

## Visual Composition

The full screen is near-black. Pines use slightly lighter black surfaces, subtle borders, restrained inner depth, 25-point rounded corners, off-white primary text, gray secondary text, and orange only for selection, confirmation, progress, and primary emphasis. Upload source cards, folder cards, and music cards are smaller rounded surfaces inside their pine. Spotify, YouTube Music, and SoundCloud use real bundled brand image assets. Generic actions use SF Symbols.

Search and guide are stationary circular screen overlays. They never move with the Uploads source strip. On iOS 26 or later they use the native Liquid Glass surface. On iOS 18 they keep the same geometry and behavior with a native material fallback, deliberate border/highlight, and Reduced Transparency handling.

## Architecture

- `MusicLibraryModels` owns music source, local and provider references, artwork, collection tracks, music items, destination families, destinations, transfers, and search results.
- `MusicLibraryStore` owns persistence, destination ordering, workout-derived destinations, duration calculation, mutations, transfer decisions, and fast local search.
- `MusicProviderAdapters` isolates official sign-in, account, search, capability, and playback integration. It has no credentials, no embedded secrets, no scraper, and no downloader.
- `MusicLibraryScreen` owns the native visual hierarchy, local interaction state, panes, search, guide, transfer prompt, and compact player composition.
- `MusicManager` remains the local AVFoundation playback path. Provider-specific playback is deferred to official adapters when configured.

## States

| State | Visible result | Behavior |
|---|---|---|
| General focus | Uploads is tall, General is the largest pane, Workout stays compact | General is vertically scrollable; tapping its label returns here without clearing the selected workout destination. |
| Workout focus | Uploads and General shrink but stay visible; Workout expands | The selected Type or Mine folder strip stays visible above its ordered music list. |
| Type | Predefined and project-defined workout types appear in the horizontal strip | The selected type is orange and keeps its selection across General focus. |
| Mine | Existing user workouts appear in the horizontal strip | A missing workout list shows a compact empty state rather than invented workouts. |
| Empty General | General has no imported items | A compact import prompt is shown; no fabricated library data appears. |
| Empty workout destination | Selected destination has no items | It shows a compact drop target. |
| Collection closed | Playlist, album, and library have one compact row | The row shows artwork mosaic semantics, total duration, add, delete, and expand controls. |
| Collection open | Contained tracks appear inline | Expansion and collapse are spring/opacity transitions. |
| Player open | A fourth sibling pine appears below Workout | It resizes surrounding panes without forcing Workout focus. Its cover contains the title over a lower dark fade; long names marquee and short names remain still. |
| Select mode | The user pressed a row add button | A dimmed overlay lets the user add that item to Type or Mine destinations; Cancel restores the original layout and Done closes it. |
| Drag/reorder | A row is held and dragged | The origin fades. Dropping in the same list preserves stable identity and changes exact ordered position. General-to-workout is direct; workout-to-different-workout opens Move, Duplicate, or Cancel. |
| Search | Search replaces the Music content below navigation | Provider toggles reset off each entry. Local results update immediately. Enabled providers are separate panes above local results and honestly show connection requirements until configured. |
| Guide | First entry waits about two seconds, then overlays the real screen | Underlying interactions are blocked. The compact black conversation has app-left/user-right bubbles, typing dots, one More response per step, Skip, Done, replay, and a contained orange spotlight. |
| Delete | A destructive remove action is pressed | A confirmation dialog appears before removing the item from every library destination. |

## Interaction Rules

- Source cards are horizontally scrollable with fixed left and right viewport fades. Import opens the native local picker. Provider cards and provider search controls open their official-configuration notice until credentials and official SDK/API paths are supplied.
- General, Workout music, Search, provider destination content, and guide messages fade at the top and bottom of their own scroll viewports.
- A user can switch Type/Mine by tapping or dragging the compact pill. A selected folder uses orange plus a border/depth change.
- General remains scrollable while Workout is open. A continuous real vertical scroll gesture of approximately three seconds shifts focus to General; a pause, stationary touch, drag, guide, or select mode resets/prevents it.
- Music rows can be dragged between General and destinations. Same-destination reordering is a direct order change. Moving from a workout destination to another workout destination pauses for an explicit Move or Duplicate decision. Moving from a workout destination to General is direct.
- The player opens from a local track row and the same active row closes it. Previous, next, play/pause, scrubber, and destination card stay compact. The scrubber has no timestamps.
- Search finding a local item selects its real destination, sets the appropriate focused pane, and opens a matching collection inline.
- Guide organization uses a temporary model item, drives normal destination mutation, then removes the item; it does not alter user music as tutorial data.

## Animation and Accessibility

Pane focus and Player insertion use scoped springs. Collection expansion uses a shorter scoped spring plus opacity transition. The guide uses contained fade/scale entry and exit, an orange spotlight that morphs between target geometry, and stable chat placement within a step. Reduce Motion removes large motion; Reduced Transparency uses opaque fallback glass. Icon-only controls carry labels. Orange is paired with labels, borders, and checkmarks rather than acting as the only selection signal.

## Dependencies

- Existing `MusicManager` for user-owned local file import and AVFoundation playback.
- Existing `WorkoutStore` and dynamic `WorkoutType` model for Mine and Type destinations.
- Future provider credentials and official SDK/API work are separate external prerequisites. No feature depends on unofficial extraction or downloading.

## Files

- `TimeMaster/Models/MusicLibraryModels.swift` — persisted provider-neutral domain.
- `TimeMaster/ViewModels/MusicLibraryStore.swift` — ordered destination state and search.
- `TimeMaster/Services/MusicProviderAdapters.swift` — official provider integration boundaries.
- `TimeMaster/Views/Settings/MusicSettingsView.swift` — native picker and screen integration.
- `TimeMaster/Views/Settings/MusicLibraryScreen.swift` — Music pines and interaction surface.
- `TimeMaster/Views/Settings/MusicGlassControls.swift` — reusable native glass/fallback controls and scroll fades.
- `TimeMaster/Views/Settings/MusicGuideOverlay.swift` — first-run and replayable guide.
- `TimeMaster/Views/Settings/MusicPlayerPane.swift` — compact independent player pine.
- `TimeMaster/Resources/Assets.xcassets` — bundled provider assets.

## Reference

- `master-music_settings_pine_prototype_v38.html` in this feature folder is the visual and behavioral reference, adapted to real SwiftUI state and existing local playback.
- Spotify, YouTube, SoundCloud, Dropbox, and Google Drive must be implemented only through their current official authentication, data, branding, and playback policies before release.
