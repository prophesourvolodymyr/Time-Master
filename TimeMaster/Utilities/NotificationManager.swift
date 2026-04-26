import Foundation
import UserNotifications

// MARK: - WorkoutSchedule

struct WorkoutSchedule: Codable {
    var isEnabled: Bool = false
    var days: Set<Int> = []   // Calendar weekday: 1=Sun, 2=Mon, … 7=Sat
    var hour: Int = 9
    var minute: Int = 0
}

// MARK: - NotificationManager

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let scheduleKey = "workout_notification_schedule"

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

    func cancelAllWorkoutNotifications() {
        var ids: [String] = []
        for d in 1...7 {
            ids.append("workout_pre_\(d)")
            ids.append("workout_post_\(d)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
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
}
