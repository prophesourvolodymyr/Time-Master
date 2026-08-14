# F02-A-c — Bundle Section Mode

Bundle sections in the player show technique cards one at a time. User completes the work at their own pace, swipes to next, or taps deeper to open the full database page. No forced timer.

## What We Build

### Bundle Player UX
- Bundle section starts → first technique card appears full-screen
- Card shows: cover image/video, technique name, notes summary, tags
- **Inline preview:** tap card → quick media preview (photo zoom / video play) within card
- **Deep open:** tap "Open Page" or long-press → opens full ExercisePage from DB with floating player controls (F02-A-d)
- **Next:** swipe left or tap "Next" button to advance to next technique in bundle
- **Previous:** swipe right to go back
- **Reorder visible:** player allows reordering bundle items mid-workout (drag handle or edit button)
- **Progress:** dots or "3/8" indicator at bottom showing position in bundle
- **Self-paced:** no countdown timer — user decides when to move on
- Section complete indicator shown after last bundle item

### Bundle Section Setup (from F02-A-b)
- Builder shows list of picked exercises
- Reorderable via drag
- Add/remove items from DB browser
- Each bundle item can have optional rest after

## States
| Phase | UI |
|-------|----|
| Bundle active | Full card: photo/video, name, notes, "Next →" button, position dots |
| Inline preview | Media zooms/video plays within card, tap again to close |
| Deep open | Full ExercisePage overlay with floating timer controls (F02-A-d) |
| Reorder mode | List of bundle items with drag handles, "+" to add from DB |
| Bundle complete | "Section Done" indicator, auto-advance to next section or rest |

## Files
- `TimeMaster/Views/Player/WorkoutPlayerView.swift` (add bundle mode)
- `TimeMaster/Views/Player/BundleCardView.swift` (new)
- `TimeMaster/Views/Player/BundleReorderSheet.swift` (new)

## Verification
- [x] Bundle section starts with first technique card
- [x] Card shows cover image, name, notes, and position count
- [x] Inline preview: expand the card to show the page media gallery; tap media for full-screen playback
- [x] Deep open: opens the full `ExercisePageOverlay` with floating controls
- [x] Swipe left/right navigates between bundle items
- [x] Reorder mid-workout: reorder sheet writes the new order to the workout store
- [x] Bundle section completes after the last item
- [x] macOS arm64 Debug build succeeds
- [x] iOS Simulator Debug build succeeds

Evidence: `WorkoutPlayerView` routes bundle sections to the self-paced card flow and persists reorder changes through `WorkoutStore`. Both app targets compiled on 2026-07-13 and the iPhone 16 Pro Simulator app launched successfully.
