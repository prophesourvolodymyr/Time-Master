import Foundation

extension DatabaseManager {
    func bootstrapSkillPageSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("write-skill-pages.md"), content: bootstrapWriteSkillPagesContent())
    }

    private func bootstrapWriteSkillPagesContent() -> String {
        return """
# write-skill-pages
Build a skill tree: skills to learn, grouped on a board, each with notes, many video clips and sub-pages.

## The shape
- A **root folder** (`create_container_page`) is the board. Its **groups** sort the skills (`create_skill_group`, or just pass `--group` when creating a skill).
- A **skill** (`create_skill_page`) is something you learn and progress in. It keeps Markdown notes, up to 100 clips or pictures with a Markdown comment each, links, and sub-pages. A skill inside a skill is a sub-skill and sits on that skill's own board.
- **Sub-pages** of a skill can be exercises (`create_exercise_page --parent "<Skill/Path>"`), notes (`create_note_page --parent "<Skill/Path>"`), more skills, or folders. An exercise or a note cannot hold sub-pages.

## Steps
1. `tmax search_pages --query "<skill>" --kind skill` first, so the same skill is not made twice; reuse it with `--if-exists reuse`.
2. `tmax create_skill_page --title "Arm Drag" --parent "Wrestling" --group "Hand Fighting & Setups" --markdown-body "<notes>" --link-urls https://… --json` with `media` as `[{"path":"/abs/clip.mp4","comment":"Source and what it shows"}]`. The first media item is the cover.
3. Put what belongs to the skill underneath it: `tmax create_exercise_page --title "Arm Drag Shadow Reps" --parent "Wrestling/Arm Drag" --markdown-body "<how>"`, and a note with the theory: `tmax create_note_page --title "Arm Drag Notes" --parent "Wrestling/Arm Drag"`.
4. Add another clip later: `tmax attach_media --page "Wrestling/Arm Drag" --path /abs/clip.mp4 --comment "<what it shows>"`.
5. `tmax get_page --page "Wrestling/Arm Drag"` reads status, group, notes, every clip with its comment and the sub-pages. `tmax get_page --page "Wrestling"` lists the groups of the board. `tmax search_pages --query "<words>"` also looks inside notes and clip comments.

Order skills from easy to hard: pages appear in the order they were created inside their group.

A page that needs no sub-skills (a tutorial or a reel that is just clips and notes) takes `--no-skills` when it is created, or later `tmax update_page --page "<Skill/Path>" --no-skills`: it then shows no skill board, progress, to-dos, milestones or learn-first list (`--no-skills false` brings them back). `--widgets clips --widgets workouts` picks the widget tiles above a page's tabs, in that order; `--widgets auto` goes back to the tiles that have something to show and `--widgets none` shows none.
"""
    }
}
