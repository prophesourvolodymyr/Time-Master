# Phase 1 of F05-A — Database Import, Export & Previews

## Context
Time-Master V1 iOS app. F05-A adds import button, Files app photo picker, ungrouped items root view, tap-to-preview on database photos/videos, and fixes photo export to be referenced-only (not bulk).

## What You Need to Read First
- `features/F05-database-import/F05-A-import-export-previews/DOCKS.md`
- `TimeMaster/Views/Database/DatabaseView.swift` (database browser, export)
- `TimeMaster/Views/Database/DatabaseSectionPickerView.swift` (category picker)
- `TimeMaster/Views/Import/ImportSheetView.swift` (server import flow)
- `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift` (photo picker, files option)
- `TimeMaster/Utilities/BackupManager.swift` (export/import ZIP logic)
- `TimeMaster/Utilities/PhotoManager.swift` (photo storage)
- `TimeMaster/ViewModels/DatabaseStore.swift` (database state)
- `TimeMaster/Models/ExerciseDatabase.swift` (ExerciseFolder, Exercise)
- `TimeMaster/Views/WorkoutDetail/MediaPreviewSheet.swift` (reusable media viewer)

## What Happened Last Session
F04-A completed: streak calendar, rest days, workout goals, partial logging built.

## What to Build

### 1. Import Button
- DatabaseView toolbar: add "Import" button (sf symbol `square.and.arrow.down`) alongside existing export
- Opens `fileImporter` for `.zip` files
- On selection: calls `BackupManager.importBackup(from:workoutStore:databaseStore:)`
- Shows success/error alert after import
- Existing export button stays as-is

### 2. Files Picker for Photos
- SectionEditorView: add "From Files" button alongside existing PhotosPicker and camera
- Opens `fileImporter` with image content types (`[.image, .movie]`)
- On selection: copies file to Documents/Photos with UUID filename, creates MediaItem
- Same flow as PhotosPicker items: thumbnail generation, mediaItems array append

### 3. Ungrouped Items in Database Root
- Exercises imported via server that aren't assigned to a folder/category: appear in a "Ungrouped" section at root of DatabaseView
- Drag from ungrouped into a folder to organize
- Ungrouped exercises show with a subtle "Ungrouped" label badge
- "Ungrouped" section hidden when empty

### 4. Database Photo/Video Preview
- Tap on exercise photo in DatabaseView → presents full-screen MediaPreviewSheet
- Same as existing SectionRow thumbnail tap behavior
- If video: play/pause/seek controls (reuse from MediaPreviewSheet)
- If photo: zoom/pan gestures
- Tap/gesture dismisses, returns to database view

### 5. Photo Export Optimization
- General backup export (BackupManager.createBackup): change from bulk-copying ALL Photos/ files to only exporting referenced media from workouts + database
- Use existing `collectWorkoutMediaFilenames` + new `collectDatabaseMediaFilenames` to build referenced set
- Reduces export size, avoids exporting orphaned media
- Fallback: if referenced file missing on disk, log warning (already done), skip

## Files to Create/Modify
- `TimeMaster/Views/Database/DatabaseView.swift` — import button, ungrouped section, tap preview
- `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift` — files picker button
- `TimeMaster/Utilities/BackupManager.swift` — import button integration, export optimization
- `TimeMaster/ViewModels/DatabaseStore.swift` — ungrouped items query

## Verification
- [ ] Import button visible in DatabaseView, imports ZIP correctly
- [ ] "From Files" option in SectionEditorView photo picker, selects and saves
- [ ] Ungrouped exercises appear in database root
- [ ] Drag ungrouped item into folder works
- [ ] Tap exercise photo in database → full-screen preview
- [ ] Video playback with controls in preview
- [ ] General backup ZIP only includes referenced media (not all Photos/)
- [ ] Photo export works correctly end-to-end
- [ ] compiles without errors

## Agent Rules (Mandatory — DO NOT SKIP)
1. **NO SUB-AGENTS:** Do NOT spawn sub-agents.
2. **COMMIT AFTER DONE:** "feat(F05-A): import button, files picker, ungrouped items, photo preview, export optimization"
3. **NO MORE PROMPTS:** This is the last sub-feature in Cycle 4. Update CYCLES.md to mark F05-A as done, then report completion.
