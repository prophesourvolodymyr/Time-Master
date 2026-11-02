import Foundation

public struct CoachActivity: Codable, Equatable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case running
        case done
        case failed
    }

    public let id: String
    public var title: String
    public var detail: String?
    public var status: Status

    public init(id: String, title: String, detail: String? = nil, status: Status = .running) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
    }
}
