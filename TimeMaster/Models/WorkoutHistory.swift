import Foundation

struct WorkoutHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var workoutId: UUID
    var workoutName: String
    var completedAt: Date
    var durationCompleted: Int

    init(id: UUID = UUID(), workoutId: UUID, workoutName: String, completedAt: Date = Date(), durationCompleted: Int) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.durationCompleted = durationCompleted
    }
}