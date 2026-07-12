# Phase 4 of F01-B — F05-B Notion-Style Pages UI Enhancement

## Context
We are building the V2 Notion-style Unified Page Model. Phase 3 connected the data layer to the UI (DatabaseView V2, ExercisePageDetailView, PageCreationSheet, media viewer, link previews). Phase 4 enhances the page UI with inline video playback (YouTube, Instagram embeds), improved link attachment UX, and the ExercisePageDetailView edit-to-markdown integration.

## What You Need to Read First
- `features/F01-unified-page-model/F01-B-unified-page-model/DOCKS.md` — full spec
- `features/DOCKS.md` — root index (check what F05-B requires)
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — current detail view (Phase 3)
- `TimeMaster/Views/Database/PageLinkPreview.swift` — link preview component (Phase 3)
- `TimeMaster/Views/Database/PageCreationSheet.swift` — creation/editing sheet (Phase 3)
- `TimeMaster/ViewModels/DatabaseStore.swift` — V2 store
- `TimeMasterCore/Sources/Models/ExercisePageManifest.swift` — manifest model

## What Happened Last Session (Phase 3)
- DatabaseView adapted to dual-mode: V2 page tree (when page-migrated) + V1 fallback (folders/notes/exercises)
- Created ExercisePageDetailView: cover hero with parallax, editable title, markdown body, media gallery grid, link list, child pages grid, breadcrumbs, empty/error states
- Created PageCardView: cover/icon/gradient thumbnails with child count badge and workout type tags
- Created PageCreationSheet: full manifest editor (title, SF Symbol icon picker, workout type grid, duration/rest/sets steppers, markdown editor, links text field, tags)
- Created PageMediaGallery: fullscreen viewer with zoomable/pannable images, AVPlayer video, swipe between items, dismiss gesture
- Created PageLinkPreview: platform-detected cards (YouTube/Instagram/TikTok/web) with OpenGraph metadata fetch
- Added page reorder (drag-to-reorder), swipe-to-delete, context menus, page-to-parent movement
- Added all 5 new files to Xcode pbxproj for both iOS and macOS targets
- Verified: macOS arm64 build succeeds, 63/63 core tests pass, no regressions

## What to Build

### Task 1 — Inline Video Preview / Embed Cards
Instead of plain link previews, render actual video previews where the platform supports it:
- YouTube: Show thumbnail from `oembed` API, play button overlay, tap → opens in web view or YouTube app
- Instagram: Show thumbnail from OG metadata, tap → opens Instagram app or web
- TikTok: Show thumbnail, tap → opens TikTok app or Safari
- Web: Show generic OG preview as currently implemented
- Each video embed card should look like a rich media card with thumbnail + title + duration badge

### Task 2 — Edit-to-Guide Integration
- ExercisePageDetailView "Edit" button opens the PageCreationSheet (already working)
- After save, the detail view should re-read guide.md fresh (currently uses manifest.markdownBody which is a cached excerpt)
- Add a `loadGuideContent()` method to ExercisePageDetailView that reads the full guide.md from disk
- The markdown section should show the FULL guide.md content, not the cached excerpt
- Cache the full content in a @State variable, reload on appear

### Task 3 — Cover Image Upload from Detail View
- In PageCreationSheet, add a "Cover Image" section
- Upload from Photos (PhotosPicker on iOS, file picker on macOS)
- Save to `cover.{ext}` in the page folder root
- Update manifest.coverImageFilename
- Show preview in the sheet

### Task 4 — Media Upload to Page
- In PageCreationSheet or ExercisePageDetailView, add "Add Media" button
- Upload photos/videos to page's `media/` subdirectory
- Update manifest.mediaFilenames
- Show preview grid with delete buttons
- Max 20 media items per page

### Task 5 — Page Reorder Persistence
- Currently drag-to-reorder only reorders the in-memory list
- Need to persist childIDs order to parent's manifest via DatabaseStore
- Add `reorderChildren(parentID:childIDs:)` method or use movePage with order

### Task 6 — Breadcrumb Navigation
- ExercisePageDetailView shows breadcrumbs (already partially working)
- Make breadcrumbs tappable → navigate back to ancestor page
- When navigating to a child page, animate the push transition with matched geometry (cover → cover)

## Files to Create/Modify
- **create:** `TimeMaster/Views/Database/VideoEmbedCard.swift`
- **modify:** `TimeMaster/Views/Database/ExercisePageDetailView.swift`
- **modify:** `TimeMaster/Views/Database/PageCreationSheet.swift`
- **modify:** `TimeMaster/Views/Database/PageLinkPreview.swift`
- **modify:** `TimeMaster/ViewModels/DatabaseStore.swift` — add reorderChildren wrapper

## Verification
- [ ] YouTube links show video thumbnail + title preview cards
- [ ] Instagram/TikTok links show platform-specific previews
- [ ] Tapping a video embed opens the correct app/web view
- [ ] Edit page → save → detail view refreshes with new content
- [ ] Full guide.md content loads and renders in detail view
- [ ] Cover image can be uploaded from photo library
- [ ] Cover image appears in detail view hero
- [ ] Media can be uploaded to page's media/ folder
- [ ] Media appears in gallery grid on detail view
- [ ] Page reorder persists across app relaunch
- [ ] Breadcrumbs navigate back to ancestor pages
- [ ] macOS arm64 build succeeds
- [ ] All 63 core tests pass (no regressions)

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents. Do all work yourself.
2. **COMMIT AFTER DONE:** After completing every task, commit with a clear message.
3. **UPDATE CYCLES.md:** After verifying a task, mark it `[x]` in CYCLES.md.
4. **GENERATE THE NEXT PROMPT:** After finishing all tasks and committing, create the next prompt file.

## When You Finish
Report what was built, what was verified, what evidence was captured, and the path to the next prompt file.
