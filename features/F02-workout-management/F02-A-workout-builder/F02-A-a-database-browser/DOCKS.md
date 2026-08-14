# F02-A-a — Database Browser + Workout Page

Browse the unified database to find exercises, preview them, and view the workout page structure with expandable sections showing sets, rest slots, and sub-exercises.

## What We Build

### Database Browser
- Sheet or embedded view showing ExercisePage tree from DatabaseStore
- Search/filter by title, tags, workout type
- Preview card for each page: cover image, title, tag chips, media count
- Tap a page → quick preview overlay (photo/video, notes summary, link count)
- "Add to Workout" action from preview

### Workout Page Rework
- WorkoutDetailView becomes a Lego builder (see F02-A-b)
- Expandable sections: tap to reveal sets, rest slots, sub-exercises
- Each set shows: exercise name, duration, rest time, rest exercise preview thumbnail
- Indentation: sets indented under section, rest exercises indented under rest slots
- Tap any exercise name → opens full page from database (see F02-A-d)

## States
| Section collapsed | Shows exercise name, mode badge, set count |
| Section expanded | Shows all sets with rest slots, sub-exercises visible |
| Rest slot empty | "Passive rest — 15s" with + button |
| Rest slot filled | Exercise thumbnail + name + duration, tap to change |

## Files
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` (full rewrite)
- `TimeMaster/Views/WorkoutDetail/DBBrowserSheet.swift` (new)
- `TimeMaster/Views/WorkoutDetail/ExercisePreviewCard.swift` (new)
- `TimeMaster/Models/Workout.swift` (modify)

## Verification
- [x] DB browser opens from workout builder and shows root, child, and container pages
- [x] Search/filter by title, markdown, tags, and effective workout type works
- [x] Exercise quick preview shows cover fallback, media count, links, tags, guide summary, and media gallery
- [x] Workout page shows expandable sections with sets and rest slots
- [x] Rest slots show passive state, assigned page, change action, and clear action
- [x] Collapsed/expanded states animate smoothly
- [x] macOS arm64 Debug build succeeds
- [x] iOS Simulator Debug build succeeds and launches on iPhone 16 Pro / iOS 18.6

Evidence: `DatabasePageBrowserSheet` is opened by `WorkoutDetailView`; page selection writes through `WorkoutStore`. The macOS and iOS builds passed on 2026-07-13, the iOS app installed and launched from the generated Debug build, and `TimeMasterCore` passed 67 tests.
