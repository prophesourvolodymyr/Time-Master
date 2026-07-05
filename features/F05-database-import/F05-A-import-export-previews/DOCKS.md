# F05-A — Import, Export & Previews

Import button, Files picker for photos, ungrouped items root view, database photo preview, and photo export fix.

## 1. Import Button
- DatabaseView: add "Import" button alongside existing "Export"
- Opens file picker to import previously exported database ZIP archives

## 2. Files Picker for Photos
- SectionEditorView: add "From Files" option alongside camera and photo library
- Allows selecting images from Files app / iCloud Drive

## 3. Ungrouped Items Root
- Exercises added via import that aren't assigned to a workout category appear in database root
- Can be dragged into categories/folders later
- Root view shows all unassigned items as a flat list

## 4. Database Photo Preview
- Tap on exercise photo in DatabaseView → full-screen preview overlay
- Video: play/pause/seek controls
- Photo: zoom/pan gestures
- Tap/gesture dismisses

## 5. Photo Export Fix (Critical)
- BackupManager: when exporting backup or database workout, include photo files in ZIP
- On import/restore, extract photos back to Documents directory
- Photos must be bundled with JSON data, not referenced externally

## Files
- `TimeMaster/Views/Database/DatabaseView.swift`
- `TimeMaster/Views/WorkoutDetail/SectionEditorView.swift`
- `TimeMaster/Utilities/BackupManager.swift`
- `TimeMaster/Utilities/PhotoManager.swift`

## Verification
- [ ] Import button visible, imports ZIP and restores data + photos
- [ ] "From Files" option in photo picker, selects and saves correctly
- [ ] Ungrouped items appear in database root, can be organized later
- [ ] Tap photo in database → full-screen preview with video/photo controls
- [ ] Backup ZIP includes all photos, restore extracts them correctly
- [ ] Database per-workout export includes photos
