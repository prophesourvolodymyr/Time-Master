import Foundation

private let scheduleWeekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
private let scheduleWeekdayFull = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
private let scheduleDefaultIcon = "figure.mixed.cardio"
private let schedulePlanIcon = "square.stack.3d.up.fill"

extension AgentToolbox {
    func runScheduleTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "get_schedule": return try getSchedule(args)
        case "list_schedule_plans": return try listSchedulePlans(args)
        case "create_schedule_plan": return try createSchedulePlan(args, dryRun: dryRun)
        case "update_schedule_plan": return try updateSchedulePlan(args, dryRun: dryRun)
        case "delete_schedule_plan": return try deleteSchedulePlan(args, dryRun: dryRun)
        case "select_schedule_plan": return try selectSchedulePlan(args, dryRun: dryRun)
        case "add_schedule_entry": return try addScheduleEntry(args, dryRun: dryRun)
        case "add_schedule_entries": return try addScheduleEntries(args, dryRun: dryRun)
        case "update_schedule_entry": return try updateScheduleEntry(args, dryRun: dryRun)
        case "remove_schedule_entry": return try removeScheduleEntry(args, dryRun: dryRun)
        case "complete_schedule_entry": return try completeScheduleEntry(args, dryRun: dryRun)
        case "set_training_days": return try setTrainingDays(args, dryRun: dryRun)
        default: return nil
        }
    }

    private func loadSchedule() throws -> (config: ConfigManifest, schedule: WeeklyWorkoutSchedule) {
        let config = try database.loadConfig()
        return (config, config.workoutSchedule ?? WeeklyWorkoutSchedule())
    }

    func scheduleOverview() -> [String: Any]? {
        guard let schedule = (try? database.loadConfig())?.workoutSchedule, !schedule.plans.isEmpty || schedule.startedOn != nil else { return nil }
        var overview: [String: Any] = [:]
        if !schedule.plans.isEmpty { overview["plans"] = schedule.plans.map(\.name) }
        if let selection = schedule.selection(for: Date()) {
            if let plan = selection.plan { overview["inUse"] = plan.name } else { overview["vacation"] = true }
        }
        return overview
    }

    private func commitSchedule(
        _ config: ConfigManifest, previous: WeeklyWorkoutSchedule, updated: WeeklyWorkoutSchedule,
        dryRun: Bool, value: [String: Any]
    ) throws -> AgentToolOutput {
        if dryRun {
            var preview = value
            preview["dryRun"] = true
            return AgentToolOutput(value: preview)
        }
        var saved = config
        saved.workoutSchedule = updated
        try database.saveConfig(saved)
        let snapshot = String(data: try JSONEncoder().encode(previous), encoding: .utf8) ?? ""
        return AgentToolOutput(value: value, effects: [.changedSchedule(previous: snapshot)])
    }

    private func scheduleDay(_ text: String) throws -> Date {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch clean {
        case "today": return today
        case "tomorrow": return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        case "yesterday": return calendar.date(byAdding: .day, value: -1, to: today) ?? today
        default: break
        }
        let pieces = clean.split(separator: "-", omittingEmptySubsequences: false)
        let numbers = pieces.compactMap { Int($0) }
        let failure = AgentToolError("invalid_date", "'\(text)' is not a day.", hint: "Use YYYY-MM-DD, for example 2026-11-25, or today, tomorrow or yesterday.")
        guard pieces.count == 3, numbers.count == 3,
              let date = calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])) else { throw failure }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == numbers[0], back.month == numbers[1], back.day == numbers[2] else { throw failure }
        return calendar.startOfDay(for: date)
    }

    private func scheduleTime(_ text: String) throws -> Int? {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if body.isEmpty { return nil }
        var meridiem: String?
        if body.hasSuffix("am") || body.hasSuffix("pm") {
            meridiem = String(body.suffix(2))
            body = String(body.dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        let parts = body.split(separator: ":", omittingEmptySubsequences: false)
        let failure = AgentToolError("invalid_time", "'\(text)' is not a time of day.", hint: "Use HH:mm on 24 hours, for example 07:30 or 18:00, or 7:30am.")
        guard parts.count == 1 || parts.count == 2, var hour = Int(parts[0]) else { throw failure }
        let minute = parts.count == 2 ? Int(parts[1]) : 0
        guard let minute, (0..<60).contains(minute) else { throw failure }
        if let meridiem {
            guard (1...12).contains(hour) else { throw failure }
            hour = hour % 12 + (meridiem == "pm" ? 12 : 0)
        }
        guard (0..<24).contains(hour) else { throw failure }
        return hour * 60 + minute
    }

    private func scheduleWeekday(_ text: String) throws -> Int {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let number = Int(clean), (1...7).contains(number) { return number }
        if clean.count >= 3, let index = scheduleWeekdayFull.firstIndex(where: { $0.hasPrefix(clean) }) { return index + 1 }
        throw AgentToolError("invalid_weekday", "'\(text)' is not a weekday.", hint: "Use Mon to Sun (Monday to Sunday also work), or 1 (Monday) to 7 (Sunday).")
    }

    private func scheduleColor(_ text: String) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard clean.count == 6, clean.allSatisfy({ $0.isHexDigit }) else {
            throw AgentToolError("invalid_color", "'\(text)' is not a colour.", hint: "Use six hex digits without #, for example FF6A00.")
        }
        return clean
    }

    private func clock(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func dayName(_ date: Date) -> String {
        scheduleWeekdayNames[WeeklyWorkoutSchedule.weekday(date) - 1]
    }

    private func scheduleWorkoutNames() throws -> [String: String] {
        Dictionary(try database.listWorkouts().map { ($0.id.lowercased(), $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func scheduleActivity() throws -> WeeklyWorkoutSchedule.Activity {
        let sessions = try database.readHistory().filter { !$0.isPartial }.compactMap { entry -> WeeklyWorkoutSchedule.Session? in
            guard let workoutID = UUID(uuidString: entry.workoutId) else { return nil }
            return WeeklyWorkoutSchedule.Session(id: UUID(uuidString: entry.id) ?? UUID(), workoutID: workoutID, date: entry.completedAt)
        }
        return WeeklyWorkoutSchedule.Activity(sessions: sessions)
    }

    private func scheduleEntry(from values: [String: Any], base: WeeklyWorkoutSchedule.Entry?, defaultWeekday: Int?) throws -> WeeklyWorkoutSchedule.Entry {
        var entry = base ?? WeeklyWorkoutSchedule.Entry(title: "", weekday: defaultWeekday ?? 1)
        if base == nil, let raw = values["id"] as? String {
            guard let id = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw AgentToolError("invalid_argument", "'id' must be an entry id.", hint: "Entry ids come from list_schedule_plans or get_schedule.")
            }
            entry.id = id
        }
        if let raw = values["workout"] as? String {
            let reference = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if reference.isEmpty {
                entry.workoutID = nil
            } else {
                let workout = try findWorkout(reference)
                entry.workoutID = UUID(uuidString: workout.id)
                if values["title"] == nil { entry.title = workout.name }
                if values["minutes"] == nil { entry.durationSeconds = workout.totalDuration }
                if values["exerciseCount"] == nil { entry.exerciseCount = workout.sections.count }
                if values["icon"] == nil { entry.icon = workout.type.iconName }
                if values["color"] == nil { entry.colorHex = workout.type.colorHex }
            }
        }
        if let title = values["title"] as? String {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { throw AgentToolError("invalid_argument", "'title' must not be empty.") }
            entry.title = clean
        }
        if let day = values["weekday"] as? String { entry.weekday = try scheduleWeekday(day) }
        if let start = values["start"] as? String { entry.startMinute = try scheduleTime(start) }
        if let minutes = values["minutes"] as? Int { entry.durationSeconds = minutes == 0 ? nil : minutes * 60 }
        if let notes = values["notes"] as? String { entry.notes = notes }
        if let icon = values["icon"] as? String {
            let clean = icon.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.icon = clean.isEmpty ? scheduleDefaultIcon : clean
        }
        if let color = values["color"] as? String { entry.colorHex = try scheduleColor(color) }
        if let count = values["exerciseCount"] as? Int { entry.exerciseCount = count }
        guard !entry.title.isEmpty else {
            throw AgentToolError("invalid_argument", "An entry needs a workout or a title.", hint: "Pass workout (id or name) or title.")
        }
        return entry
    }

    private func schedulePlan(_ reference: String, in schedule: WeeklyWorkoutSchedule) throws -> WeeklyWorkoutSchedule.Plan {
        let text = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = schedule.plans.first(where: { $0.id.uuidString.caseInsensitiveCompare(text) == .orderedSame }) { return match }
        let named = schedule.plans.filter { AgentValue.fold($0.name) == AgentValue.fold(text) }
        if named.count == 1 { return named[0] }
        if named.count > 1 {
            throw AgentToolError("ambiguous", "\(named.count) plans are named '\(text)'.", hint: "Use one of the ids: \(named.map { $0.id.uuidString }.joined(separator: ", ")).")
        }
        let known = schedule.plans.map(\.name).joined(separator: ", ")
        throw AgentToolError("not_found", "No plan matches '\(text)'.", hint: known.isEmpty ? "There are no saved plans; create_schedule_plan makes one." : "Plans: \(known).")
    }

    private func scheduleTarget(_ args: AgentArguments, in schedule: WeeklyWorkoutSchedule) throws -> (entry: WeeklyWorkoutSchedule.Entry, date: Date) {
        let reference = try args.requiredString("entry")
        var token = reference
        var date: Date?
        if let slash = reference.firstIndex(of: "/") {
            date = try scheduleDay(String(reference[..<slash]))
            token = String(reference[reference.index(after: slash)...])
        }
        if let text = args.string("date") {
            let explicit = try scheduleDay(text)
            if let date, date != explicit {
                throw AgentToolError("invalid_argument", "The occurrence id and date name different days.", hint: "Drop date, or use the day from the occurrence id.")
            }
            date = explicit
        }
        guard let day = date else {
            throw AgentToolError("invalid_argument", "Pass date, or an occurrence id such as 2026-11-25/<entry id>.")
        }
        let key = WeeklyWorkoutSchedule.dayKey(day)
        let entries = schedule.entries(on: day)
        if let match = entries.first(where: { $0.id.uuidString.caseInsensitiveCompare(token) == .orderedSame }) { return (match, day) }
        let titled = entries.filter { AgentValue.fold($0.title) == AgentValue.fold(token) }
        if titled.count == 1 { return (titled[0], day) }
        if titled.count > 1 {
            throw AgentToolError("ambiguous", "\(titled.count) entries on \(key) are titled '\(token)'.", hint: "Use an id: \(titled.map { $0.id.uuidString }.joined(separator: ", ")).")
        }
        let listing = entries.map { "\($0.title) (\($0.id.uuidString))" }.joined(separator: "; ")
        throw AgentToolError("not_found", "No entry matches '\(token)' on \(key).", hint: entries.isEmpty ? "That day has no entries; get_schedule shows what is planned." : "Entries that day: \(listing).")
    }

    private func entryItem(_ entry: WeeklyWorkoutSchedule.Entry, names: [String: String], withStyle: Bool = false) -> [String: Any] {
        var item: [String: Any] = ["id": entry.id.uuidString, "title": entry.title]
        if let workoutID = entry.workoutID {
            item["workoutId"] = workoutID.uuidString
            if let name = names[workoutID.uuidString.lowercased()], name != entry.title { item["workout"] = name }
        }
        if let start = entry.startMinute { item["start"] = clock(start) }
        if let seconds = entry.durationSeconds { item["minutes"] = seconds / 60 }
        if let count = entry.exerciseCount { item["exercises"] = count }
        if !entry.notes.isEmpty { item["notes"] = entry.notes }
        if withStyle {
            item["icon"] = entry.icon
            item["color"] = entry.colorHex
        }
        return item
    }

    private func orderedPlanEntries(_ plan: WeeklyWorkoutSchedule.Plan) -> [WeeklyWorkoutSchedule.Entry] {
        plan.entries.sorted {
            if $0.weekday != $1.weekday { return $0.weekday < $1.weekday }
            if $0.startMinute != $1.startMinute { return ($0.startMinute ?? 1440) < ($1.startMinute ?? 1440) }
            return $0.title < $1.title
        }
    }

    private func planItem(_ plan: WeeklyWorkoutSchedule.Plan, inUse: Bool, names: [String: String]) -> [String: Any] {
        var item: [String: Any] = ["id": plan.id.uuidString, "name": plan.name, "icon": plan.icon]
        if inUse { item["inUse"] = true }
        item["entries"] = orderedPlanEntries(plan).map { entry -> [String: Any] in
            var line = entryItem(entry, names: names, withStyle: true)
            line["weekday"] = scheduleWeekdayNames[entry.weekday - 1]
            return line
        }
        return item
    }

    private func weekLabel(_ date: Date) -> String {
        WeeklyWorkoutSchedule.dayKey(WeeklyWorkoutSchedule.weekStart(date))
    }

    private func getSchedule(_ args: AgentArguments) throws -> AgentToolOutput {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let first = try args.string("date").map { try scheduleDay($0) } ?? today
        let count = args.int("days") ?? 7
        let schedule = try loadSchedule().schedule
        let activity = try scheduleActivity()
        let names = try scheduleWorkoutNames()
        var days: [[String: Any]] = []
        for offset in 0..<count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            var item: [String: Any] = ["date": WeeklyWorkoutSchedule.dayKey(day), "weekday": dayName(day)]
            if day == today { item["today"] = true }
            if schedule.selection(for: day)?.isVacation == true { item["vacation"] = true }
            let occurrences = schedule.occurrences(on: day, activity: activity)
            if !occurrences.isEmpty {
                item["entries"] = occurrences.map { occurrence -> [String: Any] in
                    var line = entryItem(occurrence.entry, names: names)
                    line["occurrence"] = occurrence.id
                    line["done"] = occurrence.isComplete
                    if occurrence.isManual { line["markedByHand"] = true }
                    return line
                }
            }
            days.append(item)
        }
        var week: [String: Any] = ["start": weekLabel(first)]
        if let selection = schedule.selection(for: first) {
            if let plan = selection.plan { week["plan"] = plan.name } else { week["vacation"] = true }
        }
        var value: [String: Any] = ["today": WeeklyWorkoutSchedule.dayKey(today), "week": week, "days": days]
        value["trainingDays"] = schedule.challenge(for: first).weekdays.map { scheduleWeekdayNames[$0 - 1] }
        if let started = schedule.startedOn {
            value["started"] = started
            let progress = schedule.progress(through: now, now: now, activity: activity)
            var streak: [String: Any] = ["weeks": progress.weekNumber, "daysDone": progress.completedDays, "daysRequired": progress.requiredDays]
            if progress.isBroken { streak["broken"] = true }
            if progress.isVacation { streak["vacation"] = true }
            value["streak"] = streak
        }
        if !schedule.plans.isEmpty {
            value["plans"] = schedule.plans.map { ["id": $0.id.uuidString, "name": $0.name, "entries": $0.entries.count] as [String: Any] }
        }
        if schedule.startedOn == nil {
            value["hint"] = "Nothing is scheduled yet. create_schedule_plan with use, select_schedule_plan or add_schedule_entry starts the schedule."
        }
        return AgentToolOutput(value: value)
    }

    private func listSchedulePlans(_ args: AgentArguments) throws -> AgentToolOutput {
        let schedule = try loadSchedule().schedule
        let names = try scheduleWorkoutNames()
        let current = schedule.selection(for: Date())
        var plans = schedule.plans
        if let reference = args.string("plan") { plans = [try schedulePlan(reference, in: schedule)] }
        var value: [String: Any] = ["plans": plans.map { planItem($0, inUse: $0.id == current?.plan?.id, names: names) }]
        if current?.isVacation == true { value["vacation"] = true }
        return AgentToolOutput(value: value)
    }

    private func createSchedulePlan(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let name = try args.requiredString("name")
        let (config, schedule) = try loadSchedule()
        guard !schedule.plans.contains(where: { AgentValue.fold($0.name) == AgentValue.fold(name) }) else {
            throw AgentToolError("already_exists", "A plan named '\(name)' already exists.", hint: "Use update_schedule_plan to change it, or pick another name.")
        }
        let icon = (args.string("icon") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var plan = WeeklyWorkoutSchedule.Plan(name: name, icon: icon.isEmpty ? schedulePlanIcon : icon)
        plan.entries = try args.objects("entries").map { try scheduleEntry(from: $0, base: nil, defaultWeekday: nil) }
        let use = args.bool("use") ?? false
        let from = try args.string("from").map { try scheduleDay($0) } ?? Date()
        var updated = schedule
        updated.savePlan(plan)
        if use { updated.equip(plan, from: from) }
        var value: [String: Any] = ["id": plan.id.uuidString, "name": plan.name, "entries": plan.entries.count]
        if use { value["usedFrom"] = weekLabel(from) } else if !plan.entries.isEmpty { value["hint"] = "Saved only. Pass use (or run select_schedule_plan) to follow it." }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func updateSchedulePlan(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let (config, schedule) = try loadSchedule()
        var plan = try schedulePlan(try args.requiredString("plan"), in: schedule)
        var changed: [String] = []
        if let name = args.string("name") {
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { throw AgentToolError("invalid_argument", "'name' must not be empty.") }
            if schedule.plans.contains(where: { $0.id != plan.id && AgentValue.fold($0.name) == AgentValue.fold(clean) }) {
                throw AgentToolError("already_exists", "A plan named '\(clean)' already exists.")
            }
            plan.name = clean
            changed.append("name")
        }
        if let icon = args.string("icon") {
            let clean = icon.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.icon = clean.isEmpty ? schedulePlanIcon : clean
            changed.append("icon")
        }
        if args.has("entries") {
            guard !args.has("addEntries"), !args.has("removeEntries") else {
                throw AgentToolError("invalid_argument", "entries replaces every entry; do not combine it with addEntries or removeEntries.")
            }
            let existing = plan.entries
            plan.entries = try args.objects("entries").map { values in
                let base = (values["id"] as? String).flatMap { raw in existing.first { $0.id.uuidString.caseInsensitiveCompare(raw.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame } }
                return try scheduleEntry(from: values, base: base, defaultWeekday: nil)
            }
            changed.append("entries")
        }
        if let ids = args.strings("removeEntries") {
            for raw in ids {
                let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard plan.entries.contains(where: { $0.id.uuidString.caseInsensitiveCompare(id) == .orderedSame }) else {
                    throw AgentToolError("not_found", "The plan has no entry '\(id)'.", hint: "list_schedule_plans shows entry ids.")
                }
                plan.entries.removeAll { $0.id.uuidString.caseInsensitiveCompare(id) == .orderedSame }
            }
            changed.append("removeEntries")
        }
        if args.has("addEntries") {
            plan.entries += try args.objects("addEntries").map { try scheduleEntry(from: $0, base: nil, defaultWeekday: nil) }
            changed.append("addEntries")
        }
        guard !changed.isEmpty else { throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass name, icon, entries, addEntries or removeEntries.") }
        let from = try args.string("from").map { try scheduleDay($0) }
        let inUse = schedule.selection(for: Date())?.plan?.id == plan.id
        let apply = args.bool("apply") ?? (inUse || from != nil)
        var updated = schedule
        updated.savePlan(plan)
        if apply { updated.equip(plan, from: from ?? Date()) }
        var value: [String: Any] = ["id": plan.id.uuidString, "name": plan.name, "entries": plan.entries.count, "changed": changed]
        if apply { value["appliedFrom"] = weekLabel(from ?? Date()) } else { value["hint"] = "Saved only; weeks keep their copy until the plan is applied (select_schedule_plan)." }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func deleteSchedulePlan(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let (config, schedule) = try loadSchedule()
        let plan = try schedulePlan(try args.requiredString("plan"), in: schedule)
        var updated = schedule
        updated.plans.removeAll { $0.id == plan.id }
        let value: [String: Any] = ["deleted": plan.name, "id": plan.id.uuidString, "note": "Weeks that follow this plan keep their copy."]
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func selectSchedulePlan(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let vacation = args.bool("vacation") ?? false
        guard vacation != (args.string("plan") != nil) else {
            throw AgentToolError("invalid_argument", "Pass exactly one of plan or vacation.")
        }
        let (config, schedule) = try loadSchedule()
        let week = try args.string("week").map { try scheduleDay($0) } ?? Date()
        var updated = schedule
        var value: [String: Any] = ["from": weekLabel(week)]
        if vacation {
            updated.equip(nil, from: week)
            value["vacation"] = true
        } else {
            let plan = try schedulePlan(try args.requiredString("plan"), in: schedule)
            updated.equip(plan, from: week)
            value["plan"] = plan.name
        }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func addScheduleEntry(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let date = try scheduleDay(try args.requiredString("date"))
        guard args.has("workout") || args.has("title") else {
            throw AgentToolError("invalid_argument", "An entry needs a workout or a title.", hint: "Pass workout (id or name) or title.")
        }
        let (config, schedule) = try loadSchedule()
        let entry = try scheduleEntry(from: args.values, base: nil, defaultWeekday: WeeklyWorkoutSchedule.weekday(date))
        let repeats = args.bool("repeat") ?? false
        let key = WeeklyWorkoutSchedule.dayKey(date)
        var updated = schedule
        var value: [String: Any] = ["id": entry.id.uuidString, "occurrence": "\(key)/\(entry.id.uuidString)", "date": key, "title": entry.title, "repeats": repeats]
        if repeats {
            let selection = schedule.selection(for: date)
            if selection?.isVacation == true {
                throw AgentToolError("vacation_week", "That week is a vacation, so a repeating entry has no plan to join.", hint: "Pick a plan first with select_schedule_plan, then add the entry.")
            }
            var plan = selection?.plan ?? WeeklyWorkoutSchedule.Plan(name: "My Plan")
            plan.entries.removeAll { $0.id == entry.id }
            plan.entries.append(entry)
            updated.savePlan(plan)
            updated.equip(plan, from: date)
            value["plan"] = plan.name
        } else {
            updated.setEntry(entry, on: date)
            if schedule.selection(for: date)?.isVacation == true {
                value["warning"] = "That week is a vacation, so the entry stays hidden until a plan is chosen."
            }
        }
        if args.bool("done") == true { updated.setComplete(true, entryID: entry.id, on: date) }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func addScheduleEntries(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let items = args.objects("entries")
        guard !items.isEmpty, items.count <= 200 else {
            throw AgentToolError("invalid_argument", "Pass between 1 and 200 entries.")
        }
        let (config, schedule) = try loadSchedule()
        var updated = schedule
        var added: [[String: Any]] = []
        var hidden = 0
        for (position, values) in items.enumerated() {
            do {
                let date = try scheduleDay(values["date"] as? String ?? "")
                guard values["workout"] != nil || values["title"] != nil else {
                    throw AgentToolError("invalid_argument", "An entry needs a workout or a title.", hint: "Pass workout (id or name) or title.")
                }
                let entry = try scheduleEntry(from: values, base: nil, defaultWeekday: WeeklyWorkoutSchedule.weekday(date))
                updated.setEntry(entry, on: date)
                if values["done"] as? Bool == true { updated.setComplete(true, entryID: entry.id, on: date) }
                if schedule.selection(for: date)?.isVacation == true { hidden += 1 }
                let key = WeeklyWorkoutSchedule.dayKey(date)
                var line: [String: Any] = ["id": entry.id.uuidString, "occurrence": "\(key)/\(entry.id.uuidString)", "date": key, "title": entry.title]
                if let start = entry.startMinute { line["start"] = clock(start) }
                added.append(line)
            } catch {
                let failure = AgentToolError.translating(error)
                throw AgentToolError("entry_failed", "Entry \(position) failed: \(failure.message)", hint: failure.hint, details: ["index": position, "cause": failure.code])
            }
        }
        var value: [String: Any] = ["added": added.count, "entries": added]
        if hidden > 0 { value["warning"] = "\(hidden) entr\(hidden == 1 ? "y is" : "ies are") in a vacation week and stay hidden until a plan is chosen." }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func updateScheduleEntry(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let (config, schedule) = try loadSchedule()
        let target = try scheduleTarget(args, in: schedule)
        let editable = ["workout", "title", "start", "minutes", "notes", "icon", "color", "exerciseCount", "weekday", "moveTo"]
        let changed = editable.filter { args.has($0) }
        guard !changed.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass workout, title, start, minutes, notes, icon, color, exerciseCount, weekday (scope plan) or moveTo (scope day).")
        }
        let scope = args.string("scope") ?? "day"
        let key = WeeklyWorkoutSchedule.dayKey(target.date)
        var updated = schedule
        var value: [String: Any] = ["id": target.entry.id.uuidString, "scope": scope, "date": key, "changed": changed]
        if scope == "plan" {
            guard !args.has("moveTo") else {
                throw AgentToolError("invalid_argument", "moveTo moves one day's entry; it does not go with scope plan.", hint: "Use weekday to move the plan's entry to another weekday.")
            }
            guard var plan = schedule.selection(for: target.date)?.plan, let index = plan.entries.firstIndex(where: { $0.id == target.entry.id }) else {
                throw AgentToolError("not_in_plan", "That entry is not part of the plan in use that week; it only exists on \(key).", hint: "Use scope day to change it.")
            }
            plan.entries[index] = try scheduleEntry(from: args.values, base: plan.entries[index], defaultWeekday: nil)
            updated.savePlan(plan)
            updated.equip(plan, from: target.date)
            updated.additions[key]?.removeAll { $0.id == target.entry.id }
            value["plan"] = plan.name
            value["appliedFrom"] = weekLabel(target.date)
        } else {
            guard !args.has("weekday") else {
                throw AgentToolError("invalid_argument", "weekday moves an entry inside the plan.", hint: "Use scope plan, or moveTo with a date to move this day's entry.")
            }
            var edited = try scheduleEntry(from: args.values, base: target.entry, defaultWeekday: nil)
            if let text = args.string("moveTo") {
                let newDate = try scheduleDay(text)
                edited.weekday = WeeklyWorkoutSchedule.weekday(newDate)
                updated.removeEntry(target.entry, on: target.date)
                updated.setEntry(edited, on: newDate)
                value["movedTo"] = WeeklyWorkoutSchedule.dayKey(newDate)
            } else {
                updated.setEntry(edited, on: target.date)
            }
        }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func removeScheduleEntry(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let (config, schedule) = try loadSchedule()
        let target = try scheduleTarget(args, in: schedule)
        let scope = args.string("scope") ?? "day"
        let key = WeeklyWorkoutSchedule.dayKey(target.date)
        var updated = schedule
        var value: [String: Any] = ["removed": target.entry.title, "id": target.entry.id.uuidString, "scope": scope, "date": key]
        if scope == "plan" {
            guard var plan = schedule.selection(for: target.date)?.plan, plan.entries.contains(where: { $0.id == target.entry.id }) else {
                throw AgentToolError("not_in_plan", "That entry is not part of the plan in use that week; it only exists on \(key).", hint: "Use scope day to take it off that day.")
            }
            plan.entries.removeAll { $0.id == target.entry.id }
            updated.savePlan(plan)
            updated.equip(plan, from: target.date)
            updated.removeEntry(target.entry, on: target.date)
            value["plan"] = plan.name
            value["appliedFrom"] = weekLabel(target.date)
        } else {
            updated.removeEntry(target.entry, on: target.date)
        }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func completeScheduleEntry(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let clear = args.bool("clear") ?? false
        guard !(clear && args.has("done")) else {
            throw AgentToolError("invalid_argument", "Pass done or clear, not both.")
        }
        let (config, schedule) = try loadSchedule()
        let target = try scheduleTarget(args, in: schedule)
        var updated = schedule
        let done = args.bool("done") ?? true
        updated.setComplete(clear ? nil : done, entryID: target.entry.id, on: target.date)
        var value: [String: Any] = ["id": target.entry.id.uuidString, "title": target.entry.title, "date": WeeklyWorkoutSchedule.dayKey(target.date)]
        if clear { value["cleared"] = true } else { value["done"] = done }
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }

    private func setTrainingDays(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let days = Set(try (args.strings("days") ?? []).map { try scheduleWeekday($0) })
        guard !days.isEmpty else { throw AgentToolError("invalid_argument", "'days' must name at least one weekday.") }
        let (config, schedule) = try loadSchedule()
        let from = try args.string("from").map { try scheduleDay($0) } ?? Date()
        var updated = schedule
        updated.setChallenge(weekdays: days, from: from)
        let value: [String: Any] = ["trainingDays": days.sorted().map { scheduleWeekdayNames[$0 - 1] }, "from": weekLabel(from)]
        return try commitSchedule(config, previous: schedule, updated: updated, dryRun: dryRun, value: value)
    }
}
