#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorPlannedRouteCard: View {
    let route: PlannedRoute
    let units: OutdoorUnitSystem
    let onSelect: () -> Void
    @State private var image: UIImage?
    @State private var mapUnavailable = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Group {
                        if let image { Image(uiImage: image).resizable().scaledToFill() }
                        else if mapUnavailable { OutdoorRoutePolylineFallback(points: route.points) }
                        else { ProgressView().tint(Theme.toolbarOrange).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    HStack(alignment: .top, spacing: 4) {
                        Text(route.title).font(.caption.weight(.semibold)).lineLimit(2)
                        if route.starred { Image(systemName: "star.fill").foregroundStyle(Theme.toolbarOrange) }
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(8)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(route.trip.map { outdoorDurationText(Int($0.activeDurationSeconds.rounded())) } ?? "—")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(outdoorDistanceText(route.distanceMeters, unitSystem: units, precision: true))
                        .font(.subheadline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                        .layoutPriority(1)
                    Text(route.trip?.kind.displayName ?? "Track")
                        .font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.title), \(route.trip?.kind.displayName ?? "Imported track"), \(outdoorDistanceText(route.distanceMeters, unitSystem: units))\(route.starred ? ", starred" : "")")
        .accessibilityHint("Open road preview. Long press to star this route.")
        .accessibilityIdentifier("trip.card.\(route.id.uuidString)")
        .task(id: route.trip?.routedAt) {
            guard route.points.count > 1 else { mapUnavailable = true; return }
            do {
                let boundsPoints = route.trip?.stops.map(\.coordinate) ?? route.points.map { TripCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
                let region = try await OutdoorOfflineTripPacks.shared.region(covering: boundsPoints)
                let preview = try await OutdoorMapRouteSnapshotService.shared.tripSnapshot(route, styleURL: region.styleURL, size: CGSize(width: 360, height: 360))
                guard !Task.isCancelled else { return }
                image = preview
            } catch {
                if !Task.isCancelled { mapUnavailable = true }
            }
        }
    }
}
#endif
