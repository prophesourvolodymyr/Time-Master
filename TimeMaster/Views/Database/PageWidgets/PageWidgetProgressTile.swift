import SwiftUI
import TimeMasterCore

/// Progress: the share of the sub-skills done as a ring, with how many are done and how many are in progress. Without
/// sub-skills it says so. A tap opens them (a folder's pages, for a folder).
struct PageWidgetProgressTile: View {
    let progress: SkillProgress
    let target: PageWidgetTarget
    let onOpen: (PageWidgetTarget) -> Void

    private var isEmpty: Bool { progress.total == 0 && progress.abandoned == 0 }

    var body: some View {
        PageWidgetTile(kind: .progress, target: target, summary: summary, onOpen: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                PageWidgetHeader(kind: .progress, trailing: isEmpty ? nil : progress.summary)
                if isEmpty {
                    PageWidgetEmptyState(systemImage: "circle.dotted", title: "No sub-skills yet")
                } else {
                    HStack(spacing: 14) {
                        ring
                        VStack(alignment: .leading, spacing: 6) {
                            stat(progress.completed, label: "Done", tint: SkillStatus.completed.color)
                            stat(progress.learning, label: "In progress", tint: SkillStatus.learning.color)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(PageWidgetMetrics.inset)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var ring: some View {
        ZStack {
            SkillProgressRing(fraction: progress.fraction, tint: Theme.toolbarOrange, lineWidth: 8)
                .padding(4)
            if progress.fraction < 1 {
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(TimeMasterFont.black(16, relativeTo: .headline).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 12)
            }
        }
        .frame(width: 72, height: 72)
    }

    private func stat(_ value: Int, label: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(TimeMasterFont.black(18, relativeTo: .headline).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var summary: String {
        guard !isEmpty else { return "Progress: no sub-skills yet" }
        return "Progress: \(progress.summary), \(progress.learning) in progress"
    }
}
