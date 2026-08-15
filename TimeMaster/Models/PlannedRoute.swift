import Foundation

enum RouteSource: String, Codable, Equatable {
    case gpxImport
    case manual
    case databasePage
}

struct PlannedRoute: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var points: [OutdoorTrackPoint]
    var source: RouteSource
    var createdAt: Date

    init(id: UUID = UUID(), title: String, points: [OutdoorTrackPoint], source: RouteSource = .manual, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.points = points
        self.source = source
        self.createdAt = createdAt
    }
}
