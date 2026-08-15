import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
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
            }
        }
        .navigationTitle("Backup & Transfer")
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
                .font(.title3).fontWeight(.bold)
                .foregroundColor(.white)
            Text("Export all your workouts, exercises, notes and media into one file. AirDrop or share it to any iPhone and import in one tap.")
                .font(.subheadline)
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
                .font(.headline)
                .foregroundColor(.white)

            statsRow

            Button {
                runExport()
            } label: {
                HStack(spacing: 10) {
                    if isExporting {
                        ProgressView().tint(.black).scaleEffect(0.85)
                        Text("Building backup…")
                    } else {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export & Share")
                    }
                }
                .font(.headline)
                .foregroundColor(isExporting ? Color.black.opacity(0.5) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isExporting ? Color.white.opacity(0.5) : Color.white)
                .cornerRadius(12)
            }
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
                .font(.title3).fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Import Backup", systemImage: "square.and.arrow.down")
                .font(.headline)
                .foregroundColor(.white)

            Text("Items already on this device are never duplicated — only new items are added.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 10) {
                    if isImporting {
                        ProgressView().tint(.black).scaleEffect(0.85)
                        Text("Importing…")
                    } else {
                        Image(systemName: "square.and.arrow.down")
                        Text("Choose Backup File")
                    }
                }
                .font(.headline)
                .foregroundColor(isImporting ? Color.black.opacity(0.5) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isImporting ? Color.white.opacity(0.5) : Color.white)
                .cornerRadius(12)
            }
            .disabled(isImporting)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How to transfer", systemImage: "info.circle")
                .font(.headline).foregroundColor(.white)

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
                .font(.caption).fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Computed stats

    private var totalExercises: Int {
        databaseStore.rootExercises.count + countExercises(in: databaseStore.rootFolders)
    }

    private func countExercises(in folders: [ExerciseFolder]) -> Int {
        folders.reduce(0) { $0 + $1.exercises.count + countExercises(in: $1.subfolders) }
    }

    private var mediaFileCount: Int {
        let dir = PhotoManager.shared.photosDirectoryURL
        return (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ).count) ?? 0
    }

    // MARK: - Actions

    private func runExport() {
        isExporting = true
        // Snapshot store state HERE on the main thread before going background
        let snap = BackupManager.shared.snapshot(
            workoutStore: workoutStore,
            databaseStore: databaseStore,
            outdoorStore: outdoorStore
        )
        Task.detached(priority: .userInitiated) {
            do {
                let url = try BackupManager.shared.export(snapshot: snap)
                await MainActor.run {
                    exportURL = url
                    isExporting = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    show(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func runImport(from url: URL) {
        isImporting = true
        Task.detached(priority: .userInitiated) {
            do {
                let summary = try BackupManager.shared.importBackup(
                    from: url,
                    workoutStore: workoutStore,
                    databaseStore: databaseStore,
                    outdoorStore: outdoorStore
                )
                await MainActor.run {
                    isImporting = false
                    let msg = "Exercises: \(summary.exercisesImported), Workouts: \(summary.workoutsImported), History: \(summary.historyImported), Outdoor: \(summary.outdoorActivitiesImported)"
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
