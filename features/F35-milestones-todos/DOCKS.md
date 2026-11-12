# F35 — Milestones and To-dos

A skill or tutorial page can carry a nested To-do list and a Milestones grid. Both come from the latest To-do and Milestones of the Skillmax app and keep its behaviour, with Tmax additions: section dividers, icons, covers, pictures, attachments, and links to workouts and pages whose picture is borrowed when the entry has none of its own.

## Why It Exists

A person who collects and performs workouts learns skills over weeks: a takedown, a drill chain, a position. A page already holds the exercise's notes, media and workout configuration. Milestones add the path through the skill (what to be able to do next, in order), and the To-do list holds the small tasks (drill this, film that, ask the coach). Linking an entry to a workout lets the person start the drill from the list; linking to another page opens the lesson. Agents can keep both lists for the person.

## Where It Lives

- Skill pages and tutorial pages show **To-do**, then **Milestones**, right after "Learn first".
- Groups (containers) show neither.
- Reference: Skillmax's To-do and Milestones were read as a pattern (read-only project in `Next:Open/skillmax`); field names stay compatible and Tmax adds its own fields only when they are used.

## The To-do List

- **Entries** nest: swipe right (iPhone) or Tab (Mac) to indent, swipe left or Shift-Tab to outdent. Return keeps the next line ready to type.
- **Checking a parent** checks everything under it.
- **Deleting** an entry that has children asks first.
- **Section dividers.** A section is a centred title between two hairlines. Tapping the title renames it in place. Its menu moves, edits or deletes it. A "+ section" button sits next to the add field: a new section takes what is typed, or starts renaming "New section".
- **Row extras.** Each row can show an icon (tap it to change it), a note, a strip of pictures and link chips.
- **Link chips.** A workout chip has its own play button that starts the workout; a page chip opens the page; a file chip opens the media viewer; a web chip opens its address.
- **Section header.** A progress ring, an orange badge with what is still open, a small done count, an options menu (hide what is done, add a section) and a plus button that opens the editor.

## Pictures From Links

An entry with no cover or icon of its own takes the picture of the first workout or page it links to. A linked workout is drawn the way the workout list draws it (its mosaic) with a small play mark. An entry's own cover or icon always wins.

## Milestones

- **Cards.** A large card: the cover across the top, the icon hanging over its edge, a check on the cover, the note, pictures, link chips, and sub-milestones as rows with a progress bar.
- **Sections.** A divider runs the full width between groups of cards.

## The Editor Sheet

- A live preview at the top (the cover, icon and title as they will look), then title, note, cover, pictures, icon, colour and links.
- Links come from a workout picker, a page picker, the page's own files, or a web address. Pictures come from the page's own pictures, Photos, or Files.
- Cancel asks before throwing changes away and swiping the sheet down is blocked while there are changes.

## The Pickers

Both the workout picker and the page picker are searchable grids of covers with a check on what is already linked.

## States

| State | What the person sees |
|---|---|
| Empty list | One icon and one short line |
| Everything done or reached | One icon and one short line |
| Save failed | A small banner that fades out; the list stays usable |
| Link to something deleted | An amber "missing" chip |
| Picture file not on this device | A marked tile |
| Edited by an agent or another device | The list refreshes when the app returns to the front; the Mac also watches the library folder |

## Deep Links

`timemaster://page/<id>` opens the page in the Database tab; `timemaster://workout/<id>` opens the workout. The earlier start and detail links work as before.

## Agents

- Tools: `todo_overview`, `list_todos`, `add_todo`, `update_todo`, `check_todo`, `move_todo`, `remove_todo`. For milestones the same tools take a list switch.
- A short guide, `skills/manage-todos-and-milestones.md`, explains the lists to agents.
- The in-app Coach reloads the library after every tool call, so the lists change on screen at once.
- The on-device helper may add and tick off to-dos. This is a decision the person should confirm.

## Data and Sync

- A page stores its to-dos and milestones with its manifest; entries have stable ids so Device Sync merges them entry by entry.
- Limits: to-dos nest 8 deep and hold up to 500 entries; milestones nest 4 deep and hold up to 200; an entry has up to 12 links and 6 pictures.
- An entry's pictures are page media: they also appear in the page's Files section, and the first one becomes the page's cover if the page had no media.
- A file removed from the page is cleaned out of the lists.

## Limits

- There is no drag-and-drop reordering; order changes through the menus (Move up, Move down), Tab and Shift-Tab, swipes and the agent's move tool.
- List writes are not locked: the page edit sheet can overwrite list changes made while it was open.
- Files in the old shared media folder that are renamed during a backup restore drop out of the lists.

## Files

- `TimeMaster/Views/Database/Milestones/` — all list, card, editor, picker and chip views
- `TimeMaster/ViewModels/DatabaseStore+Milestones.swift` — store bridge
- `TimeMaster/Views/Database/ExercisePageDetailView.swift` — the one hook that shows the two sections
- `TimeMasterCore/Sources/Models/ChecklistEntry.swift`, `Todo.swift`, `Milestone.swift`, `TmaxLink.swift`
- `TimeMasterCore/Sources/DatabaseManager+Checklists.swift`, `DatabaseManager+BootstrapMilestoneSkills.swift`
- `TimeMasterCore/Sources/Agent/AgentToolRegistry+Milestones.swift`, `AgentToolbox+Milestones.swift`

## Dependencies

- F01-B Database Hierarchy and data model, F09 File-Based Data Architecture (Core), F14 Database Hierarchy Model, F31 Agent Bridge (tools), F32 Device Sync, F33 (workout links start the player)

## Reference

- `CYCLES.md` Cycle 62; Skillmax's To-do and Milestones (pattern, read-only)
