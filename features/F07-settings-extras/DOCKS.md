# F07 — Settings & Extras

App settings, backup/restore, background music, motivational quotes, notifications, and workout reminders.

## What We Build
- SettingsView: navigation hub linking to all settings sub-screens
- BackupView: export/import full app data as ZIP
- BackupManager: serialize all workouts + photos + history → ZIP, restore from ZIP
- MusicManager: background music playback during workouts (local files)
- MusicSettingsView: music library browser, playback controls
- MotivationManager: motivational quote display during rest periods
- MotivationSettingsView: quote category selection, frequency
- NotificationManager: local notification scheduling/management
- WorkoutRemindersView: schedule recurring workout reminders

## Architecture
```
Views/Settings/
├── SettingsView.swift            — Settings nav: Backup, Music, Motivation, Notifications, AI
├── BackupView.swift              — Export/Import/Delete backups
├── MusicSettingsView.swift       — Music library browser
├── MotivationSettingsView.swift  — Quote preferences
├── WorkoutRemindersView.swift    — Reminder scheduling
└── ExerciseAISettingsView.swift  — AI naming config (shared with F06)

Utilities/
├── BackupManager.swift           — ZIP export/import (ZIPFoundation)
├── MusicManager.swift            — AVAudioPlayer wrapper
├── MotivationManager.swift       — Quote database + display logic
└── NotificationManager.swift     — UNUserNotificationCenter wrapper
```

## Files
- `TimeMaster/Views/Settings/SettingsView.swift`
- `TimeMaster/Views/Settings/BackupView.swift`
- `TimeMaster/Views/Settings/MusicSettingsView.swift`
- `TimeMaster/Views/Settings/MotivationSettingsView.swift`
- `TimeMaster/Views/Settings/WorkoutRemindersView.swift`
- `TimeMaster/Views/Settings/ExerciseAISettingsView.swift`
- `TimeMaster/Utilities/BackupManager.swift`
- `TimeMaster/Utilities/MusicManager.swift`
- `TimeMaster/Utilities/MotivationManager.swift`
- `TimeMaster/Utilities/NotificationManager.swift`

## Dependencies
- F01 — Core Data Layer (WorkoutStore, Theme)

## Verification
- [x] SettingsView navigates to all sub-screens
- [x] Backup export creates valid ZIP with all data + photos
- [x] Backup import restores workouts, photos, history correctly
- [x] Background music plays during workouts, mute toggle works
- [x] Motivational quotes display during rest periods
- [x] Workout reminders schedule and fire as local notifications
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
