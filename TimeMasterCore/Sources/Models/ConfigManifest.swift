import Foundation

public struct TypeScheduleManifest: Codable, Equatable {
    public var id: String
    public var folderID: String
    public var type: WorkoutType
    public var daysOfWeek: [Int]
    public var startDate: Date
    public var durationMonths: Int
    public var weeklyGoal: Int
    public var endedAt: Date?

    public init(
        id: String = UUID().uuidString,
        folderID: String,
        type: WorkoutType,
        daysOfWeek: [Int] = [],
        startDate: Date = Date(),
        durationMonths: Int = 3,
        weeklyGoal: Int = 4,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.folderID = folderID
        self.type = type
        self.daysOfWeek = daysOfWeek
        self.startDate = startDate
        self.durationMonths = durationMonths
        self.weeklyGoal = weeklyGoal
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
