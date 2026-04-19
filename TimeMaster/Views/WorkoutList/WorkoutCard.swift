import SwiftUI

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: workout.type.icon)
                    .foregroundColor(Theme.textSecondary)

                Text(workout.name)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: 16) {
                Label("\(workout.sectionCount) sections", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Label(formatDuration(workout.totalDuration), systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 { return "\(minutes)m \(remainingSeconds)s" }
        return "\(seconds)s"
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
