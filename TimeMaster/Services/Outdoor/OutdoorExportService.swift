import Foundation
import TimeMasterCore

enum OutdoorExportService {
    static func gpxURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        privacyApplied: Bool = false
    ) throws -> URL {
        try OutdoorActivityExportService.gpxURL(
            for: activity.coreValue,
            points: exportPoints(for: activity, points: points, privacyApplied: privacyApplied).map(\.coreValue)
        )
    }

    static func fitURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        privacyApplied: Bool = false
    ) throws -> URL {
        try OutdoorActivityExportService.fitURL(
            for: activity.coreValue,
            points: exportPoints(for: activity, points: points, privacyApplied: privacyApplied).map(\.coreValue)
        )
    }

    static func csvURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        privacyApplied: Bool = false
    ) throws -> URL {
        try OutdoorActivityExportService.csvURL(
            for: activity.coreValue,
            points: exportPoints(for: activity, points: points, privacyApplied: privacyApplied).map(\.coreValue)
        )
    }

    static func privacyAppliedGPXURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint]
    ) throws -> URL {
        try gpxURL(for: activity, points: points, privacyApplied: true)
    }

    static func privacyAppliedFITURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint]
    ) throws -> URL {
        try fitURL(for: activity, points: points, privacyApplied: true)
    }

    static func privacyAppliedCSVURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint]
    ) throws -> URL {
        try csvURL(for: activity, points: points, privacyApplied: true)
    }

    static func publicGPXURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint]
    ) throws -> URL {
        try gpxURL(for: activity, points: points, privacyApplied: false)
    }

    static func publicFITURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint]
    ) throws -> URL {
        try fitURL(for: activity, points: points, privacyApplied: false)
    }

    static func shareURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        format: TimeMasterCore.OutdoorExportFormat,
        privacyApplied: Bool = false
    ) throws -> URL {
        switch format {
        case .gpx:
            return try gpxURL(for: activity, points: points, privacyApplied: privacyApplied)
        case .fit:
            return try fitURL(for: activity, points: points, privacyApplied: privacyApplied)
        }
    }

    static func privacyAppliedShareURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        format: TimeMasterCore.OutdoorExportFormat
    ) throws -> URL {
        try shareURL(for: activity, points: points, format: format, privacyApplied: true)
    }

    static func publicShareURL(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        format: TimeMasterCore.OutdoorExportFormat
    ) throws -> URL {
        try shareURL(for: activity, points: points, format: format)
    }

    private static func exportPoints(
        for activity: OutdoorActivity,
        points: [OutdoorTrackPoint],
        privacyApplied: Bool
    ) -> [OutdoorTrackPoint] {
        OutdoorPrivacyService.points(for: activity, source: points, privacyApplied: privacyApplied)
    }
}
