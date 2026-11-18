import Foundation

extension DatabaseManager {
    func bootstrapPageTagSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("tag-pages.md"), content: bootstrapTagPagesContent())
    }

    private func bootstrapTagPagesContent() -> String {
        return """
# tag-pages
Sort the exercises and notes of a folder into columns by tag, the way a Notion board is grouped by a Select property.

## What a tag is
- A tag is an option of a preset (the Select property, for example "Routine" with Morning flow, Between sets, Evening stretch). A page wears at most one tag.
- The top folder of a tree keeps the tags. Every exercise and note nested below it, at any depth, shares them; sub-folders keep none of their own.
- A tag is not the workout type (`workoutType`, owned by root folders) and not a completion status.
- Skill and tutorial pages keep their own types (their highest skill keeps them); the same tools read and write those.

## Steps
1. `tmax list_page_tags --container "Mobility & Flexibility"` shows the presets, every tag with its id, colour and how many pages wear it, and how many pages are untagged.
2. `tmax create_page_tag --container "Mobility & Flexibility" --title "Morning flow" --preset "Routine" --color 5CE1E6 --if-exists reuse` makes a tag; the preset is made when it does not exist.
3. `tmax update_page --page "Mobility & Flexibility/Hips/90-90 Switch" --tag "Morning flow"` tags a page; `--tag ""` takes the tag off. `create_exercise_page`, `create_note_page` and `create_skill_page` take `--tag` too.
4. Tag many pages at once with `tmax batch` and one `update_page` per page. If one operation fails, the tags the batch put on go back to what they were.
5. `tmax search_pages --query "" --tag "Morning flow"` lists the pages wearing a tag. `get_page`, `list_pages` and `search_pages` show `tag` on every tagged page.
6. `tmax update_page_tag --container "Mobility & Flexibility" --tag "Morning flow" --title "Morning mobility"` renames a tag (also `--color`, `--icon`); `tmax delete_page_tag` deletes one after asking, and its pages become untagged.

In the app, a folder's Exercises tab has a Board layout with one column per tag, Untagged first; dragging a card to another column changes its tag.
"""
    }
}
