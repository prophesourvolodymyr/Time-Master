# F01 — Core Data Layer

Foundation data models, persistence stores, photo management, and design tokens for the entire app.

## V2 / Migration
- [ ] **F01-A** — Migrate models from UserDefaults to file-based manifests (after F09-A TimeMasterCore is built)
- [ ] **F01-B** — Unified Page Model (ExercisePage replaces Folder/Exercise/TrayItem, Cycle 6)

## ⚠️ F09 Migration Note
When F09-A is built, WorkoutStore and DatabaseStore will be replaced by TimeMasterCore.DatabaseManager. Existing data will be migrated via MigrationManager. All model structs (Workout, Section, Exercise, etc.) will get file-based counterparts with the same field names for backward compatibility.

## What We Build
- Workout/Section/WorkoutHistory Swift structs (Codable)
- ExerciseDatabase and TrayItem models for import system
- WorkoutStore: ObservableObject singleton for CRUD on workouts
- DatabaseStore: manages imported exercise tray database
- PhotoManager: save/load/delete photos from app Documents directory
- Theme: centralized color palette, typography, spacing tokens
- KeychainHelper: secure storage for API keys

## Architecture
```
Models/
├── Workout.swift          — Workout (id, name, sections[]) + Section (id, name, duration, imageFilename, color)
├── WorkoutHistory.swift   — Completed workout log entry
├── ExerciseDatabase.swift — Categorized exercise library from imports
└── TrayItem.swift         — Individual imported exercise with video asset

ViewModels/
├── WorkoutStore.swift     — @MainActor ObservableObject, CRUD, JSON persistence to UserDefaults
├── DatabaseStore.swift    — @MainActor ObservableObject, manages imported exercise tray
├── AIProvider.swift       — Protocol + provider registry (25 providers, 7 groups)
├── AIStore.swift          — Manages AI coach conversations
└── VideoEditorViewModel.swift — Video trimming/review state

Utilities/
├── PhotoManager.swift     — UUID-named photo files in Documents/
├── Theme.swift            — Color palette (#FF6B35 primary, #1A1A2E secondary, #4ECDC4 accent)
├── KeychainHelper.swift   — Secure API key get/set/delete
└── ExerciseNamingService.swift — AI-powered exercise name suggestions
```

## Files
- `TimeMaster/Models/Workout.swift`
- `TimeMaster/Models/WorkoutHistory.swift`
- `TimeMaster/Models/ExerciseDatabase.swift`
- `TimeMaster/Models/TrayItem.swift`
- `TimeMaster/ViewModels/WorkoutStore.swift`
- `TimeMaster/ViewModels/DatabaseStore.swift`
- `TimeMaster/ViewModels/AIProvider.swift`
- `TimeMaster/ViewModels/AIStore.swift`
- `TimeMaster/ViewModels/VideoEditorViewModel.swift`
- `TimeMaster/Utilities/PhotoManager.swift`
- `TimeMaster/Utilities/Theme.swift`
- `TimeMaster/Utilities/KeychainHelper.swift`
- `TimeMaster/Utilities/ExerciseNamingService.swift`

## Dependencies
None — this is the foundation.

## Verification
- [x] Models compile, Codable round-trip works
- [x] WorkoutStore CRUD persists across app launches (UserDefaults JSON)
- [x] PhotoManager saves/loads/deletes photos correctly
- [x] KeychainHelper stores/retrieves/deletes API keys
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
