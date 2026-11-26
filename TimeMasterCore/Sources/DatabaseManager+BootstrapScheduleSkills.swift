import Foundation

extension DatabaseManager {
    func bootstrapScheduleSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("manage-schedule.md"), content: scheduleSkillContent())
    }

    private func scheduleSkillContent() -> String {
        return """
# manage-schedule
Plan the training week, see what is due, move things around and mark them done. This is the Schedule page of the app.

## How the schedule works
- A plan is a weekly template: workouts on weekdays, each with an optional start time and length. Plans are saved in a list.
- Following a plan from a week copies it into that week and every week after, until another plan (or a vacation) is chosen. Earlier weeks keep what they had, so editing or deleting a plan never rewrites the past.
- An entry can also live on one date only (a one-off). A repeating entry joins the plan in use.
- A vacation week has no entries and pauses the weekly streak.
- An entry is done when a matching workout was completed that day, or when it was marked by hand (a hand mark wins; clear it to follow the history again).
- Training days are the weekdays that must be trained to keep the weekly streak (default Mon, Wed, Fri). They apply from a week on.
- Days are written YYYY-MM-DD (today, tomorrow and yesterday also work), weekdays as Mon to Sun, times as HH:mm.

## Reading
1. `tmax get_schedule` shows the next 7 days with each entry's time, length and whether it is done, the plan in use, vacations, training days and the streak. `--date 2026-12-01 --days 14` shows another stretch.
2. `tmax list_schedule_plans` shows every plan with its entries by weekday and which plan is in use. Entry ids come from here and from get_schedule (the `occurrence` value like `2026-12-01/<id>` names one entry on one day).

## Building a plan
1. `tmax list_workouts` to find the workout names.
2. `tmax create_schedule_plan --json '{"name":"Boxing block","use":true,"from":"2026-12-01","entries":[{"workout":"W1 Mon AM","weekday":"Mon","start":"07:30"},{"workout":"W1 Wed PM","weekday":"Wed","start":"18:00","minutes":45}]}'` saves the plan and follows it from the week of 2026-12-01. Without `use` it is only saved.
3. `tmax update_schedule_plan --plan "Boxing block" --json '{"addEntries":[{"workout":"W1 Fri AM","weekday":"Fri"}]}'` changes a plan (also `name`, `icon`, `entries` to replace all, `removeEntries` with ids). A plan in use this week is applied from this week on; pass `from` to choose the week, `apply false` to only save.
4. `tmax select_schedule_plan --plan "Boxing block" --week 2026-12-08` switches from that week; `tmax select_schedule_plan --vacation --week 2026-12-22` starts a vacation.
5. `tmax delete_schedule_plan --plan "Boxing block"` asks the user first; weeks that follow it keep their copy.

## Changing single days
- `tmax add_schedule_entry --workout "W1 Mon AM" --date 2026-12-03 --start 18:30` puts a workout on one date; add `--repeat` to repeat it every week from then (it joins the plan in use). `--title "Mobility" ` adds a custom activity without a workout. `--done` marks it finished right away.
- `tmax add_schedule_entries --json '{"entries":[{"date":"2026-12-01","workout":"W1 Mon AM","start":"07:30"},{"date":"2026-12-01","workout":"W1 Mon PM","start":"18:00"}]}'` puts a whole program on dates in one call (up to 200, each one-off; all are added or none).
- `tmax update_schedule_entry --entry "W1 Mon AM" --date 2026-12-01 --start 09:00` changes that day only. `--scope plan` changes the plan's entry from that week on (it also takes `--weekday`). `--move-to 2026-12-02` moves a day's entry to another date.
- `tmax remove_schedule_entry --entry "W1 Mon AM" --date 2026-12-01` takes it off that day (asks the user first); `--scope plan` removes it from the plan from that week on.
- `tmax complete_schedule_entry --entry "W1 Mon AM" --date 2026-12-01` marks it done; `--done false` marks it not done; `--clear` goes back to following the history.
- `tmax set_training_days --days Mon --days Thu --days Sat --from 2026-12-01` sets the streak days.

Every write accepts `--dry-run`, and `tmax undo` reverses the last schedule change.
"""
    }
}
