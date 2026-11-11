import Foundation

extension DatabaseManager {
    func bootstrapMilestoneSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("manage-todos-and-milestones.md"), content: bootstrapTodosContent())
    }

    private func bootstrapTodosContent() -> String {
        return """
# manage-todos-and-milestones
Keep the to-do list and the milestones of a skill or tutorial page. Both lists use the same tools; pass `--list milestone` for milestones (the big cards), leave it out for to-dos.

## Steps
1. `tmax todo_overview` shows every page with open to-dos or milestones, and links whose workout, page or file is gone.
2. `tmax list_todos --page "<Skill/Path>"` reads a list as lines: `[ ]` open, `[x]` done, `## Title` a section, `#1A2B3C4D` the id to pass back, and the page's media numbers.
3. `tmax add_todo --page "<Skill/Path>" --title "<step>"` adds one. Nest it with `--parent "<id or title>"`, place it with `--after` or `--in-section`, or pass `--section true` for a divider that splits the list into parts.
4. Give it a face: `--icon 🥋`, `--color FF6A00`, `--note "<a few lines>"`, `--cover 2` (a media number of the page), `--images 1 --images 3`, `--attachments 4`, `--links https://…`, `--workouts "<workout name>"`, `--pages "<page path>"`. A local picture goes in with `--cover-path /abs/photo.jpg` or `--image-paths /abs/photo.jpg`. Without a cover or icon the entry shows the picture of its first linked workout or page.
5. `tmax check_todo --page "<Skill/Path>" --item "<id or title>"` checks it and everything under it; `--done false` opens it again. `tmax update_todo` changes fields (it also renames a section), `tmax move_todo` reorders or nests (one of `--parent`, `--before`, `--after`, `--in-section`, `--indent true`, `--outdent true`), `tmax remove_todo` deletes after the user approves.

## Example
`tmax add_todo --page "Wrestling/Single leg" --list milestone --title "Hit it live in sparring" --workouts "Single-leg bundle" --color FF6A00`
"""
    }
}
