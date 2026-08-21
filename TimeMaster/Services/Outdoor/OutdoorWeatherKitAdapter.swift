#if os(iOS)
import Foundation
import CoreLocation

struct OutdoorWeatherAttribution: Equatable {
    var serviceName: String
    var legalPageURL: URL
    var combinedMarkLightURL: URL
    var combinedMarkDarkURL: URL
    var squareMarkURL: URL
}

struct OutdoorWeatherPresentation: Equatable {
    var temperatureText: String
    var conditionText: String
    var symbolName: String
    var expiresAt: Date
    var attribution: OutdoorWeatherAttribution
}

enum OutdoorWeatherState: Equatable {
    case disabled
    case loading(previous: OutdoorWeatherPresentation?)
    case fresh(OutdoorWeatherPresentation)
    case cached(OutdoorWeatherPresentation)
    case unavailable(String)

    var presentation: OutdoorWeatherPresentation? {
        switch self {
        case .fresh(let presentation), .cached(let presentation): return presentation
        case .disabled, .loading, .unavailable: return nil
        }
    }
}

#if canImport(WeatherKit)
import WeatherKit

@available(iOS 16.0, *)
@MainActor
final class OutdoorWeatherKitAdapter {
    private struct TemporaryCache {
        var presentation: OutdoorWeatherPresentation
        var expiresAt: Date
        var requestedAt: Date
        var coordinate: CLLocationCoordinate2D
    }

    private let service: WeatherService
    private let onStateChange: ((OutdoorWeatherState) -> Void)?
    private var cache: TemporaryCache?
    private var requestTask: Task<Void, Never>?
    private var lastRequestedCoordinate: CLLocationCoordinate2D?
    private var lastRequestedAt: Date?
    private var requestGeneration = 0

    private(set) var state: OutdoorWeatherState = .disabled {
        didSet {
            guard oldValue != state else { return }
            let updatedState = state
            DispatchQueue.main.async { [weak self] in
                self?.onStateChange?(updatedState)
            }
        }
    }

    init(
        onStateChange: ((OutdoorWeatherState) -> Void)? = nil,
        service: WeatherService = .shared
    ) {
        self.onStateChange = onStateChange
        self.service = service
    }

    deinit {
        requestTask?.cancel()
    }

    func update(location: CLLocation?, enabled: Bool, now: Date = Date()) {
        guard enabled else {
            requestGeneration &+= 1
            requestTask?.cancel()
            requestTask = nil
            cache = nil
            lastRequestedCoordinate = nil
            lastRequestedAt = nil
            state = .disabled
            return
        }

        guard let location else {
            requestGeneration &+= 1
            requestTask?.cancel()
            requestTask = nil
            state = .unavailable("A valid location is required for WeatherKit.")
            return
        }

        if let cache {
            if cache.expiresAt > now {
                state = .cached(cache.presentation)
            } else {
                self.cache = nil
            }
        }

        if let lastRequestedAt,
           let lastRequestedCoordinate,
           now.timeIntervalSince(lastRequestedAt) < 60,
           distance(from: location.coordinate, to: lastRequestedCoordinate) < 500 {
            return
        }

        requestTask?.cancel()
        requestGeneration &+= 1
        let generation = requestGeneration
        lastRequestedCoordinate = location.coordinate
        lastRequestedAt = now
        let previous = cache?.presentation
        state = .loading(previous: previous)
        let service = self.service

        requestTask = Task { [weak self] in
            do {
                let current = try await service.weather(for: location, including: .current)
                let attribution = try await service.attribution
                let presentation = Self.presentation(from: current, attribution: attribution)
                guard presentation.expiresAt > Date() else {
                    await self?.acceptUnavailable(
                        "WeatherKit returned an already-expired response.",
                        generation: generation
                    )
                    return
                }
                await self?.accept(
                    presentation,
                    coordinate: location.coordinate,
                    generation: generation
                )
            } catch is CancellationError {
            } catch {
                await self?.acceptFailure(error, generation: generation)
            }
        }
    }

    private func accept(
        _ presentation: OutdoorWeatherPresentation,
        coordinate: CLLocationCoordinate2D,
        generation: Int
    ) {
        guard generation == requestGeneration else { return }
        let now = Date()
        guard presentation.expiresAt > now else {
            acceptUnavailable(
                "WeatherKit returned an already-expired response.",
                generation: generation
            )
            return
        }
        requestTask = nil
        cache = TemporaryCache(
            presentation: presentation,
            expiresAt: presentation.expiresAt,
            requestedAt: now,
            coordinate: coordinate
        )
        state = .fresh(presentation)
    }

    private func acceptFailure(_ error: Error, generation: Int) {
        guard generation == requestGeneration else { return }
        requestTask = nil
        if let cache, cache.expiresAt > Date() {
            state = .cached(cache.presentation)
        } else {
            cache = nil
            state = .unavailable(error.localizedDescription)
        }
    }

    private func acceptUnavailable(_ message: String, generation: Int) {
        guard generation == requestGeneration else { return }
        requestTask = nil
        if let cache, cache.expiresAt > Date() {
            state = .cached(cache.presentation)
        } else {
            cache = nil
            state = .unavailable(message)
        }
    }

    private static func presentation(
        from current: CurrentWeather,
        attribution: WeatherAttribution
    ) -> OutdoorWeatherPresentation {
        let formatter = MeasurementFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitOptions = .providedUnit
        return OutdoorWeatherPresentation(
            temperatureText: formatter.string(from: current.temperature),
            conditionText: String(describing: current.condition),
            symbolName: current.symbolName,
            expiresAt: current.metadata.expirationDate,
            attribution: OutdoorWeatherAttribution(
                serviceName: attribution.serviceName,
                legalPageURL: attribution.legalPageURL,
                combinedMarkLightURL: attribution.combinedMarkLightURL,
                combinedMarkDarkURL: attribution.combinedMarkDarkURL,
                squareMarkURL: attribution.squareMarkURL
            )
        )
    }

    private func distance(from lhs: CLLocationCoordinate2D, to rhs: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }
}
#else
final class OutdoorWeatherKitAdapter {
    private let onStateChange: ((OutdoorWeatherState) -> Void)?
    private(set) var state: OutdoorWeatherState = .disabled {
        didSet { onStateChange?(state) }
    }

    init(onStateChange: ((OutdoorWeatherState) -> Void)? = nil) {
        self.onStateChange = onStateChange
    }

    func update(location: CLLocation?, enabled: Bool, now: Date = Date()) {
        state = enabled ? .unavailable("WeatherKit is unavailable in this build.") : .disabled
    }
}
#endif
#endif
