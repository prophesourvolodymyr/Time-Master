import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct NotificationPreferences: Codable {
    var isEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var reminderLeadMinutes: Int = 15
    var streakMotivationEnabled: Bool = true
    var missedDayNudgesEnabled: Bool = true
    var restDayAffirmationsEnabled: Bool = true
}

enum NotificationTestOutcome: Equatable {
    case scheduled
    case denied
    case failed(String)
}

final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let preferencesKey = "workout_notification_preferences"
    private let lock = NSLock()
    private var tail: Task<Void, Never> = Task {}

    private enum Prefix {
        static let reminder = "tm_reminder_"
        static let missed = "tm_missed_"
        static let rest = "tm_rest_"
        static let legacy = ["workout_pre_", "workout_post_"]
        static let all = [reminder, missed, rest] + legacy
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

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func sendTestNotification() async -> NotificationTestOutcome {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            status = granted ? .authorized : .denied
        }
        guard status == .authorized || status == .provisional else { return .denied }
        let content = UNMutableNotificationContent()
        content.title = "Tmax notifications are on"
        content.body = "Reminders and workout celebrations will appear like this."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "tm_test_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        do {
            try await center.add(request)
            return .scheduled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func applyPreferences(
        _ newPreferences: NotificationPreferences,
        schedules: [TypeSchedule],
        restDays: Set<String>,
        history: [WorkoutHistoryEntry]? = nil
    ) {
        preferences = newPreferences
        guard newPreferences.isEnabled else {
            replace(prefixes: Prefix.all, with: [])
            return
        }
        let requests = reminderRequests(for: schedules, preferences: newPreferences)
            + restDayRequests(restDays: restDays, enabled: newPreferences.restDayAffirmationsEnabled)
        replace(prefixes: [Prefix.reminder, Prefix.rest] + Prefix.legacy, with: requests)
        if let history {
            refreshMissedDayNudges(schedules: schedules, history: history)
        } else if !newPreferences.missedDayNudgesEnabled {
            replace(prefixes: [Prefix.missed], with: [])
        }
    }

    func rescheduleNotifications(for schedules: [TypeSchedule]) {
        let preferences = preferences
        guard preferences.isEnabled else {
            replace(prefixes: Prefix.all, with: [])
            return
        }
        replace(
            prefixes: [Prefix.reminder] + Prefix.legacy,
            with: reminderRequests(for: schedules, preferences: preferences)
        )
    }

    func refreshMissedDayNudges(schedules: [TypeSchedule], history: [WorkoutHistoryEntry]) {
        let preferences = preferences
        let nudges = preferences.isEnabled && preferences.missedDayNudgesEnabled
            ? NotificationPlanner.missedNudges(
                schedules: schedules,
                history: history,
                hour: preferences.reminderHour,
                minute: preferences.reminderMinute,
                now: Date()
            )
            : []
        replace(prefixes: [Prefix.missed], with: nudges.map(missedNudgeRequest))
    }

    func sendPostWorkoutCelebration() {
        let content = UNMutableNotificationContent()
        content.title = "Workout Complete"
        content.body = postWorkoutMessages.randomElement() ?? "You crushed it!"
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "post_workout_\(UUID().uuidString)",
            content: content,
            trigger: nil
        ))
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

    private func replace(prefixes: [String], with requests: [UNNotificationRequest]) {
        enqueue {
            let center = UNUserNotificationCenter.current()
            let stale = await center.pendingNotificationRequests().map(\.identifier).filter { identifier in
                prefixes.contains { identifier.hasPrefix($0) }
            }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            guard !requests.isEmpty else { return }
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            for request in requests {
                try? await center.add(request)
            }
        }
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        lock.lock()
        defer { lock.unlock() }
        let previous = tail
        tail = Task {
            await previous.value
            await work()
        }
    }

    private func reminderRequests(for schedules: [TypeSchedule], preferences: NotificationPreferences) -> [UNNotificationRequest] {
        let totalMinutes = max(0, preferences.reminderHour * 60 + preferences.reminderMinute - preferences.reminderLeadMinutes)
        var requests: [UNNotificationRequest] = []
        for schedule in schedules where schedule.isActive {
            for day in schedule.daysOfWeek {
                let weekday = Self.calendarWeekday(fromMondayBased: day)
                var components = DateComponents()
                components.weekday = weekday
                components.hour = totalMinutes / 60
                components.minute = totalMinutes % 60
                let content = UNMutableNotificationContent()
                content.title = schedule.type.name
                content.body = reminderMessages.randomElement() ?? "A little \(schedule.type.name.lowercased()) time is waiting for you."
                content.sound = .default
                requests.append(UNNotificationRequest(
                    identifier: "\(Prefix.reminder)\(identifierComponent(schedule.type.id))_\(weekday)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                ))
            }
        }
        return requests
    }

    private func missedNudgeRequest(_ nudge: NotificationPlanner.MissedNudge) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = nudge.type.name
        content.body = missedDayMessages.randomElement() ?? "No sweat. Tomorrow is a fresh start."
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nudge.fireDate)
        return UNNotificationRequest(
            identifier: "\(Prefix.missed)\(identifierComponent(nudge.type.id))_\(Int(nudge.workoutDate.timeIntervalSince1970))",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func restDayRequests(restDays: Set<String>, enabled: Bool) -> [UNNotificationRequest] {
        guard enabled else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var requests: [UNNotificationRequest] = []
        for key in restDays {
            guard let date = formatter.date(from: key), date >= today else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            let content = UNMutableNotificationContent()
            content.title = "Rest day"
            content.body = restDayMessages.randomElement() ?? "Rest is training too. Enjoy it."
            content.sound = .default
            requests.append(UNNotificationRequest(
                identifier: "\(Prefix.rest)\(key)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
        return requests
    }

    private func identifierComponent(_ value: String) -> String {
        value.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
    }

    private static func calendarWeekday(fromMondayBased day: Int) -> Int {
        day == 7 ? 1 : day + 1
    }

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
