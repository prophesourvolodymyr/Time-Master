# Time-Master

## 1. Overview

**App Name:** Time-Master
**Platform:** iOS (SwiftUI)
**Bundle Identifier:** com.timemaster.app
**Core Functionality:** Section-based workout timer where users create custom workout routines with multiple exercises (sections), each with a name, duration, and custom photo. Run the entire workout with one tap.
**Target Users:** Fitness enthusiasts who want seamless, photo-guided workout timers without manually setting timers for each exercise.

---

## 2. UI/UX Specification

### Screen Structure

1. **WorkoutListView** – Main screen showing all created workouts
2. **WorkoutDetailView** – View/edit a workout's sections
3. **SectionEditorView** – Add/edit a single section (name, duration, photo)
4. **WorkoutPlayerView** – Active workout with timer and photo display
5. **HistoryView** – Completed workout log

### Navigation Structure

- `TabView` with 2 tabs:
  - **Workouts** (WorkoutListView)
  - **History** (HistoryView)
- `NavigationStack` for drill-down

### Visual Design

**Color Palette:**
- Primary: `#FF6B35` (Energetic Orange)
- Secondary: `#1A1A2E` (Dark Navy)
- Accent: `#4ECDC4` (Teal)
- Background: `#0F0F1A` (Near Black)
- Surface: `#1F1F35` (Card Dark)
- Text Primary: `#FFFFFF`
- Text Secondary: `#A0A0B0`

**Typography:**
- Font: System (SF Pro Rounded)
- Large Title: 34pt Bold
- Title: 28pt Bold
- Headline: 17pt Semibold
- Body: 17pt Regular
- Caption: 12pt Regular

**Spacing (8pt grid):**
- Screen padding: 16pt
- Card padding: 16pt
- Item spacing: 12pt
- Section spacing: 24pt

### Views & Components

**WorkoutListView:**
- Navigation title: "Workouts"
- List of workout cards (name, section count, total duration)
- Floating "+" button to add workout
- Swipe to delete

**WorkoutCard:**
- RoundedRectangle (16pt corner)
- Background: Surface color
- Workout name (Headline)
- Section count (Caption, Text Secondary)
- Total duration (Caption, Accent)

**WorkoutDetailView:**
- Navigation title: Workout name
- Edit button (top right)
- List of sections (photo thumbnail, name, duration)
- Drag handles for reordering
- "+" button to add section
- "Start Workout" button (full-width, Primary color, bottom)

**SectionRow:**
- HStack: Photo thumbnail (60x60, rounded 12pt), VStack(name, duration)
- Swipe actions: Edit, Delete

**SectionEditorView:**
- Form with:
  - Photo picker (camera or gallery)
  - TextField: Section name
  - Stepper: Duration (5-300 seconds, 5 sec increments)
  - Color picker (optional highlight)
- Save button

**WorkoutPlayerView:**
- Full-screen photo display (aspect fill, darkened overlay)
- Exercise name (Large Title, centered top)
- Timer countdown (120pt Bold, centered)
- Progress bar (bottom)
- Pause/Resume button
- Stop button (top right)
- Rest timer screen between exercises (Teal background)

**HistoryView:**
- Navigation title: "History"
- List of completed workouts
- Each row: Workout name, date/time, duration completed
- Swipe to clear

---

## 3. Functionality Specification

### Core Features

**P0 - Must Have:**
1. Create/Edit/Delete workouts
2. Add/Edit/Delete sections within workouts
3. Upload photo for each section (camera or photo library)
4. Set section name and duration
5. One-tap workout start → sequential sections with timers
6. Auto-advance between sections
7. Pause/Resume workout

**P1 - Should Have:**
8. Configurable rest period between sections (default: 10 sec)
9. Audio cues: countdown beeps (3-2-1), exercise name announcement
10. Workout history log with timestamp and duration

**P2 - Nice to Have:**
11. Drag-and-drop section reordering
12. Clone workout as template
13. Default rest toggle per section

### User Flows

**Create Workout:**
1. Tap "+" on WorkoutListView
2. Enter workout name → Save
3. Navigate to WorkoutDetailView
4. Tap "+" to add sections
5. Fill name, duration, pick photo → Save
6. Repeat step 4-5 for more sections
7. Tap "Start Workout"

**Run Workout:**
1. Tap "Start Workout" button
2. Display first section photo + name + timer
3. Timer counts down
4. At 3 seconds: audio countdown
5. At 0: show rest screen (if enabled) or advance
6. Show next section → repeat
7. On completion: show "Done" + log to history

### Data Handling

- **Storage:** UserDefaults (JSON encoded) for workouts + photo references
- **Photos:** Saved to app's Documents directory with UUID filenames
- **History:** UserDefaults (JSON encoded)

### Architecture

- **MVVM Pattern**
- `WorkoutModel` (Codable struct)
- `SectionModel` (Codable struct)
- `WorkoutStore` (ObservableObject, singleton)
- `WorkoutPlayer` (ObservableObject, manages timer state)

### Edge Cases & Error Handling

- No sections: Disable "Start" button, show empty state
- No photo: Show placeholder (white silhouette)
- 0 duration: Minimum 5 seconds enforced
- App backgrounded during workout: Continue timer (background audio)
- Delete workout with history: Keep history entry

---

## 4. Technical Specification

### Dependencies

- No external dependencies required (pure SwiftUI)

### UI Framework

- **SwiftUI** with iOS 16+ features ( PhotosPicker, NavigationStack)

### Asset Requirements

- **App Icon:** 1024x1024 (orange timer graphic)
- **Placeholder Image:** SF Symbol `figure.run` as fallback
- **Sound Files:** System sounds for beeps (or AudioServicesPlaySystemSound)

### File Structure

```
TimeMaster/
├── App/
│   └── TimeMasterApp.swift
├── Models/
│   ├── Workout.swift
│   ├── Section.swift
│   └── WorkoutHistory.swift
├── ViewModels/
│   ├── WorkoutStore.swift
│   └── WorkoutPlayer.swift
├── Views/
│   ├── MainTabView.swift
│   ├── WorkoutList/
│   │   ├── WorkoutListView.swift
│   │   └── WorkoutCard.swift
│   ├── WorkoutDetail/
│   │   ├── WorkoutDetailView.swift
│   │   ├── SectionRow.swift
│   │   └── SectionEditorView.swift
│   ├── Player/
│   │   ├── WorkoutPlayerView.swift
│   │   └── RestView.swift
│   └── History/
│       └── HistoryView.swift
├── Utilities/
│   ├── PhotoManager.swift
│   └── AudioManager.swift
├── Resources/
│   └── Assets.xcassets
└── Info.plist
```

---

## 5. Phases

### Phase 1: Data Models
- Workout, Section structs (Codable)
- PhotoManager for saving/loading photos from Documents
- WorkoutStore for CRUD operations

### Phase 2: Workout Management
- WorkoutListView (CRUD)
- WorkoutDetailView (add/edit/delete sections)
- SectionEditorView with PhotosPicker
- Drag-and-drop reordering
- Clone workout

### Phase 3: Timer Engine
- WorkoutPlayer with Timer
- Sequential section execution
- Rest timer between sections
- Pause/Resume
- Audio countdown cues

### Phase 4: History Tracking
- HistoryView
- Log completed workouts
- Clear history

### Phase 5: UI Polish
- App icon
- Launch screen
- Animations (progress bar, transitions)
- Empty states