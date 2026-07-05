import Foundation

struct WorkoutHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var workoutId: UUID
    var workoutName: String
    var completedAt: Date
    var durationCompleted: Int
    var workoutType: WorkoutType
    var isPartial: Bool
    var elapsedSeconds: Int

    init(
        id: UUID = UUID(),
        workoutId: UUID,
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

    enum CodingKeys: String, CodingKey {
        case id, workoutId, workoutName, completedAt, durationCompleted, workoutType
        case isPartial, elapsedSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self,   forKey: .id)
        workoutId         = try c.decode(UUID.self,   forKey: .workoutId)
        workoutName       = try c.decode(String.self, forKey: .workoutName)
        completedAt       = try c.decode(Date.self,   forKey: .completedAt)
        durationCompleted = try c.decode(Int.self,    forKey: .durationCompleted)
        workoutType       = try c.decodeIfPresent(WorkoutType.self, forKey: .workoutType) ?? .other
        isPartial         = try c.decodeIfPresent(Bool.self, forKey: .isPartial) ?? false
        elapsedSeconds    = try c.decodeIfPresent(Int.self,  forKey: .elapsedSeconds) ?? 0
    }
}
