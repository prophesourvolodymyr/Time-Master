import Foundation

public struct CoachProgress: Equatable, Sendable {
    public var text: String
    public var activities: [CoachActivity]
    public var statusTitle: String?
    public var isFinished: Bool
    public var failure: String?

    public init(
        text: String = "",
        activities: [CoachActivity] = [],
        statusTitle: String? = nil,
        isFinished: Bool = false,
        failure: String? = nil
    ) {
        self.text = text
        self.activities = activities
        self.statusTitle = statusTitle
        self.isFinished = isFinished
        self.failure = failure
    }
}
