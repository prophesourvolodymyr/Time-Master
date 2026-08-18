import SwiftUI

struct HomeWidgetPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @ObservedObject var widgetStore: HomeWidgetStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(HomeWidgetCategory.allCases) { category in
                            let widgets = widgetStore.availableKinds.filter { $0.category == category }
                            if !widgets.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category.title)
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)

                                    LazyVStack(spacing: 14) {
                                        ForEach(widgets) { kind in
                                            widgetOption(kind)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Widget")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func widgetOption(_ kind: HomeWidgetKind) -> some View {
        let canAdd = widgetStore.canAdd(kind)
        return VStack(alignment: .leading, spacing: 12) {
            HomeWidgetPreview(
                kind: kind,
                widgetStore: widgetStore,
                workoutStore: workoutStore,
                databaseStore: databaseStore,
                outdoorStore: outdoorStore
            )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Content-aware shape")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)
                Button(canAdd ? "Add" : "Added") {
                    widgetStore.add(kind)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(canAdd ? .cyan : .gray)
                .disabled(!canAdd)
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HomeWidgetSizing.cornerRadius)
                .stroke(.white.opacity(canAdd ? 0.1 : 0.2), lineWidth: 1)
        }
        .opacity(canAdd ? 1 : 0.64)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(canAdd ? "Preview and add \(kind.title) widget" : "\(kind.title) widget already added")
    }
}

private struct HomeWidgetPreview: View {
    let kind: HomeWidgetKind
    @ObservedObject var widgetStore: HomeWidgetStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var databaseStore: DatabaseStore
    @ObservedObject var outdoorStore: OutdoorActivityStore
    @State private var previewDate = Date()

    var body: some View {
        HomeWidgetContent(
            widget: HomeWidgetInstance(kind: kind, footprint: kind.defaultFootprint),
            workoutStore: workoutStore,
            databaseStore: databaseStore,
            outdoorStore: outdoorStore,
            now: previewDate,
            skippedScheduledInstanceIDs: widgetStore.skippedScheduledInstanceIDs,
            onStartWorkout: { _ in },
            onBrowseWorkouts: {},
            onBrowseDatabase: {},
            onCreateWorkout: {},
            onStartOutdoor: { _, _ in },
            onSkipScheduledWorkout: { scheduled in
                widgetStore.skipScheduledInstance(id: scheduled.id)
            }
        )
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity)
        .aspectRatio(kind.defaultFootprint.aspectRatio, contentMode: .fit)
        .clipped()
        .onAppear {
            previewDate = Date()
        }
    }
}
