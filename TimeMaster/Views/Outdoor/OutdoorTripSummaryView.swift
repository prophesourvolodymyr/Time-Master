#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripSummaryView<Action: View, Footer: View>: View {
    let trip: OutdoorTrip
    let units: OutdoorUnitSystem
    @ViewBuilder let action: () -> Action
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.isRouted ? outdoorDistanceText(trip.activeDistanceMeters, unitSystem: units, precision: true) : "—")
                        .font(.title2.weight(.bold)).monospacedDigit()
                    Text(trip.kind == .bike ? "Riding distance" : "On-foot distance")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                if trip.hasBus {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(outdoorDistanceText(trip.totalDistanceMeters, unitSystem: units, precision: true))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                        Label("Total with bus", systemImage: "bus.fill")
                            .font(.caption2).foregroundStyle(.yellow)
                    }
                }
                action()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { metrics }
                VStack(alignment: .leading, spacing: 8) { metrics }
            }
            if trip.isRouted {
                HStack(spacing: 12) {
                    if let fraction = trip.unpavedFraction {
                        Label("\(fraction.formatted(.percent.precision(.fractionLength(0)))) unpaved", systemImage: "leaf")
                    }
                    if let fraction = trip.majorRoadFraction {
                        Label("\(fraction.formatted(.percent.precision(.fractionLength(0)))) major roads", systemImage: "road.lanes")
                    }
                }
                .font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            footer()
        }
        .accessibilityElement(children: .contain)
    }

    private var metrics: some View {
        Group {
            Label(trip.isRouted ? outdoorDurationText(Int(trip.activeDurationSeconds.rounded())) : "—", systemImage: "clock")
                .accessibilityLabel("Estimated active time \(trip.isRouted ? outdoorDurationText(Int(trip.activeDurationSeconds.rounded())) : "unknown")")
            Label(trip.isRouted ? outdoorElevationText(trip.ascentMeters, unitSystem: units) : "—", systemImage: "mountain.2")
                .accessibilityLabel("Elevation gain \(trip.isRouted ? outdoorElevationText(trip.ascentMeters, unitSystem: units) : "unknown")")
            Label(trip.isRouted ? trip.effortTitle : "—", systemImage: "gauge.with.dots.needle.50percent")
        }
        .font(.caption.weight(.semibold)).monospacedDigit()
    }
}

struct OutdoorTripRoadInfo: View {
    let unpavedFraction: Double?
    let majorRoadFraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            fractionRow("Unpaved surface", symbol: "leaf", fraction: unpavedFraction, color: Theme.toolbarOrange)
            fractionRow("Major-road exposure", symbol: "road.lanes", fraction: majorRoadFraction, color: .blue)
        }
    }

    private func fractionRow(_ title: String, symbol: String, fraction: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: symbol).font(.subheadline)
                Spacer(minLength: 8)
                Text(fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "Unknown")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            if let fraction {
                GeometryReader { proxy in
                    Capsule().fill(Theme.separator)
                        .overlay(alignment: .leading) {
                            Capsule().fill(color).frame(width: proxy.size.width * fraction)
                        }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
        }
    }
}
#endif
