# F05-B — Notion-Style Pages

Every exercise is a rich page: cover images, media gallery, timed sections, notes, external links with YouTube embeds, infinite child nesting, and workout type tags. The database becomes a visual, browsable library.

## What We Build

### Page Content
- **Cover image:** cropped 3:2 header image, selectable from media or photo picker. SF Symbol icon fallback.
- **Media gallery:** scrollable grid of photos and videos. Tap to full-screen. Add/delete/reorder.
- **Timed sections:** optional timer config per exercise (for reference, not workout — e.g., "hold handstand for 30s"). Independent from workout sets.
- **Notes:** multi-line text area with basic formatting (bold, italic via Markdown).
- **External links:** list of links with platform icons. YouTube links get inline WKWebView embed when tapped (plays in-app). Instagram/Facebook/TikTok open in Safari (platforms block iframes).
- **Child pages:** nested sub-pages for progression exercises (e.g., "Handstand" page has children: "Wall Handstand", "Freestanding Handstand"). Infinite depth.
- **Type tags:** one or more workout type tags (strength, cardio, custom types). Selected from user-defined type list in settings (F07-C).

### Page View (Database Browser)
- Root level: "All Pages" grid with type tag filter chips at top
- Cover images in cards (3:2), title below, tag chips, media count badge, child count badge
- Tap page → opens full page view with content sections
- Navigation breadcrumbs at top when nested (e.g., "Calisthenics > Handstand > Wall Handstand")
- "Add Child Page" button on every page
- Search: by title, tags, notes content

### Links & Embeds
- Add link: paste URL, auto-detect platform (YouTube, Instagram, etc.), set title
- YouTube embed: tap link → WKWebView opens inline in page, plays video. Compact player (16:9 ratio).
- Other platforms: tap opens system browser (Safari)
- Links display with platform icon + title + domain

## Architecture
```
Views/Database/
├── DatabaseView.swift                 — rewrite: grid browser, type filter chips
├── ExercisePageView.swift             (new) — full page content viewer
├── ExercisePageCard.swift             (new) — grid card
├── ExercisePageEditor.swift           (new) — create/edit page
├── MediaGalleryView.swift             (new) — scrollable media grid
├── LinksListView.swift                (new) — links with platform icons
└── YouTubeEmbedView.swift             (new) — WKWebView wrapper

Models/
└── ExercisePage.swift                  — unified model (from F01-A)
```

## Files
- `TimeMaster/Views/Database/DatabaseView.swift` (rewrite)
- `TimeMaster/Views/Database/ExercisePageView.swift` (new)
- `TimeMaster/Views/Database/ExercisePageCard.swift` (new)
- `TimeMaster/Views/Database/ExercisePageEditor.swift` (new)
- `TimeMaster/Views/Database/MediaGalleryView.swift` (new)
- `TimeMaster/Views/Database/LinksListView.swift` (new)
- `TimeMaster/Views/Database/YouTubeEmbedView.swift` (new)
- `TimeMaster/Models/ExercisePage.swift` (new — from F01-A)

## Verification
- [ ] Create page: cover image, media, notes, links, tags, child pages
- [ ] Grid browser with type filter chips, search
- [ ] Nested navigation: breadcrumbs at top, children below
- [ ] YouTube link plays inline via WKWebView
- [ ] Instagram/Facebook/TikTok links open in Safari
- [ ] Child pages support infinite nesting
- [ ] Type tags filter correctly, custom types from F07-C appear
- [ ] compiles without errors
