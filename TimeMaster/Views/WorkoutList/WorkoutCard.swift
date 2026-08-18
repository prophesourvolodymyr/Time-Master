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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text(workout.type.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            }

            if let schedule {
                scheduleBadge(schedule)
            } else if isResumable {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill")
                    Text("Ready to resume")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            }

            HStack(spacing: 0) {
                metric(value: "\(workout.sectionCount)", label: "sections")
                metric(value: durationText(workout.totalDuration), label: "total")
                metric(value: "\(sessionsThisWeek)", label: "this week")

                Spacer(minLength: 12)

                if let lastCompletedAt {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Last done")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                        Text(lastCompletedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                } else {
                    Text(workout.sections.isEmpty ? "Add exercises" : "Not started")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: workout.colorHex).opacity(0.12))
                        .frame(height: 3)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: workout.colorHex))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: workout.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(workout.colorHex == "FFFFFF" ? .black : .white)
            }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(minWidth: 64, alignment: .leading)
    }

    private func scheduleBadge(_ schedule: ScheduledWorkout) -> some View {
        HStack(spacing: 7) {
            Image(systemName: schedule.status == .completed ? "checkmark.circle.fill" : "calendar")
            Text(schedule.status == .completed ? "Completed · \(schedule.timeRangeText)" : schedule.timeRangeText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(schedule.status == .missed ? Color.red : Color.white)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 { return "\(remainder)s" }
        if remainder == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remainder)s"
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
