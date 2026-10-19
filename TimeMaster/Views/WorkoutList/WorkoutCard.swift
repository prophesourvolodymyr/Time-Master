import SwiftUI

struct WorkoutCard: View {
    let workout: Workout
    let schedule: ScheduledWorkout?
    let sessionsThisWeek: Int
    let lastCompletedAt: Date?
    let isResumable: Bool

    init(
        workout: Workout,
        schedule: ScheduledWorkout? = nil,
        sessionsThisWeek: Int = 0,
        lastCompletedAt: Date? = nil,
        isResumable: Bool = false
    ) {
        self.workout = workout
        self.schedule = schedule
        self.sessionsThisWeek = sessionsThisWeek
        self.lastCompletedAt = lastCompletedAt
        self.isResumable = isResumable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                WorkoutCoverMosaic(workout: workout, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            categoryBadge
                            durationBadge
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            categoryBadge
                            durationBadge
                        }
                    }
                    if let schedule {
                        scheduleBadge(schedule)
                    } else if isResumable {
                        Text("Ready to resume")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TimeMasterDisclosureIndicator()
            }
            HStack(spacing: 8) {
                if isStretchWorkout {
                    metricBox(value: "\(exerciseCount)", label: "Stretches")
                } else {
                    metricBox(value: "\(setCount)", label: "Sets")
                    metricBox(value: "\(exerciseCount)", label: "Exercises")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(emphasized: isResumable, flat: true))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.name), \(durationText(workout.totalDuration)), \(exerciseCount) \(isStretchWorkout ? "stretches" : "exercises")")
    }

    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: workout.type.iconName)
                .font(.system(size: 9, weight: .bold))
            Text(workout.type.name)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.surface2, in: Capsule())
    }

    private var durationBadge: some View {
        Text(durationText(workout.totalDuration))
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.surface2, in: Capsule())
    }

    private func metricBox(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.headline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduleBadge(_ schedule: ScheduledWorkout) -> some View {
        Text(schedule.status == .completed ? "Completed · \(schedule.timeRangeText)" : schedule.timeRangeText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(schedule.status == .missed ? .red : Theme.textSecondary)
            .lineLimit(1)
    }

    private var exerciseCount: Int {
        workout.sections.count
    }

    private var setCount: Int {
        workout.sections.reduce(0) { $0 + max(1, $1.effectiveSlots.count) }
    }

    private var isStretchWorkout: Bool {
        let category = "\(workout.type.id) \(workout.type.name)".lowercased()
        let hasRepBasedExercise = workout.sections.contains { section in
            section.repCount != nil || section.effectiveSlots.contains { $0.repCount != nil }
        }
        return category.contains("stretch") && !hasRepBasedExercise
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(0, seconds / 60)
        let remaining = max(0, seconds % 60)
        if minutes == 0 { return "\(remaining)s" }
        if remaining == 0 { return "\(minutes)min" }
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)min"
        }
        return "\(minutes)min"
    }
}

struct WorkoutCoverMosaic: View {
    let workout: Workout
    let size: CGFloat
    let styleOverride: WorkoutCoverStyle?

    init(
        workout: Workout,
        size: CGFloat = 82,
        styleOverride: WorkoutCoverStyle? = nil
    ) {
        self.workout = workout
        self.size = size
        self.styleOverride = styleOverride
    }

    var body: some View {
        Group {
            switch styleOverride ?? workout.coverStyle {
            case .customImage:
                if let imageFilename = workout.imageFilename {
                    AsyncCoverImage(
                        url: PhotoManager.shared.photoURL(for: imageFilename),
                        fallbackIcon: workout.type.iconName,
                        fallbackColor: Color(hex: workout.type.colorHex),
                        height: size,
                        contentMode: .fill,
                        overlayGradient: false
                    )
                } else {
                    iconCover
                }
            case .icon:
                iconCover
            case .exerciseThumbnails:
                exerciseMosaic
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(12, size / 6), style: .continuous))
    }

    private var exerciseMosaic: some View {
        let tileSize = max(1, (size - 2) / 2)

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)],
            spacing: 2
        ) {
            ForEach(0..<4, id: \.self) { index in
                if let section = workout.sections[safe: index] {
                    sectionCover(section, size: tileSize)
                } else {
                    Theme.surface2
                        .frame(width: tileSize, height: tileSize)
                }
            }
        }
        .frame(width: size, height: size)
        .background(Theme.surface2)
    }

    @ViewBuilder
    private func sectionCover(_ section: Section, size: CGFloat) -> some View {
        if let media = section.mediaItems.first {
            MediaThumbnailView(item: media, size: size, cornerRadius: 2)
        } else if let page = section.pageID.flatMap({ DatabaseStore.shared.page(id: $0) }),
                  let url = page.coverImageURL {
            AsyncCoverImage(
                url: url,
                fallbackIcon: page.effectiveWorkoutType?.iconName ?? workout.type.iconName,
                fallbackColor: Theme.surface2,
                height: size,
                contentMode: .fill,
                overlayGradient: false
            )
            .frame(width: size, height: size)
        } else {
            Theme.surface2
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: workout.type.iconName)
                        .font(.system(size: max(12, size * 0.3)))
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }

    private var iconCover: some View {
        Color(hex: workout.type.colorHex)
            .opacity(0.32)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: workout.type.iconName)
                    .font(.system(size: max(16, size * 0.3), weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}


#Preview {
    WorkoutCard(workout: Workout(name: "Morning HIIT", sections: [
        Section(name: "Burpees",  duration: 45),
        Section(name: "Push-ups", duration: 30)
    ]))
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
