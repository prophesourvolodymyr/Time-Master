import Foundation

extension DatabaseManager {
    func bootstrapRecordSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("workout-history.md"), content: workoutHistoryContent())
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("boxing-combos.md"), content: boxingCombosContent())
    }

    private func workoutHistoryContent() -> String {
        return """
# workout-history
Read and fix the workout history, look at outdoor activities, check the library for damage, make a backup and copy a workout.

## History
- `tmax list_history --days 30` lists completed workouts, newest first. Each entry has an `id`, the `name`, `at` (local time with its UTC offset), `seconds` actually trained, the `type`, `partial` when the user stopped early, and `workout` (the saved workout's id) while that workout still exists. `--type Cardio` and `--limit 100` narrow it; the reply says how many `more` matched.
- `tmax log_workout --workout "Week 3 Tue AM" --completed-at 2026-11-24T18:30` records a workout the user did without the app. A saved workout fills the name, type and length. Without one pass `--name "Run in the park" --seconds 1500 --type Cardio`. `--partial --seconds 600` records a workout stopped early: the seconds are the time actually done.
- `--completed-at` is ISO 8601: `2026-11-24T18:30` is the user's local time, `2026-11-24T18:30+02:00` carries its own offset, `2026-11-24` alone means noon that day. The default is now and the future is refused.
- A logged workout counts for streaks and stats like one done in the app, and it is added at the end of the history file: nothing else moves.
- `tmax delete_history_entry --id <id from list_history>` removes one entry (it asks the user first). It stops counting for streaks and stats, and other devices drop it on the next sync.
- `tmax undo` takes back the last `log_workout` or `delete_history_entry`; a deleted entry returns to its old place.

## Outdoor activities
- `tmax list_outdoor_activities --kind run --limit 10` lists runs, walks and bike rides, newest first: `id`, `kind`, `title` once renamed, `at`, `distanceKm`, `seconds`, `starred`, and `finished false` for one that was never finished or is still being recorded.
- `tmax get_outdoor_activity --id <id>` shows every field that is set and `trackPoints`, how many route points were recorded. `--points --limit 20` adds an even sample of them (t seconds since the start, lat, lon, ele, speed); the whole route is never listed.
- `tmax update_outdoor_activity --id <id> --title "Hill repeats" --starred --description "Windy" --tags hills --tags tempo` changes a finished activity. `--kind walk` switches between run, walk and bike; an empty `--title ""` goes back to the kind's name. Visibility and the privacy settings stay in the app. This cannot be undone.
- `tmax delete_outdoor_activity --id <id>` moves the activity and its route to the library's .trash folder and asks the user first. It is not erased: moving its folder back out of .trash restores it. `tmax undo` does not cover it.

## Library health and backups
- `tmax validate_library` checks the manifest of every page and workout and answers with totals (`checked`, `healthy`, `withErrors`) and the first 50 problems. A problem has its `path`, `name` or `in` (the nearest page or workout that can still be read) and the `errors`. Fields that are simply not set are not problems. History, settings and outdoor activities are not checked.
- `tmax create_backup --label before-cleanup` copies pages with their media, workouts, outdoor activities, routes, history and the settings file into a new folder under Backups and answers with the folder's name, which starts with the UTC date and time (for example 20261125-183000-before-cleanup). It is a space-saving clone where the disk allows it. Music and the old Media folder are not copied, and old backups are never deleted. Make one before a bulk change such as a big `batch`, a reorganisation or deleting many things.
- `tmax duplicate_workout --workout "Week 3 Tue AM" --name "Week 4 Tue AM" --group "Week 4"` copies a workout, sections and rests included, with fresh ids. Without `--name` the copy is called "<name> Copy" (numbered when taken); without `--group` it lands in no group and the original's group stays as it was. `tmax undo` moves the copy to the trash.

## Gotchas
- When the user says they trained "yesterday", ask for the time and length unless they gave them; do not invent them. Use `--dry-run` to preview any of these calls.
- Deleting a history entry can break a streak and lowers the stats; list the entry first and confirm it is the right one.
- Each `undo` reverses only the last agent change.
"""
    }

    private func boxingCombosContent() -> String {
        return """
# boxing-combos
Build the called-punch part of a Boxing workout: a combo section plays rounds of calls such as 1-2-3, and the app says each call aloud.

## What a combo is
- A combo is a section of a workout with its own kind, `combo`; it is not a plain bundle. Every round plays all the calls once, in order; each call lasts `secondsPerCall` seconds and a rest comes between rounds. The player says 1-2-3 as "one, two, three".
- A call is moves joined by dashes. Moves: 1 jab, 2 cross, 3 lead hook, 4 rear hook, 5 lead uppercut, 6 rear uppercut, and the words slip, roll, duck, block, pivot, reset. A call holds 1 to 8 moves, a round up to 40 calls. Write a call as `1-2-3`, `1 2 3` or `123`; `1,2,slip` and `1-2-Slip` are accepted too. It is stored as `1-2-3` or `1-2-slip`.
- Defaults: 3 rounds, 5 seconds per call, 20 seconds of rest between rounds, 3 seconds to get ready before the first round, calls spoken aloud. The optional `icon` is drawn in the corner of the combo.

## Steps
1. `tmax build_workout --json '{"name":"Boxing night","type":"Cardio","sections":[{"name":"Round robin","combo":{"calls":["1-2","1-2-3","1-1-2-slip"],"rounds":4,"secondsPerCall":5,"restBetweenRounds":20,"icon":"flame.fill"}},{"exercise":"Boxing/Shadow Boxing","duration":120}]}'`
2. `tmax add_workout_section --workout "Boxing night" --name "Finisher" --position 1 --combo '{"calls":["1-2","1-2-3"],"rounds":3}'` adds another combo; `position` inserts it, otherwise it is appended.
3. `tmax get_workout --workout "Boxing night"` reads it back: `kind` combo with `calls`, `rounds`, `secondsPerCall`, `restBetweenRounds` and `icon`. When the user edited rounds in the app so that they differ, `roundCalls` lists the calls of each round (and `callSeconds` or `roundCallSeconds` the seconds when they are not all the same).

## Changing a combo
- `tmax update_workout_section --workout "Boxing night" --section "Round robin" --combo '{"rounds":6}'` changes only the keys you pass.
- `calls` replaces the calls of every round and keeps the rounds, rests and icon. `secondsPerCall` sets every call. `restBetweenRounds` sets the rest after every round but the last. `rounds` adds copies of the last round or drops the last ones.
- `icon` is an SF Symbol name or one emoji (`""` clears it). `name`, `order` (ordered or random) and `voice` (false to stay silent) sit in the same object. `--rest-after`, `--untimed`, `--prepare-time` and `--name` work as on any section; a combo's get-ready time is the first round's.
- A plain `bundle` argument on a combo is refused; use `combo`. `sets`, `duration`, `restBetweenSets` and `repCount` do not apply to a combo: `combo.rounds`, `combo.secondsPerCall` and `combo.restBetweenRounds` take their place. A bundle or a timed section cannot be turned into a combo: add a combo and remove the old section.
- `tmax remove_workout_section` asks the user first.

## Gotchas
- One string per call in `calls`. A comma inside a string separates moves, not calls: `["1,2"]` is one call of two moves.
- An unknown move is refused with the list of valid ones (`jab` and `7` are not moves; write `1` for a jab).
- A spoken cue that is not a punch, such as "Switch stance", belongs in a bundle as a callout: `{"callout":"Switch stance","duration":5}` inside `bundle.exercises`.
- `list_workouts` counts combos apart from bundles.
"""
    }
}
