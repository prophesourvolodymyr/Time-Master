import Foundation
import TimeMasterCore

enum OutdoorPrivacyService {
    static let supportedEndpointDistancesMeters = [100, 200, 500]

    static func projectedPoints(
        _ points: [OutdoorTrackPoint],
        hidingEndpointsMeters meters: Int
    ) -> [OutdoorTrackPoint] {
        let projected = OutdoorActivityExportService.privacyProjectedPoints(
            points.map(\.coreValue),
            hidingEndpointsMeters: meters
        )
        return projected.map(OutdoorTrackPoint.init)
    }

    static func points(
        for activity: OutdoorActivity,
        source: [OutdoorTrackPoint],
        privacyApplied: Bool = false
    ) -> [OutdoorTrackPoint] {
        guard privacyApplied || (activity.visibility == .publicVisibility && activity.hideStartFinish) else {
            return source.map { $0 }
        }
        return projectedPoints(source, hidingEndpointsMeters: activity.endpointPrivacyMeters)
    }
}
