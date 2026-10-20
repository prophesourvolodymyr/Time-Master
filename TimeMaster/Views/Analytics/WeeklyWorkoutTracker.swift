import SwiftUI
import Charts

struct WeeklyWorkoutTracker: View {
    enum Metric {
        case sessions
        case trainingTime

        var tracker: AnalyticsTracker {
            switch self {
            case .sessions: .sessions
            case .trainingTime: .trainingTime
            }
        }
    }

    let metric: Metric
    let summary: WorkoutWeekSummary
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(metric.tracker.title, systemImage: metric.tracker.systemImage)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("analytics.tracker.\(metric.tracker.rawValue)")

            Text(formattedValue(sessions: summary.sessions, seconds: summary.seconds))
                .font(TimeMasterFont.title().monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("analytics.total.\(metric.tracker.rawValue)")

            Chart(summary.days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value(metric == .sessions ? "Sessions" : "Minutes", chartValue(day))
                )
                .foregroundStyle(Theme.toolbarOrange)
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                .accessibilityValue(formattedValue(sessions: day.sessions, seconds: day.seconds))
            }
            .chartYScale(domain: 0...max(1, summary.days.reduce(0) { max($0, chartValue($1)) }))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    if let number = value.as(Double.self), metric != .sessions || number.rounded() == number {
                        AxisValueLabel()
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: summary.days.map(\.date)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: chartHeight)

            if summary.sessions == 0 {
                Text("No workouts recorded this week.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
    }

    private func chartValue(_ day: WorkoutWeekSummary.Day) -> Double {
        metric == .sessions ? Double(day.sessions) : Double(day.seconds) / 60
    }

    private func formattedValue(sessions: Int, seconds: Int) -> String {
        if metric == .sessions {
            return "\(sessions) \(sessions == 1 ? "session" : "sessions")"
        }
        return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }
}
