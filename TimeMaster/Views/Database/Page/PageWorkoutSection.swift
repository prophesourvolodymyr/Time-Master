import SwiftUI
import TimeMasterCore

/// An exercise's Workout part: the timing it brings into a workout (its length, sets and rests) and the saved workouts
/// that train it, most recently trained first. The plus adds it to another workout.
struct PageWorkoutSection: View {
    let page: ExercisePage
    let onAddToWorkout: () -> Void

    private struct Timing: Identifiable {
        let label: String
        let value: String

        var id: String { label }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            PageSectionHeader(symbol: PageTab.workout.symbol, title: PageTab.workout.title) {
                PageSectionAddButton(label: "Add to Workout", action: onAddToWorkout)
            }
            if page.hasWorkoutConfig {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: SkillMetrics.s2)], spacing: SkillMetrics.s2) {
                    ForEach(timings) { timing in
                        tile(timing)
                    }
                }
            }
            Text("In workouts")
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, SkillMetrics.s2)
                .accessibilityAddTraits(.isHeader)
            PageWorkoutsList(pageID: page.id)
        }
    }

    private var timings: [Timing] {
        let manifest = page.manifest
        let sets = manifest.sets ?? 1
        var timings = [Timing(label: "Duration", value: "\(manifest.duration ?? 0)s")]
        if let count = manifest.sets {
            timings.append(Timing(label: "Sets", value: "\(count)"))
        }
        if let rest = manifest.restBetweenSets, sets > 1 {
            timings.append(Timing(label: "Rest Between Sets", value: "\(rest)s"))
        }
        if let rest = manifest.restAfter {
            timings.append(Timing(label: sets > 1 ? "Big Rest" : "Rest", value: "\(rest)s"))
        }
        return timings
    }

    private func tile(_ timing: Timing) -> some View {
        VStack(spacing: 2) {
            Text(timing.value)
                .font(TimeMasterFont.heading())
                .foregroundStyle(Theme.textPrimary)
            Text(timing.label)
                .font(TimeMasterFont.micro())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SkillMetrics.s3)
        .padding(.horizontal, SkillMetrics.s2)
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
        .accessibilityElement(children: .combine)
    }
}

/// The saved workouts that train a skill, a tutorial or a container (and the pages in it), as a sheet: where their
/// Workouts widget leads. Opening a workout closes it.
struct PageWorkoutsSheet: View {
    let pageID: UUID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PageWorkoutsList(pageID: pageID)
                    .skillsContained(maxWidth: ProfileStyle.readableWidth)
                    .padding(.vertical, SkillMetrics.s5)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Workouts")
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { _ in dismiss() }
        .keyNavHost()
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }
}

/// The links of an exercise or a container as cards with their previews (a video's thumbnail, the site, the title).
/// The page's editor adds and removes them.
struct PageLinksSection: View {
    let urls: [String]
    let metadata: [LinkMetadata]
    let onOpen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            PageSectionHeader(symbol: PageTab.links.symbol, title: PageTab.links.title, count: urls.count)
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                PageLinkRow(
                    info: PageLinkInfo(urlString: url, metadata: preview(for: url, at: index)),
                    onOpen: { onOpen(url) }
                )
            }
        }
    }

    private func preview(for url: String, at index: Int) -> LinkMetadata? {
        metadata.first { $0.url == url } ?? (metadata.indices.contains(index) ? metadata[index] : nil)
    }
}
