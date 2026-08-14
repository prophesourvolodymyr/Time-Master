import Foundation
import UserNotifications

// MARK: - WorkoutSchedule

struct WorkoutSchedule: Codable {
    var isEnabled: Bool = false
    var days: Set<Int> = []   // Calendar weekday: 1=Sun, 2=Mon, … 7=Sat
    var hour: Int = 9
    var minute: Int = 0
}

struct NotificationPreferences: Codable {
    var isEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var reminderLeadMinutes: Int = 15
    var streakMotivationEnabled: Bool = true
    var missedDayNudgesEnabled: Bool = true
    var restDayAffirmationsEnabled: Bool = true
}

// MARK: - NotificationManager

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let scheduleKey = "workout_notification_schedule"
    private let preferencesKey = "workout_notification_preferences"

    // MARK: - Persisted schedule

    var schedule: WorkoutSchedule {
        get {
            guard let data = UserDefaults.standard.data(forKey: scheduleKey),
                  let s = try? JSONDecoder().decode(WorkoutSchedule.self, from: data)
            else { return WorkoutSchedule() }
            return s
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: scheduleKey)
            }
        }
    }

    var preferences: NotificationPreferences {
        get {
            guard let data = UserDefaults.standard.data(forKey: preferencesKey),
                  let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
            else { return NotificationPreferences() }
            return preferences
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: preferencesKey)
            }
        }
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    // MARK: - Schedule / cancel

    func scheduleWorkoutNotifications(_ s: WorkoutSchedule) {
        cancelAllWorkoutNotifications()
        guard s.isEnabled, !s.days.isEmpty else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            for day in s.days {
                self.schedulePreWorkout(weekday: day, hour: s.hour, minute: s.minute)
                self.schedulePostWorkout(weekday: day, hour: s.hour, minute: s.minute)
            }
        }
    }

    func rescheduleNotifications(for schedules: [TypeSchedule]) {
        cancelAllWorkoutNotifications()
        let preferences = preferences
        guard preferences.isEnabled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let activeSchedules = schedules.filter(\.isActive)
            for schedule in activeSchedules {
                for day in schedule.daysOfWeek {
                    self.scheduleTypeReminder(
                        type: schedule.type,
                        weekday: Self.calendarWeekday(fromMondayBased: day),
                        hour: preferences.reminderHour,
                        minute: preferences.reminderMinute,
                        leadMinutes: preferences.reminderLeadMinutes
                    )
                }
            }
        }
    }

    func applyPreferences(_ newPreferences: NotificationPreferences, schedules: [TypeSchedule], restDays: Set<String>) {
        preferences = newPreferences
        cancelAllWorkoutNotifications()
        guard newPreferences.isEnabled else { return }
        rescheduleNotifications(for: schedules)
        scheduleRestDayAffirmations(restDays: restDays, enabled: newPreferences.restDayAffirmationsEnabled)
    }

    func refreshMissedDayNudges(schedules: [TypeSchedule], history: [WorkoutHistoryEntry]) {
        let preferences = preferences
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix("tm_missed_") })
            guard preferences.isEnabled, preferences.missedDayNudgesEnabled else { return }
            let calendar = Calendar.current
            let now = Date()
            for schedule in schedules where schedule.isActive {
                for day in schedule.daysOfWeek {
                    guard let workoutDate = self.mostRecentOccurrence(
                        weekday: Self.calendarWeekday(fromMondayBased: day),
                        hour: preferences.reminderHour,
                        minute: preferences.reminderMinute,
                        from: now
                    ), workoutDate <= now else { continue }
                    let start = calendar.startOfDay(for: workoutDate)
                    let didComplete = history.contains {
                        $0.workoutType.id == schedule.type.id && calendar.isDate($0.completedAt, inSameDayAs: start)
                    }
                    guard !didComplete, now >= workoutDate.addingTimeInterval(60 * 60) else { continue }
                    self.scheduleMissedDayNudge(type: schedule.type, after: workoutDate)
                }
            }
        }
    }

    func cancelAllWorkoutNotifications() {
        var ids: [String] = []
        for d in 1...7 {
            ids.append("workout_pre_\(d)")
            ids.append("workout_post_\(d)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["tm_rest_day"])
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let managedIDs = requests.map(\.identifier).filter {
                $0.hasPrefix("tm_reminder_") || $0.hasPrefix("tm_missed_") || $0.hasPrefix("tm_rest_")
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: managedIDs)
        }
    }

    // MARK: - Post-workout celebration (immediate)

    func sendPostWorkoutCelebration() {
        let content = UNMutableNotificationContent()
        content.title = "Workout Complete"
        content.body = postWorkoutMessages.randomElement() ?? "You crushed it!"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "post_workout_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    func notifyWorkoutCompleted(totalWorkouts: Int, streak: Int) {
        let preferences = preferences
        guard preferences.isEnabled else { return }
        if [10, 25, 50, 100].contains(totalWorkouts) {
            sendImmediate(title: "That counts", body: "\(totalWorkouts) workouts is real consistency. Keep going. 🏆")
        }
        if preferences.streakMotivationEnabled, [7, 14, 30, 50, 100].contains(streak) {
            sendImmediate(title: "Streak check", body: "\(streak) days on fire. Your future self noticed. 🔥")
        }
    }

    private func sendImmediate(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "tm_\(UUID().uuidString)", content: content, trigger: nil
        ))
    }

    // MARK: - Private helpers

    private func schedulePreWorkout(weekday: Int, hour: Int, minute: Int) {
        var c = DateComponents()
        c.weekday = weekday
        c.hour = hour
        c.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Time to Train"
        content.body = preWorkoutMessages.randomElement() ?? "Your workout is waiting!"
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "workout_pre_\(weekday)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
        )
        UNUserNotificationCenter.current().add(req)
    }

    private func scheduleTypeReminder(type: WorkoutType, weekday: Int, hour: Int, minute: Int, leadMinutes: Int) {
        var components = DateComponents()
        components.weekday = weekday
        let totalMinutes = max(0, hour * 60 + minute - leadMinutes)
        components.hour = totalMinutes / 60
        components.minute = totalMinutes % 60

        let content = UNMutableNotificationContent()
        content.title = type.name
        content.body = reminderMessages.randomElement() ?? "A little \(type.name.lowercased()) time is waiting for you."
        content.sound = .default
        let id = "tm_reminder_\(notificationIdentifierComponent(type.id))_\(weekday)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        ))
    }

    private func scheduleMissedDayNudge(type: WorkoutType, after workoutDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = type.name
        content.body = missedDayMessages.randomElement() ?? "No sweat. Tomorrow is a fresh start."
        content.sound = .default
        let triggerDate = workoutDate.addingTimeInterval(60 * 60)
        let id = "tm_missed_\(notificationIdentifierComponent(type.id))_\(Int(workoutDate.timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate), repeats: false)
        ))
    }

    private func scheduleRestDayAffirmations(restDays: Set<String>, enabled: Bool) {
        guard enabled else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        for key in restDays {
            guard let date = formatter.date(from: key), date >= calendar.startOfDay(for: Date()) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            let content = UNMutableNotificationContent()
            content.title = "Rest day"
            content.body = restDayMessages.randomElement() ?? "Rest is training too. Enjoy it."
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: "tm_rest_\(key)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }

    private func mostRecentOccurrence(weekday: Int, hour: Int, minute: Int, from date: Date) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        return Calendar.current.nextDate(
            after: date.addingTimeInterval(1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            direction: .backward
        )
    }

    private func notificationIdentifierComponent(_ value: String) -> String {
        value.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
    }

    private static func calendarWeekday(fromMondayBased day: Int) -> Int {
        day == 7 ? 1 : day + 1
    }

    private func schedulePostWorkout(weekday: Int, hour: Int, minute: Int) {
        var postHour = hour + 2
        var postDay  = weekday
        if postHour >= 24 { postHour -= 24; postDay = (postDay % 7) + 1 }

        var c = DateComponents()
        c.weekday = postDay
        c.hour    = postHour
        c.minute  = minute

        let content = UNMutableNotificationContent()
        content.title = "TimeMaster"
        content.body  = postWorkoutMessages.randomElement() ?? "Imagine the feeling now."
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "workout_post_\(weekday)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
        )
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Message pools

    private let preWorkoutMessages = [
        "Your workout is waiting. Let's go.",
        "Time to crush it.",
        "Show up. That's all.",
        "You said today. Today is now.",
        "One session at a time.",
    ]

    private let postWorkoutMessages = [
        "Imagine the feeling now.",
        "That's one more day you showed up.",
        "Done? Feel that? That's growth.",
        "The you from 6 months ago would be proud.",
        "Another one in the bank.",
        "Rest. You've earned it.",
    ]

    private let reminderMessages = [
        "Your plan has a small window waiting for you.",
        "Show up for a few minutes. That is enough to begin.",
        "Your workout is ready when you are.",
        "A little movement can change the rest of the day.",
    ]

    private let missedDayMessages = [
        "No sweat. Tomorrow is a fresh start.",
        "Plans change. You can pick this back up when ready.",
        "One missed day does not erase your progress.",
    ]

    private let restDayMessages = [
        "Rest is training too. Enjoy it.",
        "Today is for recovery. You earned it.",
        "Taking care of yourself counts too.",
    ]
}
