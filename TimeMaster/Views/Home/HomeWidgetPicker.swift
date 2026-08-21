import SwiftUI

struct HomeWidgetPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @ObservedObject var widgetStore: HomeWidgetStore

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    ForEach(HomeWidgetCategory.allCases) { category in
                        let widgets = widgetStore.availableKinds.filter { $0.category == category }
                        if !widgets.isEmpty {
                            categorySection(category, widgets: widgets)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add Widget")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func categorySection(
        _ category: HomeWidgetCategory,
        widgets: [HomeWidgetKind]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(category.title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(widgets) { kind in
                    widgetCard(kind)
                        .gridCellColumns(pickerFootprint(for: kind).columnSpan)
                }
            }
        }
    }

    private func pickerFootprint(for kind: HomeWidgetKind) -> HomeWidgetFootprint {
        switch kind.category {
        case .workouts:
            .compact
        case .analytics:
            .wide
        default:
            kind.defaultFootprint
        }
    }

    private func widgetCard(_ kind: HomeWidgetKind) -> some View {
        let canAdd = widgetStore.canAdd(kind)
        let footprint = pickerFootprint(for: kind)

        return ZStack(alignment: .topTrailing) {
            HomeWidgetPreview(
                kind: kind,
                footprint: footprint,
                widgetStore: widgetStore,
                workoutStore: workoutStore,
                databaseStore: databaseStore,
                outdoorStore: outdoorStore
            )
            .padding(14)

            Button {
                widgetStore.add(kind, footprint: footprint)
            } label: {
                Image(systemName: canAdd ? "plus" : "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canAdd ? .black : .white)
                    .frame(width: 44, height: 44)
                    .background(
                        canAdd ? Color.green : Theme.surface2,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.8), lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .padding(7)
            .offset(x: 6, y: -6)
        }
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Theme.surface2, Theme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(canAdd ? 0.12 : 0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .opacity(canAdd ? 1 : 0.62)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(canAdd ? "Add \(kind.title) widget" : "\(kind.title) widget already added")
        .accessibilityHint(canAdd ? "Adds this widget to Home" : "This widget is already on Home")
    }
}

private struct HomeWidgetPreview: View {
    let kind: HomeWidgetKind
    let footprint: HomeWidgetFootprint
    @ObservedObject var widgetStore: HomeWidgetStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var databaseStore: DatabaseStore
    @ObservedObject var outdoorStore: OutdoorActivityStore
    @State private var previewDate = Date()

    var body: some View {
        Group {
            if footprint.columnSpan == 1 {
                HStack(spacing: 12) {
                    previewContent
                        .frame(maxWidth: .infinity)
                        .aspectRatio(footprint.aspectRatio, contentMode: .fit)
                    Color.clear
                        .frame(maxWidth: .infinity)
                }
            } else {
                previewContent
                    .frame(maxWidth: .infinity)
                    .aspectRatio(footprint.aspectRatio, contentMode: .fit)
            }
        }
        .allowsHitTesting(false)
        .clipped()
        .onAppear {
            previewDate = Date()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        HomeWidgetContent(
            widget: HomeWidgetInstance(kind: kind, footprint: footprint),
            workoutStore: workoutStore,
            databaseStore: databaseStore,
            outdoorStore: outdoorStore,
            now: previewDate,
            skippedScheduledInstanceIDs: widgetStore.skippedScheduledInstanceIDs,
            onStartWorkout: { _ in },
            onBrowseWorkouts: {},
            onBrowseDatabase: {},
            onCreateWorkout: {},
            onStartOutdoor: { _, _, _ in },
            onSkipScheduledWorkout: { scheduled in
                widgetStore.skipScheduledInstance(id: scheduled.id)
            }
        )
    }
}
