import SwiftUI

struct MenuBarSchedulePage: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.menuBarActions) private var actions

    private var today: Date { Date() }

    private var upcomingDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        return (1...6).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                todaySection
                upcomingSection
                MenuBarCompactButton(title: "Open Schedule", symbol: "calendar", fillsWidth: true) {
                    actions.openPage(.schedule, nil)
                }
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    private var todaySection: some View {
        let items = store.scheduledWorkouts(for: today).filter { !$0.workout.sections.isEmpty }
        let isRest = store.isRestDay(today)
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(today.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if isRest { MenuBarChip(text: "REST DAY", tint: Theme.accent) }
            }
            MenuBarCard(emphasized: !items.isEmpty, padding: 12) {
                if items.isEmpty {
                    MenuBarEmptyState(
                        symbol: isRest ? "moon.zzz.fill" : "calendar.badge.clock",
                        title: isRest ? "Rest day" : "Nothing scheduled",
                        message: isRest
                            ? "Recover well. Your streak is safe today."
                            : "Plan a workout for today in Schedule."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            MenuBarScheduledRow(item: item)
                        }
                    }
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "Next 6 days")
            MenuBarCard(padding: 12) {
                VStack(spacing: 12) {
                    ForEach(upcomingDays, id: \.self) { day in
                        MenuBarUpcomingDayRow(store: store, day: day)
                    }
                }
            }
        }
    }
}

private struct MenuBarUpcomingDayRow: View {
    @ObservedObject var store: WorkoutStore
    let day: Date

    var body: some View {
        let items = store.scheduledWorkouts(for: day).filter { !$0.workout.sections.isEmpty }
        let isRest = store.isRestDay(day)
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(TimeMasterFont.black(11, relativeTo: .caption2))
                    .foregroundStyle(Theme.textSecondary)
                Text(day.formatted(.dateTime.day()))
                    .font(TimeMasterFont.black(20, relativeTo: .title3))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                if items.isEmpty {
                    Text(isRest ? "Rest day" : "Nothing planned")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(isRest ? Theme.accent : Theme.textSecondary)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: item.workout.type.colorHex))
                                .frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                            Text(item.workout.name)
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.hasScheduledTime ? item.timeRangeText : "Any time")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
