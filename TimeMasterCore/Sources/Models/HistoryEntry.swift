import Foundation

public struct HistoryEntry: Codable {
    public var id: String
    public var workoutId: String
    public var workoutName: String
    public var completedAt: Date
    public var durationCompleted: Int
    public var workoutType: WorkoutType
    public var isPartial: Bool
    public var elapsedSeconds: Int

    public init(
        id: String = UUID().uuidString,
        workoutId: String,
        workoutName: String,
        completedAt: Date = Date(),
        durationCompleted: Int,
        workoutType: WorkoutType = .other,
        isPartial: Bool = false,
        elapsedSeconds: Int = 0
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.durationCompleted = durationCompleted
        self.workoutType = workoutType
        self.isPartial = isPartial
        self.elapsedSeconds = elapsedSeconds
    }
}
