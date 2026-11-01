# F32 — Device Sync

Pair a Mac and an iPhone once. From then on, whenever both run Tmax on the same Wi-Fi, a change made on one shows up on the other within about a second, and a device that was away catches up the moment it is back. Nothing goes through the internet and nothing needs an account: the two devices talk directly, encrypted, and only to each other.

## Why It Exists

The library is a folder of files, so the two copies on a Mac and an iPhone drift apart as soon as both are edited. Cloud sync covers the exercise database only and needs an account and a server. Device Sync is the same idea for everything a person keeps in Tmax, without a server. The engine was first built for Skillmax (a sister app written by the same author whose data layer came from Tmax) and is brought here adapted to Tmax's own library.

## What We Build

- **Pairing, once.** On both devices open Settings → Device Sync → Add a device. One device taps the other, both show the same six digits, and the person confirms on both screens. A stranger on the same Wi-Fi would end up with different digits on each side, so the person says no. The devices keep a shared secret from this moment on; every later connection proves it.
- **Live sync.** The device with the smaller id dials; the other dials only if it has not been reached for eight seconds. Every local change (found within a second), every "my library changed" notice from the other device and a safety timer every three minutes start a sync. One device drives each sync, so every merge happens once.
- **The Settings screen.** Settings → Device Sync shows this device, the on/off switch, every paired device with its state (connecting, syncing, up to date, not on this network with the time of the last sync, or the reason it failed) and three actions per device: Sync now, Remove, and Add a device at the bottom. A line says when notes were edited in the same place on both devices.
- **The network stays off until it is needed.** Nothing is advertised or browsed until a device is paired or Add a device is open, so the iPhone asks for Local Network access only when the person wants sync. The iPhone syncs while Tmax is open in front; the Mac while it runs.
- **After something arrives**, Workouts, History, the exercise database, routes and activities and the music list reload.

## What Travels

The library is divided into items, and each item is compared as one whole.

| Item | Where it lives | What counts as its content |
|---|---|---|
| Page | `Exercises Database/…/<page id>/` | `manifest.json` and every file in the folder except the generated `guide.md`: `media/`, a cover, `Attachments/`, group material under `Sections/`, any other file. Child pages are their own items. |
| Workout | `Workouts/<id>/` | `manifest.json` and any other file in the folder |
| Activity | `Activities/<id>/` | `manifest.json` and `track.jsonl`, once the activity is finished. A recording in progress stays where it is. |
| Route | `Routes/<id>.json` | the file |
| Legacy media | `Media/<file>` | the file |
| Photos and music | the app's `Photos` and `Music` folders (outside the library folder) | each file |
| History | `History/entries.jsonl` | every completed workout, one by one, grouped by month |
| Schedule and settings | `Config/manifest.json` | everything except the outdoor recording preferences |

Folder names are page, workout and activity ids, so renaming never moves a folder; moving a page moves its folder, with its children, under the new parent.

## What Never Travels

- **Config/sync/** — this copy's id, the shared secrets of paired devices (readable by the owner only), what each pair last agreed on and a file-hash cache. It is bookkeeping about this one copy: never copy it to another device, never edit it, never restore it from a backup onto another device. Agents leave it alone.
- Outdoor recording preferences (GPS accuracy, keep screen awake, haptics …), device settings kept in the system preferences, in-flight workout timers and resume points, caches, drafts, music and photo files that are not in the app's own folders, Backups, `.trash`, generated files (`AGENTS.md`, `schema.json`, `skills/`, `Knowledge/`), and everything about the cloud account, Ranked and the cloud sync journal (`.sync/`).

## How Two Copies Are Merged

- A page gets a content hash over its manifest and files; `updatedAt`, the order mirrors (`order` of a page with a parent) and the generated guide are left out, because two copies with the same content are the same version. A hybrid logical clock stamps each new version; a page seen for the first time is as old as its `updatedAt`.
- Each pair of devices remembers the last version they agreed on (the base). A change made on one side is taken by the other; changes on both sides are merged field by field: lists of things with ids (media notes, groups, workout sections and slots, schedule entries) item by item, lists of names as ordered sets, long notes line by line, and for one value changed both ways the newer change wins. Where the same lines of a note were changed on both devices, both versions stay in the note between `<<<<<<<` and `>>>>>>>` marks and Settings says so.
- A page's place (parent, group and position on the board) is one fact: after two devices move or place it differently the newer whole place wins and the parent's list of children is put right.
- A page deleted on one device is deleted on the other (into `.trash`), unless it was edited after the deletion: then it comes back whole, with its files. Pages inside a deleted page that were changed after the deletion move up one level.
- Files are compared per path; a replaced or deleted file goes to `.trash`, never into a conflict copy. Large files travel in 1 MiB pieces and are checked by hash.
- History entries are matched by id; a deleted entry is deleted on the other device and does not come back. The schedule merges like a manifest.
- The first change that comes from a device is preceded by a copy of the library in `Backups/<time>-before-sync` on the device that receives it (skipped when the library is empty).
- Two devices that run different versions of the sync format refuse to sync and say which one needs updating.

## Coexisting With Cloud Sync

The two engines are separate: the cloud journal lives in `.sync/`, Device Sync in `Config/sync/`, and neither reads the other's files. A page that Device Sync brings in is an ordinary local edit for cloud sync, and the other way round. Device Sync pauses while the cloud account or the cloud sync mode is being switched, because that swaps the whole exercise library.

## States

- **Switch off:** nothing runs, paired devices stay paired.
- **No paired devices:** the Paired devices card says so and offers Add a device.
- **Device row:** Connecting…, Connected, Looking for changes… / Reading… / Receiving a file… / Updating…, Up to date, Not on this network (with the last sync), or a one-line reason.
- **Add a device sheet:** looking on this Wi-Fi, a list of devices that also have the sheet open, connecting, the six digits with Yes, they match / No, they are different, waiting for the other device, paired, or a failure with Try again. A "they match" tap in the first second is ignored.

## Limits

Device Sync works on one network only: no cloud relay, no selective sync, no syncing while the iPhone app is in the background, and an interrupted large file starts over. Two devices that deleted and re-created the same data separately can show it twice. A new device that opens with the sample workout creates it under its own id, so it may appear twice after the first sync.
