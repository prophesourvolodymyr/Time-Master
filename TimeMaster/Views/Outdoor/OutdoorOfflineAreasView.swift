#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
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
    @State private var importing = false
    @State private var removing: OfflineTripRegion?
    @State private var nativeNotices: String?
    @State private var noticeError: String?

    var body: some View {
        NavigationStack {
            Form {
                importSection
                if let error = model.error {
                    SwiftUI.Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("trip.area.error") }
                }
                installedAreasSection
                attributionSection
            }
            .navigationTitle("Offline areas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(model.isImporting) } }
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
    }

    private var importSection: some View {
        SwiftUI.Section {
            Text("Routes, places, addresses, and the planning map stay on this device. No routing account or server is needed.")
                .foregroundStyle(.secondary)
            if model.isLoading { ProgressView("Preparing offline areas…") }
            else if model.isImporting {
                ProgressView("Installing and checking area…")
                Button("Cancel import", role: .cancel) { model.cancelImport() }
            } else {
                Button { importing = true } label: { Label("Import area from Files", systemImage: "square.and.arrow.down") }
                    .accessibilityIdentifier("trip.area.import")
            }
        } footer: {
            Text("Import packs only from a source you trust. Checksums detect corruption, not authenticity. Area data is kept separately from saved trips and drafts and is not included in workout backups.")
        }
    }

    private var installedAreasSection: some View {
        SwiftUI.Section("Installed areas") {
            if model.regions.isEmpty, !model.isLoading {
                Text("No areas installed. Import an area covering the places where you want to plan.").foregroundStyle(.secondary)
            }
            ForEach(model.regions) { region in
                VStack(alignment: .leading, spacing: 6) {
                    Text(region.manifest.name).font(.headline)
                    Text(ByteCountFormatter.string(fromByteCount: region.byteCount, countStyle: .file)).font(.subheadline).foregroundStyle(.secondary)
                    Text(region.manifest.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    Text(region.manifest.hasElevation ? "Elevation estimates included" : "Hill goals require an elevation-enabled area").font(.caption).foregroundStyle(.secondary)
                    if !region.compatible { Text("Engine update required: import a matching area version.").font(.caption).foregroundStyle(.red) }
                    DisclosureGroup("Data attribution") {
                        Text(region.manifest.source).font(.caption).textSelection(.enabled)
                        Text(region.manifest.attribution).font(.caption).textSelection(.enabled)
                    }
                    Button("Remove area", role: .destructive) { removing = region }
                        .font(.subheadline).disabled(model.isLoading || model.isImporting)
                }.padding(.vertical, 4)
            }
        }
    }

    private var attributionSection: some View {
        SwiftUI.Section("Data attribution") {
            if let url = URL(string: "https://www.openstreetmap.org/copyright") {
                Link("© OpenStreetMap contributors · ODbL 1.0", destination: url)
            }
            Text("Road access and place coverage depend on imported OpenStreetMap data. Bus legs are road estimates, not timetables.")
            if let nativeNotices {
                DisclosureGroup("Routing engine licenses") {
                    Text(nativeNotices).font(.caption).textSelection(.enabled)
                }
            }
            if let noticeError { Text(noticeError).foregroundStyle(.red) }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
#endif
