import Foundation

extension DatabaseManager {
    func bootstrapOrganizeSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("organize-library.md"), content: bootstrapOrganizeLibraryContent())
    }

    private func bootstrapOrganizeLibraryContent() -> String {
        return """
# organize-library
Put pages where they belong: order the pages of a folder, move a page to a chosen place, set a skill's status and group, edit skill groups, copy pages, and bring deleted pages and workouts back from the trash.

## Order and move pages
1. `tmax list_pages --parent "Boxing"` shows the pages of a folder in their order.
2. `tmax move_page --page "Boxing/Jab" --before "Boxing/Cross"` puts a page right before another page (`--after` puts it right after). The page lands in that page's folder, so this also moves it there when it sits somewhere else.
3. `tmax move_page --page "Jab" --new-parent "Boxing" --position 1` makes it the first page of a folder; `--position` counts from 1 and a number past the end means last. Pass at most one of `--before`, `--after` and `--position`.
4. Without `--new-parent`, `--position` counts the pages at the top of the library, so a page that sits inside a folder needs `--new-parent` to be placed inside that folder. `tmax move_page --page "Boxing/Jab"` alone still moves it to the top level, and `--new-parent "Footwork"` alone moves it to the end of another folder.
5. `tmax reorder_pages --parent "Boxing" --order Jab --order Cross --order Hook` sets the order in one call: the pages named come first in that order, every page you leave out keeps its current order after them. Leave out `--parent` to order the top level. Only pages directly inside the folder can be named.
6. `tmax undo` takes the last move or reorder back, with every page in its earlier place.

Skills on a skill board sit in groups; their order inside a group is set with `update_skill`, not with `reorder_pages`.

## Skill status, group and place
1. `tmax get_page --page "Wrestling"` lists the board's groups; `tmax get_page --page "Wrestling/Arm Drag"` shows a skill's status and group.
2. `tmax update_skill --page "Wrestling/Arm Drag" --status learning` moves the skill to another column. Status is `notStarted`, `learning`, `completed` or `abandoned`; the words the app shows (Not Started, Learning, Completed, Abandoned) work in any letter case.
3. `tmax update_skill --page "Wrestling/Arm Drag" --group "Hand Fighting"` puts it in a group of its parent's board (by title or id; `create_skill_group` makes new ones). `--group none` (or empty text) takes it out of every group.
4. `--position 1` sets its place among the skills of the same group and status; without it a skill that changes group or status goes to the end of its new column. One call can change status, group and position together.
5. Only a skill or tutorial page has these; a skill at the top of the library has a status but no groups.

## Skill groups
1. `tmax update_skill_group --container "Wrestling" --group "Hand Fighting" --title "Hand Fighting & Setups" --color FF6A00 --icon hand.raised` renames the group and changes its colour (RRGGBB) and icon (an SF Symbol name or an emoji); `--icon ""` and `--color ""` clear them. `--markdown-body "<notes>"` replaces the group's notes (empty text clears them) and `--position 1` moves the group among the groups.
2. `tmax delete_skill_group --container "Wrestling" --group "Hand Fighting"` asks the user first. The skills in the group are kept and move to no group, after the skills already outside any group; the group's own notes, links, clips and pictures go with it (its files to the trash).
3. `tmax undo` brings back a renamed or moved group, and a deleted one that held no clips or pictures.

## Duplicate a page
1. `tmax duplicate_page --page "Boxing/Jab"` makes a copy right after the original, titled "Jab Copy" ("Jab Copy 2" when that exists). `--title "Jab Drill"` names it; a number is added when a page there already has the title.
2. The copy has the same fields, notes, links, clips and pictures with their comments, a note's pictures included. A skill copy stays in the same group and status; a tag stays when the copy is in the same tree.
3. `--parent "Footwork"` puts the copy at the end of another container instead. A copy there leaves its group, and keeps its tag only when the new tree has that tag (the result says when it lost one).
4. A folder or a skill is copied without its sub-pages. `--deep true` copies everything inside, at any depth, up to 200 pages in all, and refuses a bigger tree; prerequisites between copied pages point at the copies.
5. A page cannot be copied into itself or into a page inside it. `tmax undo` moves the copy (and its sub-pages) to the trash.

## Find and restore deleted items
1. `tmax list_trash` shows pages and workouts, newest first: `id` (the trash entry), `kind`, `title`, `deleted`, and for a page `from` (the path it came from) and `inside` (pages inside it). `--limit 200` shows more; `more` says how many are left.
2. `tmax restore_from_trash --item "<id from list_trash>"` brings a page back together with everything inside it, in the folder it came from. When that folder is gone the page returns to the top level and the result says so; `--parent "Boxing"` picks another container. The id of the deleted page or workout works as `--item` too when only one deleted copy exists.
3. A workout goes back to the Workouts page; it was taken out of its workout groups when it was deleted, so add it to a group again with `update_workout_group`.
4. Nothing is overwritten: a page or workout that already exists blocks the restore. A page whose title is already used in its folder still comes back, with a warning; ids tell the two apart. `tmax undo` after a restore moves it back to the trash.
5. Nothing here deletes from the trash for good.
"""
    }
}
