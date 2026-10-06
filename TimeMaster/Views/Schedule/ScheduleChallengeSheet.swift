import SwiftUI
import TimeMasterCore

struct ScheduleChallengeSheet: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var weekdays: Set<Int>
    @ScaledMetric(relativeTo: .largeTitle) private var flameSize = 96.0
    private let week: Date

    init(week: Date, weekdays: [Int]) {
        self.week = week
        _weekdays = State(initialValue: Set(weekdays))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ScheduleFlame(difficulty: weekdays.count, isBurning: !weekdays.isEmpty)
                        .frame(width: flameSize, height: flameSize)
                    VStack(spacing: 8) {
                        Text("Your pace. Your streak.").font(.title2.bold())
                        Text("Choose the days that count. Complete every planned workout on each chosen day to keep your weekly streak.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 10) {
                        ForEach(1...7, id: \.self) { day in
                            Button {
                                if weekdays.contains(day) { weekdays.remove(day) }
                                else { weekdays.insert(day) }
                            } label: {
                                VStack(spacing: 8) {
                                    Text(dayName(day)).font(.body.weight(.semibold))
                                    Image(systemName: weekdays.contains(day) ? "checkmark.circle.fill" : "circle")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(weekdays.contains(day) ? ScheduleFlame.accent(for: weekdays.count) : .secondary)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dayName(day))
                            .accessibilityAddTraits(weekdays.contains(day) ? .isSelected : [])
                        }
                    }
                    VStack(spacing: 6) {
                        Text(weekdays.isEmpty ? "Choose at least one day" : "\(weekdays.count)-day challenge")
                            .font(.headline)
                        Text("A chosen day with nothing completed breaks the streak after midnight. Other days are flexible. Vacation freezes it.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Applies this week onward. Previous weeks keep their challenge.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    if let error = store.scheduleError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    Button("Use \(weekdays.count)-day challenge") {
                        if store.changeWeeklySchedule({ $0.setChallenge(weekdays: weekdays, from: week) }) { dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .disabled(weekdays.isEmpty || !store.scheduleIsLoaded)
                    .accessibilityIdentifier("schedule.challenge.confirm")
                }
                .padding(24)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Streak challenge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep current") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func dayName(_ day: Int) -> String {
        Calendar.current.shortWeekdaySymbols[day % 7]
    }
}
