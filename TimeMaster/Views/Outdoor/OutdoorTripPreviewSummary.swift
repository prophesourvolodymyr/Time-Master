#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorTripPreviewSummary: View {
    let route: PlannedRoute
    let kind: OutdoorActivityKind
    let units: OutdoorUnitSystem
    let isRouting: Bool
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var distanceSize: CGFloat = 40
    @ScaledMetric(relativeTo: .title) private var activitySize: CGFloat = 64

    var body: some View {
        VStack(spacing: 12) {
            if !compact {
                Image(systemName: kind == .bike ? "figure.outdoor.cycle" : kind.iconName)
                    .font(.system(size: activitySize * 0.52, weight: .medium))
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: activitySize, height: activitySize)
                    .background(Theme.toolbarOrange.opacity(0.12), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.toolbarOrange.opacity(0.3), lineWidth: 1))
                    .accessibilityLabel(kind.displayName)
            }
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                metric(route.trip.map { outdoorDurationText(Int($0.activeDurationSeconds.rounded())) } ?? "Unknown", label: "Estimated time")
                    .frame(maxWidth: .infinity)
                let distance = outdoorRouteDistanceParts(route.distanceMeters, units: units)
                VStack(spacing: 2) {
                    Text(distance.value).font(.system(size: distanceSize, weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                    Text(distance.unit).font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
                .layoutPriority(1)
                .accessibilityElement(children: .combine)
                metric(outdoorElevationText(route.trip?.ascentMeters, unitSystem: units), label: "Elevation gain")
                    .frame(maxWidth: .infinity)
            }
            if isRouting {
                ProgressView("Calculating roads…").font(.caption).tint(Theme.toolbarOrange)
            } else if route.trip?.hasBus == true {
                Label("\(outdoorDistanceText(route.trip?.totalDistanceMeters ?? 0, unitSystem: units, precision: true)) total with bus", systemImage: "bus.fill")
                    .font(.caption).foregroundStyle(.yellow)
            } else if route.trip == nil {
                Text("Imported track · Editing stops recalculates the roads locally")
                    .font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}
#endif
