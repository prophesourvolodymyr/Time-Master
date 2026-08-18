import Foundation

public struct TimeOfDayManifest: Codable, Equatable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

public struct TypeScheduleManifest: Codable, Equatable {
    public var id: String
    public var folderID: String
    public var type: WorkoutType
    public var daysOfWeek: [Int]
    public var startDate: Date
    public var durationMonths: Int
    public var weeklyGoal: Int
    public var startTime: TimeOfDayManifest?
    public var durationMinutes: Int?
    public var endedAt: Date?

    public init(
        id: String = UUID().uuidString,
        folderID: String,
        type: WorkoutType,
        daysOfWeek: [Int] = [],
        startDate: Date = Date(),
        durationMonths: Int = 3,
        weeklyGoal: Int = 4,
        startTime: TimeOfDayManifest? = nil,
        durationMinutes: Int? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.folderID = folderID
        self.type = type
        self.daysOfWeek = daysOfWeek
        self.startDate = startDate
        self.durationMonths = durationMonths
        self.weeklyGoal = weeklyGoal
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.endedAt = endedAt
    }
}

public struct ConfigManifest: Codable {
    public var customWorkoutTypes: [WorkoutType]
    public var weeklyGoal: Int
    public var restDays: [String]
    public var trainingDays: [Int]
    public var trainingStartDate: Date
    public var trainingDurationMonths: Int
    public var typeSchedules: [TypeScheduleManifest]

    public var kind: String { "config" }

    public init(
        customWorkoutTypes: [WorkoutType] = [],
        weeklyGoal: Int = 4,
        restDays: [String] = [],
        trainingDays: [Int] = [],
        trainingStartDate: Date = Date(),
        trainingDurationMonths: Int = 3,
        typeSchedules: [TypeScheduleManifest] = []
    ) {
        self.customWorkoutTypes = customWorkoutTypes
        self.weeklyGoal = max(1, min(7, weeklyGoal))
        self.restDays = restDays
        self.trainingDays = trainingDays
        self.trainingStartDate = trainingStartDate
        self.trainingDurationMonths = trainingDurationMonths
        self.typeSchedules = typeSchedules
    }
}
