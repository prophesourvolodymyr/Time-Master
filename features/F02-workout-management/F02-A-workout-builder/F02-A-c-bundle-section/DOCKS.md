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
- [ ] Bundle section starts with first technique card
- [ ] Card shows cover image, name, notes, position dots
- [ ] Inline preview: tap card → photo/video previews inline
- [ ] Deep open: opens full ExercisePage with floating controls
- [ ] Swipe left/right navigates between bundle items
- [ ] Reorder mid-workout: drag items, changes persist
- [ ] Bundle section completes after last item
- [ ] compiles without errors
