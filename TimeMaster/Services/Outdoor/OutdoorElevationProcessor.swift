#if os(iOS)
import Foundation
import CoreLocation
import CoreMotion
import TimeMasterCore

struct OutdoorElevationUpdate: Equatable {
    var elevationMeters: Double?
    var relativeElevationMeters: Double?
    var gainMeters: Double
    var highestElevationMeters: Double?
    var source: OutdoorElevationSource
}

final class OutdoorElevationProcessor: NSObject {
    private(set) var elevationGainMeters = 0.0
    private(set) var highestElevationMeters: Double?
    private(set) var latestBarometricRelativeAltitudeMeters: Double?
    private(set) var isRunning = false
    private(set) var barometerAvailable = false

    var source: OutdoorElevationSource {
        didSet {
            guard source != oldValue else { return }
            previousResolvedElevationMeters = nil
            previousRelativeElevationMeters = nil
            if source == .gps {
                barometricReferenceAbsoluteMeters = nil
                barometricBaselineRelativeMeters = nil
            }
        }
    }
    var noiseThresholdMeters: Double {
        didSet { noiseThresholdMeters = max(0.1, min(noiseThresholdMeters, 25)) }
    }
    var maximumVerticalAccuracyMeters: Double {
        didSet { maximumVerticalAccuracyMeters = max(1, maximumVerticalAccuracyMeters) }
    }

    private let altimeter = CMAltimeter()
    private var previousResolvedElevationMeters: Double?
    private var previousRelativeElevationMeters: Double?
    private var barometricReferenceAbsoluteMeters: Double?
    private var barometricBaselineRelativeMeters: Double?
    private var latestBarometricDate: Date?
    private var lastAnchorDate: Date?

    init(
        source: OutdoorElevationSource = .hybrid,
        noiseThresholdMeters: Double = 1.5,
        maximumVerticalAccuracyMeters: Double = 50
    ) {
        self.source = source
        self.noiseThresholdMeters = max(0.1, min(noiseThresholdMeters, 25))
        self.maximumVerticalAccuracyMeters = max(1, maximumVerticalAccuracyMeters)
        super.init()
        barometerAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            barometerAvailable = false
            return
        }
        barometerAvailable = true
        altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main) { [weak self] data, error in
            guard let self else { return }
            if error != nil {
                self.barometerAvailable = false
                self.clearBarometricSample()
                return
            }
            guard let data else { return }
            let value = data.relativeAltitude.doubleValue
            guard value.isFinite else { return }
            self.barometerAvailable = true
            self.latestBarometricRelativeAltitudeMeters = value
            self.latestBarometricDate = Date()
        }
    }

    func stop() {
        if isRunning, CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.stopRelativeAltitudeUpdates()
        }
        isRunning = false
        latestBarometricDate = nil
        latestBarometricRelativeAltitudeMeters = nil
        previousRelativeElevationMeters = nil
    }

    func reset() {
        elevationGainMeters = 0
        highestElevationMeters = nil
        previousResolvedElevationMeters = nil
        previousRelativeElevationMeters = nil
        barometricReferenceAbsoluteMeters = nil
        barometricBaselineRelativeMeters = nil
        latestBarometricDate = nil
        latestBarometricRelativeAltitudeMeters = nil
        lastAnchorDate = nil
    }

    func process(
        location: CLLocation,
        barometricRelativeAltitudeMeters: Double? = nil
    ) -> OutdoorElevationUpdate {
        if let barometricRelativeAltitudeMeters,
           barometricRelativeAltitudeMeters.isFinite {
            latestBarometricRelativeAltitudeMeters = barometricRelativeAltitudeMeters
            latestBarometricDate = location.timestamp
        }
        let barometric = freshBarometricSample(at: location.timestamp)
        let absolute = acceptedAbsoluteAltitude(from: location)
        if let absolute {
            highestElevationMeters = max(highestElevationMeters ?? absolute, absolute)
            if let barometric,
               barometricReferenceAbsoluteMeters == nil || shouldReanchor(at: location.timestamp) {
                barometricReferenceAbsoluteMeters = absolute
                barometricBaselineRelativeMeters = barometric
                lastAnchorDate = location.timestamp
            }
        }
        if barometricBaselineRelativeMeters == nil, let barometric {
            barometricBaselineRelativeMeters = barometric
        }

        let resolved: Double?
        let relative: Double?
        switch source {
        case .gps:
            resolved = absolute
            relative = nil
        case .barometer, .hybrid:
            if let barometric,
               let reference = barometricReferenceAbsoluteMeters,
               let baseline = barometricBaselineRelativeMeters {
                resolved = reference + (barometric - baseline)
                relative = barometric - baseline
            } else if source == .hybrid {
                resolved = absolute
                relative = nil
            } else if let barometric,
                      let baseline = barometricBaselineRelativeMeters {
                resolved = nil
                relative = barometric - baseline
            } else {
                resolved = nil
                relative = nil
            }
        }

        if let resolved {
            if let previous = previousResolvedElevationMeters {
                let change = resolved - previous
                if change > noiseThresholdMeters {
                    elevationGainMeters += change
                }
            }
            previousResolvedElevationMeters = resolved
        } else if let relative {
            if let previous = previousRelativeElevationMeters {
                let change = relative - previous
                if change > noiseThresholdMeters {
                    elevationGainMeters += change
                }
            }
            previousRelativeElevationMeters = relative
        }
        return OutdoorElevationUpdate(
            elevationMeters: resolved,
            relativeElevationMeters: relative,
            gainMeters: elevationGainMeters,
            highestElevationMeters: highestElevationMeters,
            source: source
        )
    }

    deinit {
        stop()
    }

    private func clearBarometricSample() {
        latestBarometricRelativeAltitudeMeters = nil
        latestBarometricDate = nil
        barometricReferenceAbsoluteMeters = nil
        barometricBaselineRelativeMeters = nil
        previousRelativeElevationMeters = nil
    }

    private func freshBarometricSample(at date: Date) -> Double? {
        guard let latestBarometricDate,
              abs(date.timeIntervalSince(latestBarometricDate)) <= 10 else {
            return nil
        }
        return latestBarometricRelativeAltitudeMeters
    }

    private func shouldReanchor(at date: Date) -> Bool {
        guard let lastAnchorDate else { return true }
        return date.timeIntervalSince(lastAnchorDate) >= 30
    }

    private func acceptedAbsoluteAltitude(from location: CLLocation) -> Double? {
        let altitude = location.altitude
        let accuracy = location.verticalAccuracy
        guard altitude.isFinite, accuracy.isFinite, accuracy >= 0,
              accuracy <= maximumVerticalAccuracyMeters else { return nil }
        return altitude
    }
}
#endif
