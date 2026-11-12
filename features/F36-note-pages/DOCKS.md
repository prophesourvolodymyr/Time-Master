# F36 — Note Pages

A Note is a page in the Database that holds only a document: a title and Markdown text, rendered like a Notion page, with pictures shown right inside the text. It is the simplest page type: no media strip, no timing, no sets, no skill status, no workout, no children.

## Why It Exists

Everything else in the Database is about doing something: an exercise is performed, a skill is learned, a tutorial is followed. People also keep plain writing next to their exercises: a training plan, a coach's notes, a rules sheet, a diary of a camp week. Until now the only place for that text was the guide of some other page. A Note is the page type whose whole purpose is the text.

## What We Build

- **A new page type, Note**, next to Exercise, Skill and Tutorial. It keeps a title, its Markdown body, its place in the tree, timestamps and an optional icon (an SF Symbol or an emoji). Nothing else is kept.
- **Where a Note may live.** At the top level of the Database or inside a plain folder. It cannot go inside an exercise, a skill or a tutorial: a skill board lists only skills and tutorials, so a note placed there would be invisible. Creating or moving a Note somewhere else is refused with a short explanation.
- **The Note screen.** It opens as a clean reading page: the whole document rendered (headings, bold and italic, links, bulleted, numbered and to-do lists with ticked items struck through, quotes, code blocks, dividers, link cards and pictures). A pencil button swaps in the same block editor used everywhere else (the `/` block menu, the formatting bar, pasted links, inserting a picture). The title is edited in place. There is no Save button: text is saved about three quarters of a second after typing stops, when leaving the screen, when the app goes to the background and when Done is tapped.
- **Pictures.** A picture is added by paste, the image button or the `/` menu. It is stored in the Note's own Attachments folder and written into the text as an ordinary Markdown image, so it shows in the document wherever it was inserted. Tapping a picture in the reading page opens the existing media viewer. Pictures travel with the Note when it is moved, renamed, duplicated, synced between devices, backed up or sent to the trash.
- **Creating a Note.** The Database add menu has New Note: it asks only for a title and opens the new Note straight in the editor. The page sheet also offers Note as a page type; for a Note it shows only the title and the optional icon.
- **In the Database.** A Note is an ordinary page. Its row or card shows its icon (a note glyph by default), its title and a two-line plain-text preview, and it sits among its sibling pages in every list, grid and container screen and in search. There is no Notes-only tab, chip or filter. Notes are never offered where exercises are picked for a workout.
- **Agents.** `create_note_page` creates a Note with a body and local pictures; `get_page` reads it (long bodies in pieces); `update_page` replaces the text; `add_page_note` appends a paragraph; `attach_media` appends a picture; `search_pages` filters by kind `note`; moving and deleting work as for other pages. Notes are not counted as exercises in the library overview or the statistics. A short guide, `skills/write-note.md`, explains it to agents.

## States

| State | What the person sees |
|---|---|
| Empty note | A quiet pencil glyph and a picture-stack glyph, no sentence. Tapping it starts editing. |
| Reading | The rendered document at a comfortable width (about 760 points, centred on a Mac; full width with margins on iPhone; margins grow with the text size). |
| Editing | The block editor with its formatting bar above the keyboard; the navigation arc is hidden so it never covers the bar. |
| Save failed | A red triangle appears in the toolbar; the text stays in memory; tapping the triangle retries. |
| Deleted while open | The screen closes by itself. |
| Note missing | A "Note not found" screen. |
| Offline | Not applicable: everything is local. |

## Interaction Rules

- Pencil toggles reading and editing; edit mode starts with the cursor at the end of the text.
- Escape, back and the system back gesture leave the screen after a final save.
- Keyboard shortcuts of the editor (bold, italic, link, indent) keep working on the Mac.
- Reduce Motion removes the cross-fade between reading and editing.
- VoiceOver reads the rendered document block by block; the pencil is labelled "Edit".

## Limits

- An older build of Tmax cannot read `note` as a page type and will not show the page. This is the cost of a new type; the page is not damaged, and a build with this feature reads it again.
- A picture deleted from the text stays in the Note's Attachments folder until the Note is deleted.
- A Note cannot be placed inside a skill or tutorial.
- Notes appear wherever pages of their container appear; there is nothing special to open or switch to.

## Files

- `TimeMasterCore/Sources/DatabaseManager+Notes.swift` — Note rules and picture handling
- `TimeMasterCore/Sources/Agent/AgentToolRegistry+Notes.swift`, `AgentToolbox+Notes.swift` — agent tools
- `TimeMasterCore/Sources/DatabaseManager+BootstrapNoteSkills.swift` — the agent guide
- `TimeMaster/Views/Database/NotePageView.swift` — the Note screen
- `TimeMaster/Views/Markdown/NotePreview.swift` — the row preview text
- `TimeMaster/ViewModels/DatabaseStore+Notes.swift` — create, save, duplicate

## Dependencies

- F01-B Unified Page Model, F14 Database Hierarchy, F32 Device Sync (pictures travel with the page folder)
- Cycle 52's Markdown editor and renderer

## Reference

- `CYCLES.md` Cycle 52 (global Markdown editor) and Cycle 62 (this feature)
