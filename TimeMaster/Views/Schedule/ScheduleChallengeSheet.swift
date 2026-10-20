import SwiftUI
import TimeMasterCore

struct ScheduleChallengeSheet: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var weekdays: Set<Int>
    @ScaledMetric(relativeTo: .largeTitle) private var flameSize = 96.0
    @ScaledMetric(relativeTo: .body) private var dayWidth = 76.0
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dayWidth))], spacing: 10) {
                        ForEach(1...7, id: \.self) { day in
                            Button {
                                if weekdays.contains(day) { weekdays.remove(day) }
                                else { weekdays.insert(day) }
                            } label: {
                                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 8))
                                layout {
                                    Text(dayName(day)).font(.body.weight(.semibold))
                                    Image(systemName: weekdays.contains(day) ? "checkmark.circle.fill" : "circle")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 0)
                                .foregroundStyle(weekdays.contains(day) ? .white : .secondary)
                                .modifier(TimeMasterGlassSurface(
                                    cornerRadius: 14,
                                    isInteractive: true,
                                    tint: weekdays.contains(day) ? Theme.toolbarOrange : Theme.surface2,
                                    tintOpacity: 0.42
                                ))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(weekdays.contains(day) ? Theme.toolbarOrange.opacity(0.65) : Theme.separator)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dayName(day))
                            .accessibilityAddTraits(weekdays.contains(day) ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Selected days: finish every workout", systemImage: "checkmark.circle")
                        Label("Missed or empty day: reset at midnight", systemImage: "arrow.counterclockwise")
                        Label("Other days are flexible", systemImage: "calendar")
                        Label("Vacation freezes your streak", systemImage: "snowflake")
                        Label("Starts this week; past weeks stay unchanged", systemImage: "arrow.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    if let error = store.scheduleError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    Button {
                        if store.changeWeeklySchedule({ $0.setChallenge(weekdays: weekdays, from: week) }) { dismiss() }
                    } label: {
                        Label(weekdays.isEmpty ? "Choose days" : "Accept \(weekdays.count)-day challenge", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
                    .opacity(weekdays.isEmpty || !store.scheduleIsLoaded ? 0.45 : 1)
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
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func dayName(_ day: Int) -> String {
        Calendar.current.shortWeekdaySymbols[day % 7]
    }
}
