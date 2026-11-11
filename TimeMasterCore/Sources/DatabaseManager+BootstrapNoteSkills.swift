import Foundation

extension DatabaseManager {
    func bootstrapNoteSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("write-note.md"), content: bootstrapWriteNoteContent())
    }

    private func bootstrapWriteNoteContent() -> String {
        return """
# write-note
Write a note page: a title and a Markdown document with pictures inside the text. Notes are not exercises and never go into workouts.

## Steps
1. `tmax search_pages --query "<title>" --kind note` to see whether the note already exists.
2. `tmax create_note_page --title "<title>" --parent "<Folder/Path>" --markdown-body "# Heading\\n\\n- [ ] first to-do" --images /abs/photo.jpg`. The app copies each picture into the note and shows it after the text. Omit `--parent` for the top level. Notes cannot live inside exercises, skills or tutorials.
3. `tmax add_page_note --page "<id or path>" --note "<more text>"` appends a paragraph; `tmax update_page --page "<id or path>" --markdown-body "<whole new document>"` replaces everything.
4. `tmax attach_media --page "<id or path>" --path /abs/photo.png` adds a picture at the end of a note.
5. `tmax get_page --page "<id or path>"` reads the document; long ones come back in pieces, pass `--body-offset` from `nextOffset` to read on.

Markdown the app renders: `#` headings, `-` and `1.` lists, `- [ ]` / `- [x]` to-dos, `>` quotes, fenced code, `---`, links, and `![](<Attachments/file.jpg>)` pictures.
"""
    }
}
