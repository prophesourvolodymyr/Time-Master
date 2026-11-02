import SwiftUI
import TimeMasterCore

struct CoachActivityList: View {
    let activity: [CoachActivity]

    private static let visibleLimit = 8

    private var visible: [CoachActivity] {
        Array(activity.suffix(Self.visibleLimit))
    }

    private var hiddenCount: Int {
        max(0, activity.count - Self.visibleLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hiddenCount > 0 {
                Text("\(hiddenCount) earlier steps")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(visible) { item in
                row(item)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func row(_ item: CoachActivity) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            icon(for: item.status)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(TimeMasterFont.body(13, relativeTo: .footnote))
                    .foregroundStyle(item.status == .failed ? Theme.toolbarOrange : Theme.textPrimary)
                    .lineLimit(2)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(item))
    }

    @ViewBuilder
    private func icon(for status: CoachActivity.Status) -> some View {
        switch status {
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.toolbarOrange)
        }
    }

    private func accessibilityText(_ item: CoachActivity) -> String {
        switch item.status {
        case .running: return "\(item.title), in progress"
        case .done: return "\(item.title), done"
        case .failed: return "\(item.title), failed"
        }
    }
}
