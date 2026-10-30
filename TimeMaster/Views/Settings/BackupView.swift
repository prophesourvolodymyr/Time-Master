import SwiftUI
import UniformTypeIdentifiers
import TimeMasterCore
#if os(macOS)
import AppKit
#endif

struct BackupView: View {
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var outdoorStore: OutdoorActivityStore
    @ObservedObject var databaseStore: DatabaseStore = .shared

    // Export
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    // Import
    @State private var showFilePicker = false
    @State private var isImporting = false

    // Feedback
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        GeometryReader { viewport in
            let frame = viewport.frame(in: .global)
            let topClearance = max(0, (navigationBounds?.minY ?? frame.minY) - frame.minY - viewport.safeAreaInsets.top)
            let bottomClearance = max(0, frame.maxY - (navigationBounds?.maxY ?? frame.maxY) - viewport.safeAreaInsets.bottom)
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        exportCard
                        importCard
                        infoCard
                    }
                    .padding(16)
                    .padding(.top, topClearance)
                    .padding(.bottom, bottomClearance)
                }
            }
        }
        .font(TimeMasterFont.body())
        .timeMasterNavigationTitle("Backup & Transfer")
        #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
        // Share sheet for export
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        #endif
        // File picker for import
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType("public.zip-archive") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                runImport(from: url)
            case .failure(let error):
                show(title: "Could Not Open File", message: error.localizedDescription)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Sub-views

    private var headerCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .font(.system(size: 44))
                .foregroundColor(.white)
            Text("Transfer Everything")
                .font(TimeMasterFont.black(20, relativeTo: .title3))
                .foregroundColor(.white)
            Text("Export your workouts, exercises, notes, profile, posts and media into one file. AirDrop or share it to another device and import it here.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Export Backup", systemImage: "square.and.arrow.up")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(.white)

            statsRow

            Button {
                runExport()
            } label: {
                HStack(spacing: 10) {
                    if isExporting {
                        TmaxLoadingIndicator(size: 18)
                        Text("Building backup…")
                    } else {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export & Share")
                    }
                }
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(isExporting ? Color.black.opacity(0.5) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isExporting ? Color.white.opacity(0.5) : Color.white)
                .cornerRadius(12)
            }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 12))
            .disabled(isExporting)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(count: workoutStore.workouts.count, label: "Workouts")
            Divider().frame(height: 28).background(Theme.separator)
            statItem(count: workoutStore.historyEntries.count, label: "History")
            Divider().frame(height: 28).background(Theme.separator)
            statItem(count: totalExercises, label: "Exercises")
            Divider().frame(height: 28).background(Theme.separator)
            statItem(count: mediaFileCount, label: "Media")
        }
        .padding(.vertical, 10)
        .background(Theme.surface2)
        .cornerRadius(10)
    }

    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(TimeMasterFont.black(20, relativeTo: .title3))
                .foregroundColor(.white)
            Text(label)
                .font(TimeMasterFont.body(11, relativeTo: .caption2))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Import Backup", systemImage: "square.and.arrow.down")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(.white)

            Text("Items already on this device are never duplicated — only new items are added.")
                .font(TimeMasterFont.caption())
                .foregroundColor(Theme.textSecondary)

            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 10) {
                    if isImporting {
                        TmaxLoadingIndicator(size: 18)
                        Text("Importing…")
                    } else {
                        Image(systemName: "square.and.arrow.down")
                        Text("Choose Backup File")
                    }
                }
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(isImporting ? Color.black.opacity(0.5) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isImporting ? Color.white.opacity(0.5) : Color.white)
                .cornerRadius(12)
            }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 12))
            .disabled(isImporting)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How to transfer", systemImage: "info.circle")
                .font(TimeMasterFont.black(17, relativeTo: .headline)).foregroundColor(.white)

            infoRow("1", "Tap Export & Share on your old phone")
            infoRow("2", "AirDrop the file to your new phone (or save to Files / iCloud Drive)")
            infoRow("3", "On your new phone open this screen and tap Choose Backup File")
            infoRow("4", "Done — everything appears instantly")
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func infoRow(_ step: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(TimeMasterFont.caption())
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Computed stats

    private var totalExercises: Int {
        if MigrationManager.isV2PageMigrationComplete {
            return databaseStore.allPagesFlat.reduce(0) { $0 + ($1.isLeaf ? 1 : 0) }
        }
        return databaseStore.rootExercises.count + countExercises(in: databaseStore.rootFolders)
    }

    private func countExercises(in folders: [ExerciseFolder]) -> Int {
        folders.reduce(0) { $0 + $1.exercises.count + countExercises(in: $1.subfolders) }
    }

    private var mediaFileCount: Int {
        let legacy = (try? FileManager.default.contentsOfDirectory(
            at: PhotoManager.shared.photosDirectoryURL, includingPropertiesForKeys: nil
        )) ?? []
        var files = Set(legacy)
        for page in databaseStore.allPagesFlat {
            files.formUnion(page.mediaURLs)
            if let cover = page.coverImageURL { files.insert(cover) }
        }
        return files.count
    }

    // MARK: - Actions

    private func runExport() {
        isExporting = true
        let snap: BackupManager.ExportSnapshot
        do {
            snap = try BackupManager.shared.snapshot(
                workoutStore: workoutStore,
                databaseStore: databaseStore,
                outdoorStore: outdoorStore
            )
        } catch {
            isExporting = false
            show(title: "Export Failed", message: error.localizedDescription)
            return
        }
        let libraryToken = ExerciseLibraryAccess.shared.capture()
        Task {
            do {
                let url = try await DatabaseSyncStore.shared.performLocalOperation(token: libraryToken) {
                    try BackupManager.shared.export(snapshot: snap)
                }
                await MainActor.run {
                    exportURL = url
                    isExporting = false
                    #if os(iOS)
                    showShareSheet = true
                    #else
                    saveExport(url)
                    #endif
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    show(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }
    #if os(macOS)
    @MainActor
    private func saveExport(_ source: URL) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = source.lastPathComponent
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            guard destination.standardizedFileURL != source.standardizedFileURL else { return }
            Task.detached(priority: .userInitiated) {
                let access = destination.startAccessingSecurityScopedResource()
                defer { if access { destination.stopAccessingSecurityScopedResource() } }
                let staged = destination.deletingLastPathComponent().appendingPathComponent(".tmax-export-" + UUID().uuidString)
                do {
                    defer { try? FileManager.default.removeItem(at: staged) }
                    try FileManager.default.copyItem(at: source, to: staged)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
                    } else {
                        try FileManager.default.moveItem(at: staged, to: destination)
                    }
                } catch {
                    await MainActor.run { show(title: "Export Failed", message: error.localizedDescription) }
                }
            }
        }
    }
    #endif


    private func runImport(from url: URL) {
        isImporting = true
        let libraryToken = ExerciseLibraryAccess.shared.capture()
        Task {
            do {
                let summary = try await DatabaseSyncStore.shared.performLocalOperation(token: libraryToken) {
                    try BackupManager.shared.importBackup(
                        from: url,
                        workoutStore: workoutStore,
                        databaseStore: databaseStore,
                        outdoorStore: outdoorStore
                    )
                }
                await MainActor.run {
                    isImporting = false
                    let msg = "Exercises: \(summary.exercisesImported), Workouts: \(summary.workoutsImported), History: \(summary.historyImported), Outdoor: \(summary.outdoorActivitiesImported)" + (summary.profileImported ? "\nLocal profile and posts imported. Existing profile preferences are retained when merging." : "")
                    show(title: "Import Complete", message: msg)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    show(title: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func show(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - ShareSheet wrapper

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    NavigationStack {
        BackupView()
            .environmentObject(WorkoutStore())
            .environmentObject(OutdoorActivityStore())
    }
    .preferredColorScheme(.dark)
}
