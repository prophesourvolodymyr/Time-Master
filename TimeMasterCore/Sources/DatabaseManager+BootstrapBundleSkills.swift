import Foundation

extension DatabaseManager {
    func bootstrapBundleSkills() throws {
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("build-bundle.md"), content: bundleSkillContent())
    }

    private func bundleSkillContent() -> String {
        return """
# build-bundle
Build a workout section where several exercises (drills) play back to back, for example wrestling drills.

## How a bundle plays
Every set plays all the exercises once, one after another. Each exercise has its own seconds (as short as 1) and its own rest after it (0 switches straight to the next). After the last exercise of a set comes the rest between sets. `order` is `ordered` or `random` (reshuffled each time the workout starts). The player shows what is playing now and what is next.

## Steps
1. `tmax search_pages --query "<drill>" --kind exercise` to find the exercise paths.
2. `tmax build_workout --json '{"name":"Wrestling drills","sections":[{"bundle":{"exercises":[{"exercise":"Wrestling/Sprawl","duration":20,"restAfter":5},{"exercise":"Wrestling/Shoot","duration":20,"restAfter":5}],"sets":3,"restBetweenSets":40,"order":"random"}}]}'`
3. `tmax get_workout --workout "Wrestling drills"` to confirm the sets, rests and total time.

## Changing a bundle later
- `tmax update_workout_section --workout "Wrestling drills" --section 1 --json '{"bundle":{"sets":4,"restBetweenSets":30}}'`
- Pass `bundle.exercises` to replace the exercises in every set.
- `tmax add_workout_section --workout "Wrestling drills" --json '{"bundle":{...}}'` adds another bundle (or a timed `exercise` section); `position` inserts it.
- `tmax remove_workout_section --workout "Wrestling drills" --section 2` asks the user first.
"""
    }
}
