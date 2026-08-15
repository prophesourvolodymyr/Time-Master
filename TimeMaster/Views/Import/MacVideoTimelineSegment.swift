#if os(macOS)
import Foundation

struct MacVideoTimelineSegment: Identifiable, Equatable {
    enum Boundary {
        case start
        case end
    }

    let id: UUID
    var startTime: Double
    var endTime: Double

    init(
        id: UUID = UUID(),
        startTime: Double,
        endTime: Double
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }

    var duration: Double {
        max(0, endTime - startTime)
    }

    func contains(_ time: Double) -> Bool {
        time >= startTime && time <= endTime
    }
}
#endif
