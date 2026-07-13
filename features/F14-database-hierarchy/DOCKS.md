# F14 — Database Hierarchy Model (root container vs leaf exercise)

The exercise database is currently monolithic: every page can be configured with cover, tag, duration, sets, reps, rests — but per the design only **container** pages should accept cover + tag (a placeholder that holds workouts), and only **exercise leaf** pages should accept the workout config (duration, sets, reps, rest). Containers can also hold other containers, giving the user unlimited divide + organization + customization. Sub-folder cover image is taken from the first media item uploaded to that sub-folder if no explicit cover is set, so the leaf creation form must hide the cover-photo uploader. The AI tool-calling schema must reflect this distinction so AI agents cannot create malformed pages.

## What We Build

- A clear page-type enum on `ExercisePageManifest`: `.container` (can hold pages) and `.leaf` (an exercise — no children). The existing `isContainer` / `isLeaf` booleans become a stored enum.
- `PageCreationSheet` and `PageEditSheet` show different form sections based on type:
  - **Container** form: title, icon, cover image (optional), tags, workout-type tag. No duration/sets/reps/rest fields. No media-uploader. No markdown guide required (but allowed).
  - **Leaf (exercise)** form: title, icon (optional), workout-type tag, duration + sets + reps + rest + rest-between-sets, markdown guide, external links, tags, media uploader NO cover photo field — cover derives from first uploaded media.
- Sub-folder (container-of-container) creation allowed to unlimited depth. Existing tree already supports it; UI parity must confirm it.
- `ExercisePage.coverImageURL` for a leaf with no explicit cover returns the first item in `mediaFilenames` (so leaf cards always show a thumbnail).
- `ExercisePage.coverImageURL` for a container honors the explicit `coverImageFilename` only.
- AI tool-calling schema (`schema.json` and `F09-D` tool definitions) gets two distinct tools:
  - `create_container_page` — accepts title, icon, cover, tags, workoutType. Rejects duration/sets.
  - `create_exercise_page` — accepts title, duration, sets, reps, rest, markdown, links, tags, media. Rejects cover. Requires parentID (parent must be a container).
- `update_page` tool validates the same constraints.
- Migration: existing pages that have `duration` set but `isContainer == true` get split — duration moves into a single child exercise page; container keeps only cover + tag.

## Architecture

```
ExercisePageManifest
  ├─ kind: PageKind  // .container | .leaf
  ├─ title, iconName, tags
  ├─ workoutType?
  ├─ coverImageFilename?     // only used by containers
  ├─ markdownBody             // both
  ├─ linkURLs, linkMetadata   // both (more common for leaves)
  ├─ mediaFilenames           // both; for leaves, first element drives the cover
  └─ duration?, sets?, reps?, restAfter?, restBetweenSets?  // leaves only
```

```
PageCreationSheet
  ├─ if creating container:
  │    fields: title, icon, cover, tags, workoutType
  │    hidden: duration/sets/reps/rest/media
  └─ if creating leaf:
       fields: title, icon(optional), workoutType, duration, sets, reps, rest, markdown, links, tags, media
       hidden: cover
```

```
CreateContainerPageSchema (AI tool)
  required: title, kind:"container"
  optional: iconName, coverImageFilename, tags, workoutType, markdownBody
  rejects: duration, sets, reps

CreateExercisePageSchema (AI tool)
  required: title, kind:"leaf", duration, parentID
  optional: sets, reps, restAfter, restBetweenSets, markdownBody, linkURLs, tags, mediaFilenames, workoutType, iconName
  rejects: coverImageFilename
```

## States

| State | Container page | Leaf (exercise) page |
|---|---|---|
| creation form | cover + tag enabled | duration + sets + reps + rest + media + markdown enabled |
| detail hero | explicit cover, or workout-type icon, or `folder.fill` | first-media thumbnail, or workout-type icon |
| shows "Child Pages" section | yes | no |
| shows "Workout Config" badge | no | yes |
| shows "Add to Workout" toolbar button | no | yes |
| AI creation tool | `create_container_page` | `create_exercise_page` |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| form mode swap (container ↔ leaf) | 0.2s ease-out | toggle in creation sheet |
| cover thumbnail fallback | none | leaf with no cover first media uploaded |

## Files

- `TimeMaster/Models/ExercisePage.swift` — `PageKind` enum, decoding legacy fallback
- `TimeMasterCore/Sources/TimeMasterCore/Models/ExercisePageManifest.swift` — schema kinds
- `TimeMaster/Views/Database/PageCreationSheet.swift` — split form by kind
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — hide workout config on containers, hide "Add to Workout" on containers
- `TimeMaster/Views/Database/PageCardView.swift` — leaf cover = first media fallback
- `TimeMasterCore/Sources/TimeMasterCore/Schema/schema.json` — two distinct create tools, validation rules
- `TimeMaster/ViewModels/ToolRouter.swift` — reject out-of-kind fields per tool
- `TimeMaster/ViewModels/DatabaseStore.swift` — validation gate for createPage / updatePage

## Dependencies

- F09-D — AI tool calling already exists, schema update is in place
- F01-B — Unified page model already exists

## Reference

- `genesis/ISSUES.md` — "initial page that you created inside of the database space is always the mass for the X exercise itself"
- `genesis/REFERENCE/` — none

## Verification

- [ ] New container page form has NO duration/sets/reps/rest/media fields
- [ ] New leaf page form has NO cover-photo uploader
- [ ] Leaf with no explicit cover but with one uploaded media shows that media as the cover
- [ ] Container with no cover and no workoutType shows `folder.fill` icon hero
- [ ] Container can hold another container (`Add Child Page` works on a container)
- [ ] `create_container_page` AI tool rejects a call that includes `duration`
- [ ] `create_exercise_page` AI tool rejects a call that includes `coverImageFilename`
- [ ] Migration: existing malformed pages either split or get correctly typed
- [ ] macOS build + iOS build succeed; all core tests pass
