import SwiftUI

struct MenuBarActivityPage: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.menuBarActions) private var actions

    var body: some View {
        let summary = MenuBarActivitySummary.make(
            entries: store.historyEntries,
            now: Date(),
            calendar: .current,
            weeklyGoal: store.weeklyGoal,
            streak: store.streakInfo()
        )
        ScrollView {
            VStack(spacing: 12) {
                if summary.hasHistory {
                    weekCard(summary)
                    chartCard(summary)
                    if !summary.monthByType.isEmpty { typesCard(summary) }
                    recentCard(summary)
                } else {
                    MenuBarCard {
                        MenuBarEmptyState(
                            symbol: "chart.bar.fill",
                            title: "No sessions yet",
                            message: "Finish a workout and your week shows up here."
                        )
                    }
                }
                MenuBarCompactButton(title: "Open Analytics", symbol: "chart.bar.fill", fillsWidth: true) {
                    actions.openPage(.analytics, nil)
                }
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    private func weekCard(_ summary: MenuBarActivitySummary) -> some View {
        MenuBarCard(emphasized: true, padding: 16) {
            HStack(spacing: 16) {
                MenuBarRing(progress: summary.goalProgress, lineWidth: 10) {
                    VStack(spacing: 0) {
                        Text("\(summary.sessionsThisWeek)")
                            .font(WidgetFont.hero(32))
                            .foregroundStyle(Theme.textPrimary)
                        Text(summary.weeklyGoal > 0 ? "of \(summary.weeklyGoal)" : "this week")
                            .font(WidgetFont.label())
                            .foregroundStyle(WidgetTint.graphite.secondaryInk)
                    }
                }
                .frame(width: 104, height: 104)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    summary.weeklyGoal > 0
                        ? "\(summary.sessionsThisWeek) of \(summary.weeklyGoal) sessions this week"
                        : "\(summary.sessionsThisWeek) sessions this week"
                )
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.toolbarOrange)
                        Text("\(summary.streakCurrent)")
                            .font(WidgetFont.hero(32))
                            .foregroundStyle(Theme.textPrimary)
                        Text(summary.streakCurrent == 1 ? "day" : "days")
                            .font(WidgetFont.label())
                            .foregroundStyle(WidgetTint.graphite.secondaryInk)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(summary.streakCurrent) day streak")
                    HStack(spacing: 12) {
                        MenuBarStat(value: "\(summary.streakBest)", caption: "best streak")
                        MenuBarStat(value: MenuBarFormat.minutes(summary.weekSeconds), caption: "this week")
                    }
                }
            }
        }
    }

    private func chartCard(_ summary: MenuBarActivitySummary) -> some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "Last 7 days", trailing: MenuBarFormat.minutes(summary.days.reduce(0) { $0 + $1.seconds }))
            MenuBarCard(padding: 14) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(summary.days) { day in
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 84)
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.toolbarOrange)
                                    .frame(height: barHeight(day.seconds, busiest: summary.busiestDaySeconds))
                            }
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                                .foregroundStyle(day.isToday ? Theme.textPrimary : WidgetTint.graphite.secondaryInk)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(day.date.formatted(.dateTime.weekday(.wide))), \(day.seconds > 0 ? MenuBarFormat.minutes(day.seconds) : "no workout")"
                        )
                    }
                }
            }
        }
    }

    private func barHeight(_ seconds: Int, busiest: Int) -> CGFloat {
        guard seconds > 0, busiest > 0 else { return 0 }
        return max(6, 84 * CGFloat(seconds) / CGFloat(busiest))
    }

    private func typesCard(_ summary: MenuBarActivitySummary) -> some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "This month")
            MenuBarCard(padding: 14) {
                VStack(spacing: 12) {
                    ForEach(summary.monthByType) { share in
                        let tint = WidgetTint.forTypeColor(hex: share.colorHex).accentOnDark
                        VStack(spacing: 5) {
                            HStack {
                                Circle()
                                    .fill(tint)
                                    .frame(width: 8, height: 8)
                                Text(share.typeName)
                                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(MenuBarFormat.minutes(share.seconds))
                                    .font(WidgetFont.label())
                                    .foregroundStyle(WidgetTint.graphite.secondaryInk)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(WidgetTint.graphite.track)
                                    Capsule()
                                        .fill(tint)
                                        .frame(width: max(4, proxy.size.width * share.fraction))
                                }
                            }
                            .frame(height: 6)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func recentCard(_ summary: MenuBarActivitySummary) -> some View {
        VStack(spacing: 8) {
            MenuBarSectionTitle(title: "Recent sessions")
            MenuBarCard(padding: 12) {
                VStack(spacing: 10) {
                    ForEach(summary.recent) { item in
                        Button {
                            if store.workout(id: item.workoutID) != nil {
                                actions.openWorkoutDetail(item.workoutID)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(WorkoutTitle.short(item.name))
                                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(dayLabel(item.date))
                                        .font(WidgetFont.label())
                                        .foregroundStyle(WidgetTint.graphite.secondaryInk)
                                }
                                Spacer(minLength: 6)
                                if item.isPartial { MenuBarChip(text: "PARTIAL") }
                                Text(MenuBarFormat.minutes(item.seconds))
                                    .font(TimeMasterFont.black(13, relativeTo: .subheadline))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MenuBarRowButtonStyle())
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
