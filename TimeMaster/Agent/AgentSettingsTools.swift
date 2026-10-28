import Foundation
import TimeMasterCore

@MainActor
enum AgentSettingsTools {
    static func snapshot() throws -> AgentToolOutput {
        let preferences = NotificationManager.shared.preferences
        let config = try? DatabaseManager.shared.loadConfig()
        let schedules = config?.typeSchedules.map { schedule in
            [
                "type": schedule.type.name,
                "daysOfWeek": schedule.daysOfWeek,
                "weeklyGoal": schedule.weeklyGoal,
                "durationMonths": schedule.durationMonths,
            ] as [String: Any]
        } ?? []
        let value: [String: Any] = [
            "extraRestSeconds": UserDefaults.standard.object(forKey: "extra_rest_seconds") as? Int ?? 15,
            "motivationEnabled": MotivationManager.shared.isEnabled,
            "motivationInterval": MotivationManager.shared.interval,
            "notifications": [
                "enabled": preferences.isEnabled,
                "reminderHour": preferences.reminderHour,
                "reminderMinute": preferences.reminderMinute,
                "reminderLeadMinutes": preferences.reminderLeadMinutes,
                "streakMotivationEnabled": preferences.streakMotivationEnabled,
                "missedDayNudgesEnabled": preferences.missedDayNudgesEnabled,
                "restDayAffirmationsEnabled": preferences.restDayAffirmationsEnabled,
            ] as [String: Any],
            "typeSchedules": schedules,
            "excluded": ["API keys", "provider credentials", "filesystem paths", "music files"],
        ]
        return AgentToolOutput(value: value)
    }

    static func apply(_ args: [String: Any], dryRun: Bool) throws -> AgentToolOutput {
        guard !args.isEmpty else {
            throw AgentToolError("invalid_argument", "Nothing to change.", hint: "Pass at least one supported setting.")
        }
        var changed: [String: Any] = [:]

        if let seconds = args["extraRestSeconds"] as? Int {
            guard (5...120).contains(seconds), seconds.isMultiple(of: 5) else {
                throw AgentToolError("invalid_settings", "extraRestSeconds must be a multiple of 5 from 5 through 120.")
            }
            if !dryRun { UserDefaults.standard.set(seconds, forKey: "extra_rest_seconds") }
            changed["extraRestSeconds"] = seconds
        }
        if let enabled = args["motivationEnabled"] as? Bool {
            if !dryRun { MotivationManager.shared.isEnabled = enabled }
            changed["motivationEnabled"] = enabled
        }
        if let seconds = args["motivationInterval"] as? Int {
            guard (30...120).contains(seconds), seconds.isMultiple(of: 5) else {
                throw AgentToolError("invalid_settings", "motivationInterval must be a multiple of 5 from 30 through 120.")
            }
            if !dryRun { MotivationManager.shared.interval = seconds }
            changed["motivationInterval"] = seconds
        }
        if let values = args["notifications"] as? [String: Any] {
            var preferences = NotificationManager.shared.preferences
            if let value = values["enabled"] as? Bool { preferences.isEnabled = value }
            if let value = values["reminderHour"] as? Int { preferences.reminderHour = value }
            if let value = values["reminderMinute"] as? Int { preferences.reminderMinute = value }
            if let value = values["reminderLeadMinutes"] as? Int {
                guard value.isMultiple(of: 5) else {
                    throw AgentToolError("invalid_settings", "notifications.reminderLeadMinutes must be a multiple of 5 from 0 through 60.")
                }
                preferences.reminderLeadMinutes = value
            }
            if let value = values["streakMotivationEnabled"] as? Bool { preferences.streakMotivationEnabled = value }
            if let value = values["missedDayNudgesEnabled"] as? Bool { preferences.missedDayNudgesEnabled = value }
            if let value = values["restDayAffirmationsEnabled"] as? Bool { preferences.restDayAffirmationsEnabled = value }
            if !dryRun {
                let config = try? DatabaseManager.shared.loadConfig()
                let schedules = config?.typeSchedules.map {
                    TypeSchedule(
                        id: UUID(uuidString: $0.id) ?? UUID(),
                        folderID: UUID(uuidString: $0.folderID),
                        type: WorkoutType(core: $0.type),
                        daysOfWeek: Set($0.daysOfWeek),
                        startDate: $0.startDate,
                        durationMonths: $0.durationMonths,
                        weeklyGoal: $0.weeklyGoal,
                        endedAt: $0.endedAt
                    )
                } ?? []
                NotificationManager.shared.applyPreferences(preferences, schedules: schedules, restDays: Set(config?.restDays ?? []))
            }
            changed["notifications"] = values
        }
        var value: [String: Any] = ["message": dryRun ? "Settings would be updated." : "Settings updated.", "changed": changed]
        if dryRun { value["dryRun"] = true }
        return AgentToolOutput(value: value)
    }
}
