# F17 — Minimalist Text Cleanup

The UI carries too many small explanatory strings ("Move how you feel today / Your day is still open", "This page is empty. Tap Edit to add a guide, media, links, and more.", "Ungrouped", "Tap + to add a folder, note, or exercise.", etc.). The user wants minimalist text — clear, sparse, no chatter. This feature removes secondary/subtitle strings across the app, keeps only the essential labels, and aligns Action button copy with what the user actually expects.

## What We Build

- Audit every view for subtitle/explanatory text strings and classify each as: **keep** (essential label), **shorten** (label can be 1-2 words), or **remove entirely**.
- Remove or shorten the following identified subtitles:
  - Home dashboard — drop "Your day is still open" / "Move how you feel" secondary text; the hero keeps greeting + tagline only; replace today multiple statuses with a single 1-3 word chip (e.g. "Rest day", "Scheduled", "Done", "Open").
  - Page detail "This page is empty. Tap Edit to add a guide, media, links, and more." → remove; show just the small "+" affordance.
  - DatabaseView "Tap + to add a folder, note, or exercise." → remove; toolbar already exposes the action.
  - SettingsView row subtitles ("Export or import all your data", "Customize and create workout categories", "Plays during workouts", "Daily push notifications on training days", "Name exercises from photos with OpenAI", "Seconds added per tap during rest") → remove; the row title alone is clear.
  - WorkoutListView "Tap + to create your first workout" → remove subtitle; "Create Workout" button label is enough.
  - `Recent activity` "Finish a workout and your recent activity will appear here." → shorten to "No activity yet."
  - Empty-state paragraphs are trimmed to one short sentence.
- Keep accessibility labels (`accessibilityLabel`) so VoiceOver users keep context even when the visual subtitle disappears.
- Document the reduced-string style in `STYLES.md` for future consistency.

## Architecture

```
View body
  ├─ Section title        // keep, 1-2 words
  ├─ Subtitle/explanatory // remove unless explicitly allowed
  └─ Action labels        // keep, ≤3 words
```

## States

| State | Before | After |
|---|---|---|
| home "no workout today" | "Your day is still open" + chip | chip only: "Open" |
| home scheduled today | "Move how you feel today." + chip | chip only: "Scheduled" |
| page detail empty | "This page is empty. Tap Edit to add…" | a discreet plus icon, no text |
| database empty | "Tap + to add a folder, note, or exercise." | remove subtitle; the only content is the toolbar + icon |
| settings rows | title + subtitle line | title only |
| workouts empty | "Tap + to create your first workout" | remove; just the title + a CTA button |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| none — pure text removal, layout shifts | — | — |

## Files

- `TimeMaster/Views/Home/HomeDashboardView.swift` — trim hero subtitle + status chip
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — remove empty-content text prompt
- `TimeMaster/Views/Database/DatabaseView.swift` — remove list-empty subtitle
- `TimeMaster/Views/Settings/SettingsView.swift` — remove per-row subtitles
- `TimeMaster/Views/WorkoutList/WorkoutListView.swift` — remove empty subtitle
- `TimeMaster/Views/WorkoutDetail/WorkoutDetailView.swift` — remove empty + caption subtitles
- `STYLES.md` — record the minimalist-text rule

## Dependencies

- None — pure UI pass.

## Reference

- `genesis/ISSUES.md` — "there are too many small text like explanations … text has to me in minimalist style"
- `genesis/REFERENCE/` — none

## Verification

- [ ] Home dashboard hero shows greeting + chip; no explanatory subtitle line
- [ ] Settings rows render title-only; voice-over still speaks the descriptive label
- [ ] Database empty state icon-only with toolbar "+" (no full sentence)
- [ ] Page detail empty state shows at most one short line, never a paragraph
- [ ] Workouts empty state is title + CTA only
- [ ] No layout regression: every removed subtitle slot collapses cleanly
- [ ] macOS + iOS builds succeed
