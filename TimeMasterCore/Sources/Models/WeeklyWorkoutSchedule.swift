import Foundation

public struct WeeklyWorkoutSchedule: Codable, Equatable {
    public struct Entry: Codable, Equatable, Identifiable {
        public var id: UUID
        public var workoutID: UUID?
        public var title: String
        public var weekday: Int
        public var startMinute: Int?
        public var durationSeconds: Int?
        public var exerciseCount: Int?
        public var notes: String
        public var icon: String
        public var colorHex: String

        public init(id: UUID = UUID(), workoutID: UUID? = nil, title: String, weekday: Int,
                    startMinute: Int? = nil, durationSeconds: Int? = nil, exerciseCount: Int? = nil,
                    notes: String = "", icon: String = "dumbbell.fill", colorHex: String = "FFFFFF") {
            self.id = id
            self.workoutID = workoutID
            self.title = title
            self.weekday = min(7, max(1, weekday))
            self.startMinute = startMinute.map { min(1439, max(0, $0)) }
            self.durationSeconds = durationSeconds.map { max(0, $0) }
            self.exerciseCount = exerciseCount.map { max(0, $0) }
            self.notes = notes
            self.icon = icon
            self.colorHex = colorHex
        }
    }

    public struct Plan: Codable, Equatable, Identifiable {
        public var id: UUID
        public var name: String
        public var icon: String
        public var entries: [Entry]

        public init(id: UUID = UUID(), name: String, icon: String = "square.stack.3d.up.fill", entries: [Entry] = []) {
            self.id = id
            self.name = name
            self.icon = icon
            self.entries = entries
        }
    }

    public struct Selection: Codable, Equatable {
        public var week: String
        public var plan: Plan?
        public var isVacation: Bool { plan == nil }
    }

    public struct Challenge: Codable, Equatable {
        public var week: String
        public var weekdays: [Int]
    }

    public struct Session {
        public var id: UUID
        public var workoutID: UUID
        public var date: Date

        public init(id: UUID, workoutID: UUID, date: Date) {
            self.id = id
            self.workoutID = workoutID
            self.date = date
        }
    }

    public struct Activity {
        public var sessionsByDay: [String: [Session]]

        public init(sessions: [Session] = [], calendar: Calendar = .current) {
            sessionsByDay = Dictionary(grouping: sessions, by: { WeeklyWorkoutSchedule.dayKey($0.date, calendar: calendar) })
            for key in sessionsByDay.keys {
                sessionsByDay[key]?.sort { $0.date < $1.date }
            }
        }
    }

    public struct Occurrence: Identifiable {
        public var id: String
        public var entry: Entry
        public var date: Date
        public var start: Date?
        public var finish: Date?
        public var isComplete: Bool
        public var matchedSessionID: UUID?
        public var isManual: Bool
    }

    public struct Progress {
        public var weekNumber: Int = 0
        public var completedDays: Int = 0
        public var requiredDays: Int = 0
        public var isBroken = false
        public var isVacation = false
        public init() {}
    }

    public var plans: [Plan] = []
    public var selections: [Selection] = []
    public var additions: [String: [Entry]] = [:]
    public var removals: [String: Set<UUID>] = [:]
    public var completions: [String: Bool] = [:]
    public var challenges: [Challenge] = []
    public var startedOn: String?

    public init() {}

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(for key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func weekday(_ date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    public static func weekStart(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1 - weekday(start, calendar: calendar), to: start) ?? start
    }

    public func selection(for date: Date, calendar: Calendar = .current) -> Selection? {
        let key = Self.dayKey(Self.weekStart(date, calendar: calendar), calendar: calendar)
        return selections.last { $0.week <= key }
    }

    public func challenge(for date: Date, calendar: Calendar = .current) -> Challenge {
        let key = Self.dayKey(Self.weekStart(date, calendar: calendar), calendar: calendar)
        return challenges.last { $0.week <= key } ?? Challenge(week: key, weekdays: [1, 3, 5])
    }

    public mutating func setChallenge(weekdays: Set<Int>, from date: Date, calendar: Calendar = .current) {
        let days = weekdays.filter { (1...7).contains($0) }.sorted()
        guard !days.isEmpty else { return }
        let key = Self.dayKey(Self.weekStart(date, calendar: calendar), calendar: calendar)
        challenges.removeAll { $0.week == key }
        challenges.append(Challenge(week: key, weekdays: days))
        challenges.sort { $0.week < $1.week }
    }

    public mutating func savePlan(_ plan: Plan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
    }

    public mutating func equip(_ plan: Plan?, from date: Date, now: Date = Date(), calendar: Calendar = .current) {
        let monday = Self.weekStart(date, calendar: calendar)
        let key = Self.dayKey(monday, calendar: calendar)
        selections.removeAll { $0.week == key }
        selections.append(Selection(week: key, plan: plan))
        selections.sort { $0.week < $1.week }
        if let plan, !plan.entries.isEmpty {
            startIfNeeded(on: max(monday, calendar.startOfDay(for: now)), calendar: calendar)
        }
    }

    public mutating func setEntry(_ entry: Entry, on date: Date, calendar: Calendar = .current) {
        let key = Self.dayKey(date, calendar: calendar)
        additions[key, default: []].removeAll { $0.id == entry.id }
        additions[key, default: []].append(entry)
        removals[key]?.remove(entry.id)
        startIfNeeded(on: date, calendar: calendar)
    }

    public mutating func removeEntry(_ entry: Entry, on date: Date, calendar: Calendar = .current) {
        let key = Self.dayKey(date, calendar: calendar)
        additions[key]?.removeAll { $0.id == entry.id }
        removals[key, default: []].insert(entry.id)
        completions.removeValue(forKey: "\(key)/\(entry.id.uuidString)")
    }

    public mutating func setComplete(_ complete: Bool?, entryID: UUID, on date: Date, calendar: Calendar = .current) {
        let key = "\(Self.dayKey(date, calendar: calendar))/\(entryID.uuidString)"
        completions[key] = complete
    }

    private mutating func startIfNeeded(on date: Date, calendar: Calendar) {
        let key = Self.dayKey(date, calendar: calendar)
        startedOn = min(startedOn ?? key, key)
    }

    public func entries(on date: Date, calendar: Calendar = .current) -> [Entry] {
        let key = Self.dayKey(date, calendar: calendar)
        guard startedOn.map({ key >= $0 }) ?? false,
              selection(for: date, calendar: calendar)?.isVacation != true else { return [] }
        let day = Self.weekday(date, calendar: calendar)
        let extra = additions[key] ?? []
        let replaced = Set(extra.map(\.id))
        var result = selection(for: date, calendar: calendar)?.plan?.entries.filter {
            $0.weekday == day && !replaced.contains($0.id)
        } ?? []
        result.append(contentsOf: extra)
        let removed = removals[key] ?? []
        result.removeAll { removed.contains($0.id) }
        return result.sorted {
            if $0.startMinute != $1.startMinute { return ($0.startMinute ?? 1440) < ($1.startMinute ?? 1440) }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func occurrences(on date: Date, activity: Activity, calendar: Calendar = .current) -> [Occurrence] {
        let key = Self.dayKey(date, calendar: calendar)
        let sessions = activity.sessionsByDay[key] ?? []
        var used = Set<UUID>()
        return entries(on: date, calendar: calendar).map { entry in
            let id = "\(key)/\(entry.id.uuidString)"
            let matched = sessions.first { $0.workoutID == entry.workoutID && !used.contains($0.id) }
            if let matched { used.insert(matched.id) }
            let start = entry.startMinute.flatMap {
                calendar.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: date)
            }
            let finish = start.flatMap { start in entry.durationSeconds.map { start.addingTimeInterval(Double($0)) } }
            return Occurrence(id: id, entry: entry, date: date, start: start, finish: finish,
                              isComplete: completions[id] ?? (matched != nil), matchedSessionID: matched?.id,
                              isManual: completions[id] != nil)
        }
    }

    public func activityCount(on date: Date, activity: Activity, calendar: Calendar = .current) -> Int {
        let actual = activity.sessionsByDay[Self.dayKey(date, calendar: calendar)]?.count ?? 0
        let manual = occurrences(on: date, activity: activity, calendar: calendar).filter {
            $0.isComplete && $0.matchedSessionID == nil
        }.count
        return actual + manual
    }

    public func progress(through date: Date, now: Date = Date(), activity: Activity, calendar: Calendar = .current) -> Progress {
        var result = Progress()
        guard let startedOn, let start = Self.date(for: startedOn, calendar: calendar) else { return result }
        let target = min(Self.weekStart(date, calendar: calendar), Self.weekStart(now, calendar: calendar))
        var week = Self.weekStart(start, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        while week <= target {
            guard let next = calendar.date(byAdding: .day, value: 7, to: week) else { break }
            let vacation = selection(for: week, calendar: calendar)?.isVacation == true
            if vacation {
                if week == target { result.isVacation = true }
                week = next
                continue
            }
            let required = challenge(for: week, calendar: calendar).weekdays.compactMap {
                calendar.date(byAdding: .day, value: $0 - 1, to: week)
            }.filter { $0 >= start }
            var completed = 0
            var missed = false
            for day in required {
                let items = occurrences(on: day, activity: activity, calendar: calendar)
                if day <= today && !items.isEmpty && items.allSatisfy(\.isComplete) {
                    completed += 1
                } else if day < today {
                    missed = true
                }
            }
            if missed { result.weekNumber = 0 }
            else if !required.isEmpty && (completed == required.count || week == target) {
                result.weekNumber += 1
            }
            if week == target {
                result.completedDays = completed
                result.requiredDays = required.count
                result.isBroken = missed
            }
            week = next
        }
        return result
    }
}
