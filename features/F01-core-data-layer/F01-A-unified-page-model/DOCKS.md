# F01-A — Unified Page Model

Replace ExerciseFolder, Exercise, and TrayItem with a single unified ExercisePage struct. Every page is equal — pages can contain child pages, media, links, and metadata. No technical distinction between "folders" and "exercises."

## What We Build
- Single `ExercisePage` struct (Codable, Identifiable) replacing three separate types
- Tree structure: every page has `children: [ExercisePage]` for infinite nesting
- Every page supports: cover image, media items (photos/videos), timed sections, notes, links, tags
- DatabaseStore rewritten to operate on a flat page list with parent references instead of nested folder structs
- Migration path from old data (ExerciseFolder + Exercise + TrayItem → ExercisePage)

## Architecture
```
Models/
├── ExercisePage.swift      — replaces ExerciseDatabase.swift + TrayItem.swift

ViewModels/
└── DatabaseStore.swift     — rewritten: flat page store, parentID-based nesting

OLD (removed):
├── ExerciseDatabase.swift
└── TrayItem.swift
```

## ExercisePage Model
```swift
struct ExercisePage: Identifiable, Codable {
    var id: UUID
    var title: String
    var coverImageFilename: String?
    var icon: String?                      // SF Symbol fallback
    var mediaItems: [MediaItem]            // photos + videos
    var timedSections: [TimedSection]      // optional timer config
    var notes: String
    var links: [ExternalLink]
    var tags: [String]
    var parentID: UUID?                    // nil = root
    var children: [ExercisePage]           // exported for migration, runtime uses parentID
    var createdAt: Date
    var updatedAt: Date
}

struct ExternalLink: Codable {
    var url: URL
    var title: String
    var platform: LinkPlatform           // youtube, instagram, facebook, tiktok, web
}

enum LinkPlatform: String, Codable {
    case youtube, instagram, facebook, tiktok, web
}
```

## Files
- `TimeMaster/Models/ExercisePage.swift` (new)
- `TimeMaster/ViewModels/DatabaseStore.swift` (rewrite)
- `TimeMaster/Models/ExerciseDatabase.swift` (archive)
- `TimeMaster/Models/TrayItem.swift` (archive)

## Dependencies
None — this is the V2 foundation. All other V2 features depend on this.

## Verification
- [ ] ExercisePage encodes/decodes correctly
- [ ] Tree navigation: parentID-based flat store, children built at runtime
- [ ] Migration: old ExerciseFolder + Exercise data converts to ExercisePage without data loss
- [ ] Cover images, media items, links, notes, tags all save and load
- [ ] Infinite nesting: page → children → grandchildren works
- [ ] compiles without errors
