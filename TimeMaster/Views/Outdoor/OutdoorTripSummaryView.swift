#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripSummaryView<Action: View, Footer: View>: View {
    let trip: OutdoorTrip
    let units: OutdoorUnitSystem
    @ViewBuilder let action: () -> Action
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.isRouted ? outdoorDistanceText(trip.activeDistanceMeters, unitSystem: units, precision: true) : "—")
                        .font(TimeMasterFont.black(26, relativeTo: .title2)).monospacedDigit()
                    Label(trip.kind == .bike ? "Riding distance" : "On-foot distance", systemImage: trip.kind.iconName)
                        .font(TimeMasterFont.caption()).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                if trip.hasBus {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(outdoorDistanceText(trip.totalDistanceMeters, unitSystem: units, precision: true))
                            .font(TimeMasterFont.rowTitle()).monospacedDigit()
                        Label("Total with bus", systemImage: "bus.fill")
                            .font(TimeMasterFont.micro()).foregroundStyle(.yellow)
                    }
                }
                action()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { metrics }
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
                .font(TimeMasterFont.micro()).foregroundStyle(Theme.textSecondary)
            }
            footer()
        }
        .accessibilityElement(children: .contain)
    }

    private var metrics: some View {
        Group {
            metric(trip.isRouted ? outdoorDurationText(Int(trip.activeDurationSeconds.rounded())) : "—", symbol: "clock")
                .accessibilityLabel("Estimated active time \(trip.isRouted ? outdoorDurationText(Int(trip.activeDurationSeconds.rounded())) : "unknown")")
            metric(trip.isRouted ? outdoorElevationText(trip.ascentMeters, unitSystem: units) : "—", symbol: "mountain.2")
                .accessibilityLabel("Elevation gain \(trip.isRouted ? outdoorElevationText(trip.ascentMeters, unitSystem: units) : "unknown")")
            metric(trip.isRouted ? trip.effortTitle : "—", symbol: "gauge.with.dots.needle.50percent")
                .accessibilityLabel("Effort \(trip.isRouted ? trip.effortTitle : "unknown")")
        }
    }

    private func metric(_ value: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.3)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .accessibilityElement(children: .ignore)
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
                Label(title, systemImage: symbol).font(TimeMasterFont.body(15, relativeTo: .subheadline))
                Spacer(minLength: 8)
                Text(fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "Unknown")
                    .font(TimeMasterFont.rowTitle()).monospacedDigit()
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
