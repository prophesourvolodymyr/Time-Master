import Foundation

extension DatabaseManager {
    func bootstrapPageContentSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("page-content.md"), content: bootstrapPageContentContent())
    }

    private func bootstrapPageContentContent() -> String {
        return """
# page-content
Read everything inside a page and edit its attachments, captions, link comments, learn-first list, attached pages, drop sets and icon.

## Read a page fully
- `tmax get_page --page "Wrestling/Arm Drag"` shows, only when the page has them: `media` (every attachment with its number `index`, its `kind` and `comment`), `links` (each link with its comment and learn-first flag; `linkURLs` stays the plain list), `learnFirst` (the pages to learn first, in order, each with `id` and `path`), `linkedPages` (the pages attached to it), `icon` (`name` and `type`), `dropSets`, and the `created` and `updated` dates.
- A skill board lists its groups with their ids; a group in someone's learn-first list shows `group: true`.
- On a media item, `cover: true` is the file the app shows as the page's cover: the banner the page chose, or the first file when none was chosen. `icon: true` is the picture used as the small icon tile, `learnFirst: true` a file to have first (skills and tutorials), `missing: true` an attachment whose file is gone from disk.
- The number `index` is the address every media tool takes. It counts from 1 in the order get_page lists the files and changes when a file is moved or removed, so read the page again before the next edit.

## Captions, order, banner and icon
1. `tmax update_media --page "Boxing/Jab" --index 2 --comment "Keep the elbow tucked"` sets the caption of the second attachment (Markdown); `--comment ""` clears it.
2. `tmax update_media --page "Boxing/Jab" --index 3 --position 1` moves the third file to the front, its caption with it. A position past the end puts it last.
3. Position 1 makes a file the cover only while the page has no chosen banner. `--cover true` chooses the banner (a picture or a video); `--cover false` takes the choice off, so the first file is the cover again. The reply's `cover` is the number of the file the app shows as the cover.
4. `--icon true` uses a picture as the page's icon tile; `--icon false` clears it when that picture is the icon. A video cannot be the icon.
5. Several changes go in one call: `tmax update_media --page "Boxing/Jab" --index 3 --position 1 --comment "Best angle" --cover true`.
6. `tmax remove_media --page "Boxing/Jab" --index 2` removes an attachment after asking the user. The file moves to the library trash (.trash), the later files move up one place, and a banner or icon that pointed at it is cleared. `tmax undo` brings back the entry and its caption but not the file, which then shows `missing: true`.
7. Notes keep their pictures inside the Markdown: change them with `update_page --markdown-body`, not with these tools.

## Links
- `tmax update_page --page "Wrestling/Arm Drag" --link-urls https://a.example --link-urls https://b.example` replaces the whole list. Comments and learn-first flags stay only on links whose address is passed unchanged.
- `tmax update_link --page "Wrestling/Arm Drag" --url https://a.example/video --comment "Start here: the grip at 2:10"` comments one link. The address matches ignoring case and a trailing slash; `--comment ""` clears it. The app shows link comments on skill and tutorial pages.
- `--new-url https://a.example/better` changes the address and keeps the link's place, comment and flag.
- `--learn-first` flags the link as something to have first (`--learn-first false` takes it off). Only skills and tutorials have the flag.

## Learn first and attached pages
- A skill or a tutorial keeps a Learn first list: the pages to learn before it, in the order to learn them. `tmax update_learn_first --page "Boxing/Combos" --add "Boxing/Jab" --add "Boxing/Cross"` appends pages, `--remove "Boxing/Cross"` takes one off, and `--order "Boxing/Cross" --order "Boxing/Jab"` gives the complete new order: every page of the list once, counting that call's removals and additions. The reply is the list afterwards.
- A page cannot wait for itself or for a page that already waits for it, and a page that does not exist is refused. A skill group goes in by its id. Adding a page that is already on the list, or removing one that is not, changes nothing and shows up as `alreadyListed` or `notListed`.
- A file or a link can be flagged to learn first too: `tmax update_media --page "Boxing/Combos" --index 1 --learn-first`, `tmax update_link --page "Boxing/Combos" --url https://a.example --learn-first`. A page with `noSkills` keeps the flags but shows no learn-first list.
- `tmax update_linked_pages --page "Boxing/Combos" --add "Boxing/Jab"` attaches pages, the app's Attach Page button; `--remove` and `--order` work the same way. Only skills and tutorials keep attached pages.

## Drop sets and icons
- An exercise page can hold drop sets: extra exercises played after a set when the page goes into a workout. Pass them as JSON: `tmax update_page --json '{"page":"Boxing/Jab","sets":3,"dropSets":[{"set":3,"exercise":"Boxing/Cross"},{"set":1,"name":"Slow jab","duration":45,"restAfter":10}]}'` replaces the whole list, and `"dropSets":[]` clears it.
- `set` counts from 1 and defaults to the last set, and the page needs that many sets. With `exercise` the name, duration and rest default from that exercise page; without it `name` is required.
- `tmax update_page --page "Boxing/Jab" --icon figure.boxing` gives any page an SF Symbol or an emoji as its icon tile; `--icon ""` clears it. `--icon-image /abs/photo.jpg` copies a picture in and uses it, and `update_media --icon` uses a picture the page already holds.

Add `--dry-run` to see what a call would change. These edits can be undone with `tmax undo`, except the trashed file of remove_media.
"""
    }
}
