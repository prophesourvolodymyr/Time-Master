# F01-B — Unified Page Model

Replaces `ExerciseFolder` + `Exercise` + `DatabaseNote` + `TrayItem` with a single `ExercisePage` data model. Every entity in the Exercises Database becomes a page — folders, exercises, and notes are unified. Pages contain cover images, markdown bodies, media, external links, workout configuration, and nested child pages at unlimited depth. Think Notion, but purpose-built for exercise content.

## What We Build

1. **`ExercisePageManifest`** (in TimeMasterCore) — new Codable manifest replacing `ExerciseManifest`
2. **`ExercisePage`** (in TimeMaster app) — runtime model wrapping the manifest for SwiftUI
3. **Updated `DatabaseManager`** — CRUD for pages using the new manifest, walkPageTree replaces walkExercises
4. **Updated `DatabaseStore`** — flat page store with parentID-based tree building, replaces folder/exercise/note arrays
5. **`PageTreeBuilder`** — utility that converts a flat `[ExercisePage]` list into a nested tree for UI rendering
6. **Migration system** — converts old `ExerciseManifest` + `ExerciseFolder` + `DatabaseNote` + `Exercise` into `ExercisePageManifest`
7. **Backward compatibility** — old `ExerciseManifest` can be read and upgraded on-the-fly during migration window

## Architecture

```
TimeMasterCore/
├── Sources/Models/
│   ├── ExercisePageManifest.swift    ← NEW: replaces ExerciseManifest
│   └── ExerciseManifest.swift        ← KEPT: for reading legacy data, deprecated
├── Sources/
│   ├── DatabaseManager.swift         ← MODIFY: page CRUD, walkPageTree
│   └── MigrationManager.swift        ← MODIFY: page migration pass
│
TimeMaster/
├── Models/
│   ├── ExercisePage.swift            ← NEW: runtime model wrapping manifest
│   └── ExerciseDatabase.swift        ← MODIFY: add ExercisePage, deprecate old types
├── ViewModels/
│   ├── DatabaseStore.swift           ← REWRITE: flat page store
│   └── PageTreeBuilder.swift         ← NEW: flat→tree conversion
```

### Data Flow
```
File System                          TimeMasterCore              App Layer
┌─────────────────────┐           ┌──────────────────┐       ┌──────────────────┐
│ Exercises Database/  │ read/write│ DatabaseManager   │ load  │ DatabaseStore     │
│ {id}/                │──────────▶│ .walkPageTree()   │──────▶│ @Published pages  │
│   manifest.json      │◀──────────│ .createPage()     │       │ PageTreeBuilder   │
│   guide.md           │           │ .updatePage()     │       │ → nested tree     │
│   cover.jpg          │           │ .deletePage()     │       │ → SwiftUI Views   │
│   media/             │           │ .movePage()       │       └──────────────────┘
│   {child-id}/        │           └──────────────────┘
│     manifest.json    │
│     ...              │
└─────────────────────┘
```

### Page Folder Structure (on disk)
```
Exercises Database/
├── {calisthenics-id}/                       ← root page
│   ├── manifest.json                        ← ExercisePageManifest
│   ├── guide.md                             ← markdown body (the rich content)
│   ├── cover.jpg                            ← cover image (optional)
│   ├── media/                               ← page-specific media
│   │   ├── handstand-progress.jpg
│   │   └── tutorial.mp4
│   ├── {handstand-id}/                      ← child page (also a complete page!)
│   │   ├── manifest.json
│   │   ├── guide.md
│   │   ├── cover.jpg
│   │   ├── media/
│   │   │   └── form-check.jpg
│   │   └── {wall-walk-id}/                  ← grandchild page (unlimited depth)
│   │       ├── manifest.json
│   │       ├── guide.md
│   │       └── media/
│   └── {pushups-id}/                        ← another child page
│       ├── manifest.json
│       ├── guide.md
│       └── media/
├── {boxing-id}/                             ← another root page
│   ├── manifest.json
│   ├── guide.md
│   └── cover.jpg
└── {yoga-id}/
    ├── manifest.json
    └── guide.md
```

**Key rule:** Every folder with a `manifest.json` IS a page. There is no distinction between "folders" and "exercises" — they are all pages. A page without children is a leaf page. A page with children is a container page. Both are structurally identical.

## ExercisePageManifest Model (TimeMasterCore)

```swift
public struct ExercisePageManifest: Codable {
    public var id: String                   // UUID string
    public var title: String                // display name
    public var coverImageFilename: String?  // e.g. "cover.jpg", relative to page folder
    public var iconName: String?            // SF Symbol fallback when no cover (e.g. "figure.strengthtraining.traditional")
    public var markdownBody: String         // rich content — stored as separate guide.md, cached here for search
    public var mediaFilenames: [String]     // relative to page folder's media/ subdir
    public var linkURLs: [String]           // external URLs (YouTube, Instagram, TikTok, web)
    public var linkMetadata: [LinkMetadata] // pre-fetched metadata for link previews
    public var workoutType: WorkoutType?    // type tag (Strength, Stretch, Cardio, etc.)
    public var duration: Int?               // optional: seconds, if page used as workout section
    public var restAfter: Int?              // optional: rest after this exercise
    public var sets: Int?                   // optional: default set count
    public var restBetweenSets: Int?        // optional: rest between sets
    public var tags: [String]               // user-defined tags for filtering
    public var childIDs: [String]           // ordered list of child page IDs (display order)
    public var parentID: String?            // nil = root page. Redundant with directory path but enables flat-store lookups
    public var order: Int                   // manual sort position among siblings
    public var createdAt: Date
    public var updatedAt: Date

    public var kind: String { "page" }

    enum CodingKeys: String, CodingKey {
        case id, title, coverImageFilename, iconName, markdownBody
        case mediaFilenames, linkURLs, linkMetadata
        case workoutType, duration, restAfter, sets, restBetweenSets
        case tags, childIDs, parentID, order, createdAt, updatedAt
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        coverImageFilename: String? = nil,
        iconName: String? = nil,
        markdownBody: String = "",
        mediaFilenames: [String] = [],
        linkURLs: [String] = [],
        linkMetadata: [LinkMetadata] = [],
        workoutType: WorkoutType? = nil,
        duration: Int? = nil,
        restAfter: Int? = nil,
        sets: Int? = nil,
        restBetweenSets: Int? = nil,
        tags: [String] = [],
        childIDs: [String] = [],
        parentID: String? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.coverImageFilename = coverImageFilename
        self.iconName = iconName
        self.markdownBody = markdownBody
        self.mediaFilenames = mediaFilenames
        self.linkURLs = linkURLs
        self.linkMetadata = linkMetadata
        self.workoutType = workoutType
        self.duration = duration.map { max(5, $0) }
        self.restAfter = restAfter.map { max(0, $0) }
        self.sets = sets.map { max(1, $0) }
        self.restBetweenSets = restBetweenSets.map { max(0, $0) }
        self.tags = tags
        self.childIDs = childIDs
        self.parentID = parentID
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LinkMetadata: Codable, Equatable {
    public var url: String
    public var title: String?
    public var description: String?
    public var thumbnailURL: String?
    public var platform: LinkPlatform

    public init(
        url: String,
        title: String? = nil,
        description: String? = nil,
        thumbnailURL: String? = nil,
        platform: LinkPlatform = .web
    ) {
        self.url = url
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.platform = platform
    }
}

public enum LinkPlatform: String, Codable, Equatable {
    case youtube
    case instagram
    case tiktok
    case facebook
    case web
}
```

## ExercisePage Runtime Model (App Layer)

```swift
struct ExercisePage: Identifiable {
    let manifest: ExercisePageManifest
    let children: [ExercisePage]       // built by PageTreeBuilder, not stored in manifest
    let coverImageURL: URL?            // resolved from coverImageFilename
    let mediaURLs: [URL]               // resolved from mediaFilenames
    let path: String                   // relative path from Exercises Database root

    var id: UUID { UUID(uuidString: manifest.id) ?? UUID() }
    var title: String { manifest.title }
    var isContainer: Bool { !children.isEmpty }
    var isLeaf: Bool { children.isEmpty }
    var isRoot: Bool { manifest.parentID == nil }
    var hasWorkoutConfig: Bool { manifest.duration != nil }
    var hasCover: Bool { manifest.coverImageFilename != nil }
    var hasLinks: Bool { !manifest.linkURLs.isEmpty }
    var hasMedia: Bool { !manifest.mediaFilenames.isEmpty }
    var hasMarkdown: Bool { !manifest.markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var totalChildCount: Int { children.count + children.reduce(0) { $0 + $1.totalChildCount } }
}
```

## DatabaseManager — New Page Operations

| Function | Description |
|---|---|
| `createPage(manifest, parentID?)` | Creates folder at correct path, writes manifest.json + guide.md |
| `updatePage(id, manifest, newParentID?)` | Updates manifest. If parent changed, moves folder on disk |
| `deletePage(id)` | Moves entire page folder (including all children) to `.trash/` |
| `getPage(id)` | Reads manifest from disk, walks children directories to build childIDs |
| `searchPages(query, type?)` | Walks entire tree, filters by title/content/type, returns results with paths |
| `walkPageTree(path)` | Recursively walks from a path, reads manifests, returns flat list |
| `listRootPages()` | Lists immediate children of Exercises Database/ with manifests |
| `movePage(id, newParentID?, newOrder)` | Moves folder on disk, updates parentID + order in manifest |
| `reorderChildren(parentID, childIDs)` | Updates childIDs order in parent manifest |
| `getPagePath(id)` | Resolves a page ID to its full path in the tree (for breadcrumbs) |

### DatabaseManager — walkPageTree Algorithm
```
walkPageTree(directory: URL) → [(ExercisePageManifest, path: String)]

1. List all entries in directory
2. For each entry that is a directory:
   a. Check for manifest.json → if exists, decode as ExercisePageManifest
   b. The directory itself IS a page (not just a container)
   c. childIDs = list of subdirectories within this page's folder that have manifest.json
   d. Recurse into child directories (they are child pages)
3. Return flat list of all manifests with their paths

OLD walkExercises: distinguished between "folder" (no manifest) and "exercise" (has manifest)
NEW walkPageTree:  every directory with manifest.json IS a page. Child pages are subdirectories of the page folder.
```

## DatabaseStore — Rewrite

### Before (V1)
```swift
@Published var rootFolders: [ExerciseFolder]   // nested struct tree
@Published var rootNotes: [DatabaseNote]
@Published var rootExercises: [Exercise]
```

### After (V2)
```swift
@Published var rootPages: [ExercisePage]       // flat list of root-level pages
@Published var allPagesFlat: [ExercisePage]     // every page in the tree, for quick lookup

// Tree building
var pageTree: [ExercisePage] { PageTreeBuilder.build(from: rootPages) }

func page(id: UUID) -> ExercisePage? { allPagesFlat.first { $0.id == id } }
func children(of parentID: UUID) -> [ExercisePage] { ... }
func breadcrumbs(for pageID: UUID) -> [ExercisePage] { ... }
```

## PageTreeBuilder

```swift
enum PageTreeBuilder {
    /// Converts flat list into nested tree using parentID
    static func build(from flatList: [ExercisePage]) -> [ExercisePage] {
        let lookup = Dictionary(uniqueKeysWithValues: flatList.map { ($0.id, $0) })
        let roots = flatList.filter { $0.manifest.parentID == nil }
        return roots.map { buildBranch(root: $0, lookup: lookup) }
    }

    private static func buildBranch(root: ExercisePage, lookup: [UUID: ExercisePage]) -> ExercisePage {
        let children = root.manifest.childIDs.compactMap { childID in
            guard let childUUID = UUID(uuidString: childID), let child = lookup[childUUID] else { return nil as ExercisePage? }
            return buildBranch(root: child, lookup: lookup)
        }
        return ExercisePage(manifest: root.manifest, children: children, coverImageURL: root.coverImageURL, mediaURLs: root.mediaURLs, path: root.path)
    }

    /// Gets breadcrumb path from root to given page
    static func breadcrumbs(for pageID: UUID, in flatList: [ExercisePage]) -> [ExercisePage] {
        var crumbs: [ExercisePage] = []
        var current = flatList.first { $0.id == pageID }
        let lookup = Dictionary(uniqueKeysWithValues: flatList.map { ($0.id, $0) })
        while let page = current {
            crumbs.insert(page, at: 0)
            if let parentIDStr = page.manifest.parentID, let parentUUID = UUID(uuidString: parentIDStr) {
                current = lookup[parentUUID]
            } else {
                current = nil
            }
        }
        return crumbs
    }
}
```

## States

| State | Trigger | Visual | Behavior |
|---|---|---|---|
| **default** | Pages loaded, tree built | Flat list or grid of page cards with cover images/thumbnails, title, child count badge | Tap opens page detail. Long-press for context menu (reorder, move, delete) |
| **loading** | App launch, store.reload() | Skeleton cards with shimmer animation | DatabaseManager walks file tree, decodes manifests, builds pages. Non-blocking. |
| **empty** | No pages exist (fresh install or all deleted) | Centered "No Pages" illustration with "Create First Page" button. Default pages from defaultFolders() shown if opted in. | Tapping "Create First Page" opens page editor. |
| **error** | Corrupt manifest.json, missing directory | Card with red border, error icon, page title grayed out. "This page could not be loaded." | Skips corrupt pages silently in list. Individual page detail shows error with "Remove" button. |
| **page-detail** | User taps a page card | Full-screen page view: cover image hero at top, title, markdown body (rendered), media gallery, link list with previews, child pages grid below, edit button in toolbar | Every element is interactive. Tapping a child page navigates deeper. Back button returns to parent. |
| **page-detail-empty** | Page has no content (freshly created) | Cover placeholder (gradient with icon), title centered, "Add content" prompt, media upload zone, link input field | Each empty section has a "+" button to add content. |
| **editing** | User taps "Edit" on page detail | Cover image picker (tap to change), title text field, markdown editor (or rich text proxy), media reorder/delete grid, link URL input fields, child page list with delete buttons, workout config section (duration/rest/sets steppers), type tag picker, tags field | Changes auto-save? No — explicit "Save" button. Dismiss with confirmation dialog if unsaved changes. |
| **viewing-media** | User taps a media item in the gallery | Full-screen media viewer: photos pannable/zoomable, videos playable inline with AVPlayer, swipe between items | Dismiss with tap or swipe down. |
| **viewing-link** | User taps an external link | YouTube/Instagram: opens in-app web view with native player. TikTok: opens in Safari (no in-app embed). Web: opens in-app web view. | Back button returns to page. |

## Animation Rules

| Animation | Type | Duration | Easing | Trigger |
|---|---|---|---|---|
| Page card appearance | spring | 0.4s | response=0.3, damping=0.7 | Cards appear when tree loads or list updates |
| Page detail push | matched geometry | 0.35s | easeInOut | Cover image + title morph from card to detail header |
| Child page expand | expand/collapse | 0.25s | easeInOut | Tapping container page expands to show children (inline or push) |
| Skeleton shimmer | repeating opacity | 1.5s loop | linear | Loading state for each card |
| Media viewer present | spring | 0.4s | response=0.4, damping=0.8 | Tapping media thumbnail → fullscreen |
| Media viewer dismiss | interactive | — | spring drive by gesture velocity | Swipe down on fullscreen media |
| Cover image parallax | scroll offset | — | 0.5 parallax factor | Scrolling page detail, cover image scrolls at half speed |
| Page reorder drag | interactive spring | — | response=0.2, damping=1.0 | Drag handle or long-press to reorder pages in list |
| Link preview load | crossfade | 0.2s | easeInOut | Link metadata fetched, preview card fades in |

## Media & File Storage Rules

### Cover Images
- One cover image per page: `cover.{jpg|png|heic}` in page folder root
- If no cover exists and `iconName` is set, show SF Symbol in a colored circle
- If neither exists, show gradient placeholder based on workout type color or random pastel
- Cover image is NOT stored in the `media/` subdirectory — it has a dedicated location at page root

### Media Files (Photos & Videos)
- Stored in `{page-folder}/media/` subdirectory
- `mediaFilenames` in manifest stores bare filenames (e.g., `"handstand-progress.jpg"`)
- App resolves full URL at runtime: `{pageFolderURL}/media/{filename}`
- Supported formats: JPEG, PNG, HEIC, GIF, MP4, MOV
- Max video duration: none enforced (user's device storage is the limit)
- Thumbnails generated on demand, cached in app's temp directory

### Markdown Body
- Stored as `guide.md` in page folder root
- Plain CommonMark — no proprietary extensions
- Supports: headers, bold, italic, lists, code blocks, tables, images, links
- On save: manifest.markdownBody = file contents of guide.md (truncated first 500 chars for search index)
- On read: guide.md contents loaded fresh into page detail. Manifest.markdownBody is a cached excerpt for list/search display.

### External Links
- Stored as URL strings in `linkURLs` array
- `linkMetadata` stores pre-fetched preview data (title, description, thumbnail, platform)
- Platform is auto-detected from URL domain:
  - `youtube.com`, `youtu.be` → `.youtube`
  - `instagram.com` → `.instagram`
  - `tiktok.com` → `.tiktok`
  - `facebook.com` → `.facebook`
  - everything else → `.web`
- Link metadata fetched lazily on first view, cached in manifest

## Migration Path

### From ExerciseManifest → ExercisePageManifest
```
ExerciseManifest.id           → ExercisePageManifest.id
ExerciseManifest.name         → ExercisePageManifest.title
ExerciseManifest.details      → ExercisePageManifest.markdownBody (first 500 chars)
ExerciseManifest.duration     → ExercisePageManifest.duration
ExerciseManifest.restAfter    → ExercisePageManifest.restAfter
ExerciseManifest.workoutType  → ExercisePageManifest.workoutType
ExerciseManifest.mediaFilenames → ExercisePageManifest.mediaFilenames
ExerciseManifest.linkURLs     → ExercisePageManifest.linkURLs
ExerciseManifest.sets         → ExercisePageManifest.sets
ExerciseManifest.restBetweenSets → ExercisePageManifest.restBetweenSets
ExerciseManifest.createdAt    → ExercisePageManifest.createdAt
ExerciseManifest.updatedAt    → ExercisePageManifest.updatedAt

NEW FIELDS (with defaults):
coverImageFilename  → nil
iconName            → nil
markdownBody        → expanded from guide.md contents (full file, not just details)
linkMetadata        → []
tags                → []
childIDs            → populated from subdirectory walk
parentID            → determined from directory path
order               → 0
```

### From ExerciseFolder → ExercisePageManifest
```
ExerciseFolder is NOT a manifest — it's a directory without manifest.json.
Migration STEPS:
1. Detect folder directory with no manifest.json
2. Create new ExercisePageManifest for the folder:
   id          → UUID().uuidString (new)
   title       → ExerciseFolder.name
   iconName    → nil (was colorHex — converted to icon fill color)
   childIDs    → IDs of all exercises/subfolders inside this folder (now child pages)
   parentID    → derived from parent directory path
   createdAt   → Date() (no original timestamp available)
   updatedAt   → Date()
   workoutType → ExerciseFolder.workoutType
3. Write manifest.json to folder directory
4. Existing exercises in the folder already have manifest.json — they keep their ID
5. Existing subfolders without manifests ALSO get new manifests created
```

### From DatabaseNote → merged into markdownBody
```
Database notes become part of the markdown body content.
Migration:
1. If page has zero markdownBody and parent folder had notes:
   markdownBody = concatenate all notes with titles as headers:
   "# {note.title}\n\n{note.body}\n\n"
2. Original note timestamps are preserved as YAML frontmatter in guide.md
```

### From TrayItem → NOT migrated
```
TrayItem is a transient UI object (import tray) — no persistence.
No migration needed.
```

### Migration Execution Order
```
MigrationManager.migrateToV2Pages():
1. Walk entire Exercises Database/ directory tree
2. For each directory with manifest.json:
   a. Try decoding as ExerciseManifest (old) → convert to ExercisePageManifest (new)
   b. If already ExercisePageManifest (has markdownBody field) → keep as is
   c. Write updated manifest.json
   d. Ensure guide.md exists with full markdown body
3. For each directory WITHOUT manifest.json:
   a. Create ExercisePageManifest from directory name
   b. Walk its contents: child dirs with manifests get their childIDs recorded
   c. Write manifest.json
4. Update migration marker: UserDefaults "migration_v2_pages_complete" = true
5. Write backup of entire Exercises Database/ to Backups/ before migration starts
```

## Files to Create

| File | Purpose |
|---|---|
| `TimeMasterCore/Sources/Models/ExercisePageManifest.swift` | New manifest model |
| `TimeMaster/Models/ExercisePage.swift` | Runtime model with children, computed properties |
| `TimeMaster/ViewModels/PageTreeBuilder.swift` | Flat→tree conversion utility |

## Files to Modify

| File | Changes |
|---|---|
| `TimeMasterCore/Sources/DatabaseManager.swift` | Add page CRUD (`createPage`, `updatePage`, `deletePage`, `searchPages`, `walkPageTree`, `getPagePath`, `movePage`). Old exercise methods deprecated with `@available(*, deprecated)`. |
| `TimeMasterCore/Sources/MigrationManager.swift` | Add `migrateToV2Pages()` method. V2 migration marker. |
| `TimeMasterCore/Sources/Models/ExerciseManifest.swift` | Mark as deprecated, add `@available(*, deprecated, message: "Use ExercisePageManifest")`. Keep for migration reading. |
| `TimeMaster/ViewModels/DatabaseStore.swift` | Full rewrite: replace `rootFolders`/`rootNotes`/`rootExercises` with `rootPages` + `allPagesFlat`. Replace CRUD methods with page-based equivalents. Replace tree walking with walkPageTree. |
| `TimeMaster/Models/ExerciseDatabase.swift` | Add `ExercisePage` struct. Keep `Exercise`, `ExerciseFolder`, `DatabaseNote`, `MediaItem` marked `@available(*, deprecated)` for backward compatibility during migration. |
| `TimeMasterCore/Sources/Models/SchemaDefinition.swift` | Update `schema.json` to include `ExercisePageManifest` object schema. |

## Files to Archive (after migration complete)

| File | Reason |
|---|---|
| `TimeMasterCore/Sources/Models/ExerciseManifest.swift` | Replaced by ExercisePageManifest |
| `TimeMaster/Models/TrayItem.swift` | No longer needed (import tray will use ExercisePage) |

## Dependencies

- **F09-A (TimeMasterCore)** — must be verified. DatabaseManager, FileSystemHelper, SchemaManager all exist and work. `walkExercises` is the basis for `walkPageTree`. F09-A is verified with evidence (25 tests, macOS arm64, 2026-07-06).
- **F01-A (Migrate models to file manifests)** — must be verified. The V1→file-system migration already runs on app launch. V2 page migration runs after V1 migration completes. F01-A is verified with evidence (14 MigrationTests pass + 49 existing tests, macOS arm64, 2026-07-09).
- **F09-D (AI Tool Calling)** — F06-B depends on the data model. Tool schemas (`create_exercise`, `search_exercises`) must be updated to accept page parameters. This is handled in a later phase.

## Verification

- [ ] ExercisePageManifest encodes/decodes correctly via Codable round-trip test
- [ ] ExercisePageManifest with all optional fields nil encodes without errors
- [ ] LinkMetadata + LinkPlatform encode/decode correctly
- [ ] walkPageTree returns all pages from nested directory structure (5 levels deep)
- [ ] walkPageTree handles empty directories (no manifests) gracefully — returns empty
- [ ] walkPageTree handles corrupt manifest.json — skips that page, continues
- [ ] createPage(id, manifest, parentID:) creates directory + manifest.json + guide.md at correct path
- [ ] createPage with parentID=nil creates at Exercises Database root
- [ ] createPage with parentID creates as subdirectory of parent page folder
- [ ] updatePage updates manifest.json, updates guide.md content, bumps updatedAt
- [ ] movePage changes parent folder on disk, updates manifest.parentID
- [ ] deletePage moves entire page folder (including children + media) to .trash/
- [ ] getPagePath resolves full breadcrumb path (e.g., "Calisthenics/Handstand/Wall Walk")
- [ ] searchPages filters by title, content, workoutType
- [ ] PageTreeBuilder.build() constructs correct tree from flat list with parentID references
- [ ] PageTreeBuilder.breadcrumbs() returns correct ancestor chain
- [ ] DatabaseStore.rootPages loads correctly from walkPageTree
- [ ] DatabaseStore.allPagesFlat contains every page at every depth
- [ ] DatabaseStore.page(id:) returns correct page from flat lookup
- [ ] DatabaseStore.children(of:) returns ordered children
- [ ] Migration: ExerciseManifest → ExercisePageManifest preserves all data (name→title, details→markdownBody, duration, rest, type, media, links, sets)
- [ ] Migration: ExerciseFolder (directory without manifest) → ExercisePageManifest with children populated
- [ ] Migration: DatabaseNote bodies merged into page markdownBody
- [ ] Migration: guide.md created for every page with full markdown content
- [ ] Migration: backup created in Backups/ before migration starts
- [ ] Migration: migration marker prevents re-migration
- [ ] Old ExerciseManifest still readable by deprecated decoder for migration window
- [ ] macOS arm64 build succeeds with all changes
- [ ] All existing tests (63 core tests) pass after migration
- [ ] No data loss: full round-trip — migrate old data → read pages → write pages → read again → identical
