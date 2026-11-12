#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import CoreLocation
import MapLibre
import TimeMasterRouting

@MainActor
final class OutdoorOfflineAreas: ObservableObject {
    @Published private(set) var regions: [OfflineTripRegion] = []
    @Published private(set) var styleURL = OfflineTripResources.emptyStyle
    @Published private(set) var isLoading = false
    @Published private(set) var isImporting = false
    @Published var error: String?
    private var coordinates: [TripCoordinate] = []
    private var cancellation: TMRoutingCancellation?

    var displayedRegion: OfflineTripRegion? {
        regions.first { $0.compatible && $0.styleURL == styleURL }
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            regions = try await OutdoorOfflineTripPacks.shared.bootstrap()
            displayCovering(coordinates)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func displayCovering(_ coordinates: [TripCoordinate]) {
        self.coordinates = coordinates
        let available = regions.lazy.filter(\.compatible)
        let covering = available.filter { region in coordinates.allSatisfy(region.manifest.bounds.contains) }
        let origin = coordinates.first.flatMap { point in
            available.filter { $0.manifest.bounds.contains(point) }.min { $0.byteCount < $1.byteCount }
        }
        let selected = covering.min { $0.byteCount < $1.byteCount }
            ?? origin ?? displayedRegion ?? available.min { $0.byteCount < $1.byteCount }
        styleURL = selected?.styleURL ?? OfflineTripResources.emptyStyle
    }

    func install(_ url: URL) async {
        guard !isLoading, !isImporting else { return }
        isImporting = true
        error = nil
        let token = TMRoutingCancellation()
        cancellation = token
        defer { isImporting = false; cancellation = nil }
        do {
            _ = try await withTaskCancellationHandler {
                try await OutdoorOfflineTripPacks.shared.install(url, cancellation: token)
            } onCancel: { token.cancel() }
            regions = try await OutdoorOfflineTripPacks.shared.regions()
            displayCovering(coordinates)
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }

    func cancelImport() { cancellation?.cancel() }

    func remove(_ region: OfflineTripRegion) async {
        guard !isLoading, !isImporting else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await OutdoorOfflineTripPacks.shared.remove(region.id)
            regions = try await OutdoorOfflineTripPacks.shared.regions()
            displayCovering(coordinates)
        } catch { self.error = error.localizedDescription }
    }
}

struct OutdoorOfflineAreasView: View {
    @ObservedObject var model: OutdoorOfflineAreas
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var importing = false
    @State private var removing: OfflineTripRegion?
    @State private var nativeNotices: String?
    @State private var noticeError: String?
    @State private var showsTrust = false
    @State private var showsLicences = false
    @State private var showsNotices = false
    @State private var sourceRegionID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    importCard
                    if let error = model.error {
                        errorCard(error)
                    }
                    installedAreas
                    attribution
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9), value: showsTrust)
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9), value: showsLicences)
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9), value: sourceRegionID)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(Theme.textPrimary)
            .font(TimeMasterFont.body())
            .timeMasterNavigationTitle("Offline areas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(model.isImporting) } }
            .interactiveDismissDisabled(model.isImporting)
            .task {
                do {
                    let data = try OfflineTripResources.data("native-notices.txt")
                    guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                    nativeNotices = text
                } catch { noticeError = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.zip]) { result in
                switch result {
                case .success(let url): Task { await model.install(url) }
                case .failure(let error): model.error = error.localizedDescription
                }
            }
            .confirmationDialog("Remove offline area?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                if let region = removing {
                    Button("Remove \(region.manifest.name)", role: .destructive) { removing = nil; Task { await model.remove(region) } }
                }
                Button("Cancel", role: .cancel) { removing = nil }
            } message: { Text("Saved trips and drafts remain. Editing routes here will require importing this area again.") }
        }
        .tint(Theme.toolbarOrange)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "map.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(TmaxGlow.blaze)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(TmaxGlow.peach.opacity(0.35), lineWidth: 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan offline")
                        .font(TimeMasterFont.sectionTitle())
                        .accessibilityAddTraits(.isHeader)
                    OutdoorChipFlow(spacing: 6) {
                        OutdoorAreaChip(text: "On this device", systemImage: "iphone")
                        OutdoorAreaChip(text: "No account", systemImage: "person.crop.circle.badge.xmark")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Plan offline. Routes, places, addresses and the planning map stay on this device. No routing account or server is needed.")
            if model.isLoading {
                TmaxLoadingIndicator("Preparing offline areas…")
                    .frame(maxWidth: .infinity, minHeight: 52)
            } else if model.isImporting {
                HStack(spacing: 12) {
                    TmaxLoadingIndicator("Installing and checking area…", size: 20)
                    Spacer(minLength: 8)
                    Button("Cancel import", role: .cancel) { model.cancelImport() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
                .frame(minHeight: 52)
            } else {
                OutdoorPinePrimaryAction(title: "Import area", symbol: "square.and.arrow.down", identifier: "trip.area.import") {
                    importing = true
                }
                .accessibilityLabel("Import area from Files")
            }
            infoToggle("Import safety", systemImage: "checkmark.shield", expanded: $showsTrust)
            if showsTrust {
                Text("Import packs only from a source you trust. Checksums detect corruption, not authenticity. Area data is kept separately from saved trips and drafts and is not included in workout backups.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .tmaxGlowSurface(cornerRadius: 26, glow: 0.8)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(message)
                .font(TimeMasterFont.caption())
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.red.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.red.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trip.area.error")
    }

    private var installedAreas: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .accessibilityHidden(true)
                Text("Installed")
                    .font(TimeMasterFont.sectionTitle())
                if !model.regions.isEmpty {
                    Text(model.regions.count.formatted())
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if model.regions.isEmpty, !model.isLoading {
                HStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
                        .accessibilityHidden(true)
                    Text("No areas yet. Import one to plan.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(model.regions) { region in
                areaCard(region)
            }
        }
    }

    private func areaCard(_ region: OfflineTripRegion) -> some View {
        let showsSource = sourceRegionID == region.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                OutdoorOfflineAreaThumbnail(region: region)
                VStack(alignment: .leading, spacing: 8) {
                    Text(region.manifest.name)
                        .font(TimeMasterFont.sectionTitle())
                        .fixedSize(horizontal: false, vertical: true)
                    OutdoorChipFlow(spacing: 6) {
                        OutdoorAreaChip(text: ByteCountFormatter.string(fromByteCount: region.byteCount, countStyle: .file), systemImage: "internaldrive")
                        OutdoorAreaChip(text: region.manifest.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        OutdoorAreaChip(text: region.manifest.hasElevation ? "Elevation" : "No elevation", systemImage: region.manifest.hasElevation ? "mountain.2.fill" : "mountain.2")
                        if !region.compatible {
                            OutdoorAreaChip(text: "Needs update", systemImage: "exclamationmark.triangle.fill", tint: .red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(region.manifest.name)
            .accessibilityValue(areaSummary(region))
            HStack(spacing: 10) {
                infoToggle("Source", systemImage: "info.circle", expanded: Binding(
                    get: { showsSource },
                    set: { sourceRegionID = $0 ? region.id : nil }
                ))
                Spacer(minLength: 8)
                Button(role: .destructive) { removing = region } label: {
                    Label("Remove", systemImage: "trash")
                        .font(TimeMasterFont.black(13, relativeTo: .footnote))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 40))
                .disabled(model.isLoading || model.isImporting)
                .accessibilityLabel("Remove \(region.manifest.name)")
            }
            if showsSource {
                VStack(alignment: .leading, spacing: 6) {
                    Text(region.manifest.source)
                    Text(region.manifest.attribution)
                }
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            }
        }
        .padding(16)
        .tmaxGlowSurface(cornerRadius: 24, glow: 0.4)
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = URL(string: "https://www.openstreetmap.org/copyright") {
                Link(destination: url) {
                    Label("© OpenStreetMap contributors · ODbL 1.0", systemImage: "link")
                        .font(TimeMasterFont.caption())
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            infoToggle("Data and licences", systemImage: "doc.text", expanded: $showsLicences)
            if showsLicences {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Road access and place coverage depend on imported OpenStreetMap data. Bus legs are road estimates, not timetables.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let nativeNotices {
                        infoToggle("Routing engine licenses", systemImage: "chevron.left.forwardslash.chevron.right", expanded: $showsNotices)
                        if showsNotices {
                            Text(nativeNotices)
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let noticeError {
                        Text(noticeError)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(.red)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
    }

    private func infoToggle(_ title: String, systemImage: String, expanded: Binding<Bool>) -> some View {
        Button {
            expanded.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 20)
                Text(title)
                    .font(TimeMasterFont.black(13, relativeTo: .footnote))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(expanded.wrappedValue ? 180 : 0))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(expanded.wrappedValue ? "Expanded" : "Collapsed")
        .accessibilityHint(expanded.wrappedValue ? "Hides details" : "Shows details")
    }

    private func areaSummary(_ region: OfflineTripRegion) -> String {
        var parts = [
            ByteCountFormatter.string(fromByteCount: region.byteCount, countStyle: .file),
            "Imported \(region.manifest.createdAt.formatted(date: .long, time: .omitted))",
            region.manifest.hasElevation ? "Elevation estimates included" : "Hill goals require an elevation-enabled area"
        ]
        if !region.compatible { parts.append("Engine update required: import a matching area version") }
        return parts.joined(separator: ", ")
    }
}

private struct OutdoorAreaChip: View {
    let text: String
    let systemImage: String
    var tint: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(text)
                .font(TimeMasterFont.caption())
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

private struct OutdoorChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(widest, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct OutdoorOfflineAreaThumbnail: View {
    let region: OfflineTripRegion
    @State private var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(0.4))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "map.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.toolbarOrange)
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
        .accessibilityHidden(true)
        .task(id: region.dataID) { await load() }
    }

    private func load() async {
        let key = "\(region.dataID)|\(region.manifest.createdAt.timeIntervalSince1970)" as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }
        guard region.compatible, FileManager.default.fileExists(atPath: region.styleURL.path) else { return }
        let bounds = region.manifest.bounds
        let options = MLNMapSnapshotOptions(
            styleURL: region.styleURL,
            camera: MLNMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: (bounds.south + bounds.north) / 2, longitude: (bounds.west + bounds.east) / 2),
                fromDistance: 1_000, pitch: 0, heading: 0
            ),
            size: CGSize(width: 152, height: 152)
        )
        options.coordinateBounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west),
            ne: CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.east)
        )
        options.showsLogo = false
        options.showsAttribution = false
        let snapshotter = MLNMapSnapshotter(options: options)
        let rendered: UIImage? = await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
        guard !Task.isCancelled, let rendered else { return }
        Self.cache.setObject(rendered, forKey: key)
        image = rendered
    }
}
#endif
