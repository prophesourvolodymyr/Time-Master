import Foundation
import TimeMasterCore

enum OutdoorExportService {
    static func gpxURL(for activity: OutdoorActivity, points: [OutdoorTrackPoint]) throws -> URL {
        try OutdoorActivityExportService.gpxURL(for: activity.coreValue, points: points.map(\.coreValue))
    }

    static func csvURL(for activity: OutdoorActivity, points: [OutdoorTrackPoint]) throws -> URL {
        try OutdoorActivityExportService.csvURL(for: activity.coreValue, points: points.map(\.coreValue))
    }
}
