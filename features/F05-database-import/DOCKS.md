# F05 — Database Import

Import exercise videos and metadata from a computer server. Browse, preview, trim, and batch import into the exercise database.

## What We Build
- DatabaseView: browse imported exercises with category filtering
- DatabaseSectionPickerView: picker for categorizing imported items
- ImportSheetView: connect to server, browse available tray items
- BatchConfirmView: review and confirm batch import
- TrayCardView: card displaying imported exercise with thumbnail
- VideoEditorView: trim video clips before import
- DatabaseStore: manages imported exercise tray state
- ServerDiscovery: Bonjour/mDNS network discovery of Python server
- VideoDownloadService: download videos from server
- VideoTrimService: trim downloaded videos

## Architecture
```
Views/Import/
├── ImportSheetView.swift       — Server connection, browse tray, select items
├── BatchConfirmView.swift      — Review selected items, confirm import
├── TrayCardView.swift          — Exercise card with thumbnail, name, duration
├── VideoEditorView.swift       — AVPlayer-based trim interface
└── ServerSettingsView.swift    — Server URL/IP configuration

Views/Database/
├── DatabaseView.swift           — Browse imported exercises, search, filter
└── DatabaseSectionPickerView.swift — Category assignment picker

Services/
├── ServerDiscovery.swift        — Network service discovery
├── VideoDownloadService.swift   — HTTP video download with progress
└── VideoTrimService.swift       — AVAssetExportSession trim

Models/
├── ExerciseDatabase.swift       — Categorized exercise library
└── TrayItem.swift               — Import candidate item

ViewModels/
└── DatabaseStore.swift          — Import tray state management
```

## Files
- `TimeMaster/Views/Database/DatabaseView.swift`
- `TimeMaster/Views/Database/DatabaseSectionPickerView.swift`
- `TimeMaster/Views/Import/ImportSheetView.swift`
- `TimeMaster/Views/Import/BatchConfirmView.swift`
- `TimeMaster/Views/Import/TrayCardView.swift`
- `TimeMaster/Views/Import/VideoEditorView.swift`
- `TimeMaster/Views/Import/ServerSettingsView.swift`
- `TimeMaster/Services/ServerDiscovery.swift`
- `TimeMaster/Services/VideoDownloadService.swift`
- `TimeMaster/Services/VideoTrimService.swift`
- `TimeMaster/Models/ExerciseDatabase.swift`
- `TimeMaster/Models/TrayItem.swift`
- `TimeMaster/ViewModels/DatabaseStore.swift`
- `server.py` (companion Python server)
- `start_server.command` (server launcher)

## Dependencies
- F01 — Core Data Layer (DatabaseStore, ExerciseDatabase, TrayItem, Theme)

## Verification
- [x] Python server starts and broadcasts via Bonjour
- [x] ImportSheetView discovers server and lists available tray items
- [x] VideoEditorView allows trimming before import
- [x] BatchConfirmView shows selected items, confirms import
- [x] Imported exercises appear in DatabaseView with categories
- [x] Video playback works in exercise preview
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
