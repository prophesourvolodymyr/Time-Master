#if os(iOS)
import SwiftUI
import UIKit
import TimeMasterCore

struct OutdoorTripDetailsView: View {
    let route: PlannedRoute
    let units: OutdoorUnitSystem
    let onShowLeg: (TripRouteLeg) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Namespace private var namespace
    @State private var expandedLegs: Set<UUID> = []
    @State private var exporting = false
    @State private var image: UIImage?
    @State private var exportError: String?
    @State private var photosDenied = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let trip = route.trip {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(route.title).font(.title2.weight(.bold)).padding(.horizontal, 4)
                        card("summary") {
                            OutdoorTripSummaryView(trip: trip, units: units, action: { EmptyView() }) {
                                Text("Time and effort are route estimates, not a promised finish time.")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        card("roads") {
                            DisclosureGroup {
                                OutdoorTripRoadInfo(unpavedFraction: trip.unpavedFraction, majorRoadFraction: trip.majorRoadFraction)
                                    .padding(.top, 10)
                                Text("Road exposure comes from mapped road classes, not live traffic or a safety rating. Missing surface data stays unknown.")
                                    .font(.caption).foregroundStyle(Theme.textSecondary).padding(.top, 8)
                            } label: {
                                Label("Roads & terrain", systemImage: "road.lanes").font(.headline)
                            }
                            DisclosureGroup {
                                Text(trip.ascentMeters == nil
                                     ? "This route has incomplete elevation coverage. Its climbing and difficulty cannot be reliably assessed."
                                     : "Climbing uses elevation data in the installed area. Riding or running elevation excludes bus legs. \(trip.effortTitle) combines active distance and climbing; it is not a technical trail grade.")
                                    .font(.subheadline).foregroundStyle(Theme.textSecondary).padding(.top, 8)
                                if trip.kind != .bike {
                                    Label(trip.runningGoal.title, systemImage: "figure.run").font(.subheadline).padding(.top, 6)
                                }
                            } label: {
                                Label("Elevation & effort", systemImage: "mountain.2").font(.headline)
                            }
                        }
                        Text("Itinerary").font(.headline).padding(.horizontal, 4)
                        ForEach(Array(trip.legs.enumerated()), id: \.element.id) { index, leg in
                            legCard(leg, index: index, trip: trip)
                        }
                        exportCard
                    }
                    .padding(16)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(route.title).font(.title2.weight(.bold))
                        Text(outdoorDistanceText(route.distanceMeters, unitSystem: units, precision: true)).font(.largeTitle.weight(.bold))
                        Text("Imported track. Road, elevation, and time estimates are unavailable until you edit and calculate its stops.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        exportCard
                    }
                    .padding(16)
                }
            }
            .background(Theme.background)
            .foregroundStyle(Theme.textPrimary)
            .navigationTitle("Trip details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Theme.toolbarOrange)
        .preferredColorScheme(.dark)
    }

    private func legCard(_ leg: TripRouteLeg, index: Int, trip: OutdoorTrip) -> some View {
        card("leg-\(leg.id)") {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: leg.mode == .bus ? "bus.fill" : trip.kind.iconName)
                    .font(.title3).foregroundStyle(leg.mode == .bus ? Color.yellow : .blue)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.stops.indices.contains(index + 1) ? trip.stops[index + 1].name : "Destination \(index + 1)")
                        .font(.headline)
                    Text(leg.mode == .bus ? "Bus road estimate" : trip.kind.displayName)
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                OutdoorPineIconAction(symbol: "map", label: "Show leg \(index + 1) on map") { onShowLeg(leg) }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legMetrics(leg) }
                VStack(alignment: .leading, spacing: 6) { legMetrics(leg) }
            }
            if leg.mode == .bus {
                Text("Yellow dashed route: a road estimate, not a timetabled bus service. Check stops, service, and bike carriage with the operator.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            DisclosureGroup(isExpanded: Binding(get: { expandedLegs.contains(leg.id) }, set: {
                if $0 { expandedLegs.insert(leg.id) } else { expandedLegs.remove(leg.id) }
            })) {
                if leg.mode == .active {
                    OutdoorTripRoadInfo(unpavedFraction: leg.unpavedFraction, majorRoadFraction: leg.majorRoadFraction).padding(.vertical, 8)
                }
                ForEach(Array(leg.instructions.enumerated()), id: \.offset) { number, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(number + 1)").font(.caption.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Theme.toolbarOrange).frame(minWidth: 22)
                        Text(instruction).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 7)
                }
            } label: {
                Label("Directions & road details", systemImage: "arrow.triangle.turn.up.right.diamond").font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("trip.leg.\(index)")
        }
    }

    private func legMetrics(_ leg: TripRouteLeg) -> some View {
        Group {
            Label(outdoorDistanceText(leg.distanceMeters, unitSystem: units, precision: true), systemImage: "ruler")
            Label(outdoorDurationText(Int(leg.durationSeconds.rounded())), systemImage: "clock")
            if leg.mode == .active { Label(outdoorElevationText(leg.ascentMeters, unitSystem: units), systemImage: "mountain.2") }
        }
        .font(.caption.weight(.semibold)).monospacedDigit()
    }

    private func card<Content: View>(_ identity: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        OutdoorPineGlassSurface(identity: "trip-details-\(identity)", namespace: namespace, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 14, content: content)
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
    }

    private var exportCard: some View {
        card("export") {
            Label("Planned Trip image", systemImage: "photo").font(.headline)
            Text("Your route, known estimates, and the Time-Master mark. Saved locally to Photos for sharing.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            Button(action: exportImage) {
                HStack(spacing: 8) {
                    if exporting { ProgressView().tint(.white) }
                    Label(exporting ? "Saving…" : saved ? "Save another copy" : "Save image to Photos", systemImage: "square.and.arrow.down")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            .disabled(exporting || route.trip?.isRouted == false || route.points.count < 2)
            .accessibilityIdentifier("trip.exportImage")
            if saved {
                Label("Saved to Photos", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.green)
            }
            if let exportError {
                Text(exportError).font(.caption).foregroundStyle(Theme.textSecondary)
                if photosDenied, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(settings) }.font(.subheadline.weight(.semibold))
                }
            }
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Planned Trip image preview")
            }
        }
    }

    private func exportImage() {
        exporting = true
        exportError = nil
        photosDenied = false
        saved = false
        Task {
            defer { exporting = false }
            do {
                let service = OutdoorTripImageExportService()
                let generated: UIImage
                if let image { generated = image }
                else { generated = try await service.image(for: route, units: units); image = generated }
                try await service.saveToPhotos(generated)
                saved = true
            } catch {
                photosDenied = error is OutdoorTripImageExportService.ExportError
                exportError = error.localizedDescription
            }
        }
    }
}
#endif
