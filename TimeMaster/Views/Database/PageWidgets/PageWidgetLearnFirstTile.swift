import SwiftUI
import TimeMasterCore

/// Learn first: what a skill waits for. The next page or group to learn, how many of them are learned as a bar, and the
/// files and links to have first. Waiting for nothing (a tile the page chose), it invites the first. A tap opens them.
struct PageWidgetLearnFirstTile: View {
    let learnFirst: PageWidgetLearnFirst
    let onOpen: (PageWidgetTarget) -> Void

    var body: some View {
        PageWidgetTile(kind: .learnFirst, target: .dependencies, summary: summary, onOpen: onOpen) {
            if learnFirst.total == 0 {
                VStack(alignment: .leading, spacing: 0) {
                    PageWidgetHeader(kind: .learnFirst)
                    PageWidgetEmptyState(systemImage: "plus.circle", title: "Nothing to learn first")
                }
                .padding(PageWidgetMetrics.inset)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            PageWidgetHeader(kind: .learnFirst, trailing: "\(learnFirst.total)")
            Spacer(minLength: 0)
            if let next = learnFirst.next {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: next.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(next.color)
                    Text(next.title)
                        .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            } else if learnFirst.steps > 0 {
                Label("All learned", systemImage: "checkmark.seal.fill")
                    .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.toolbarOrange)
            } else {
                Text(learnFirst.materials)
                    .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
            if learnFirst.steps > 0 {
                HStack(spacing: 8) {
                    PageWidgetBar(fraction: Double(learnFirst.stepsDone) / Double(learnFirst.steps))
                    Text("\(learnFirst.stepsDone) of \(learnFirst.steps)")
                        .font(TimeMasterFont.black(11, relativeTo: .caption2).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                }
                if !learnFirst.materials.isEmpty {
                    Text("and \(learnFirst.materials)")
                        .font(TimeMasterFont.micro())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(PageWidgetMetrics.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var summary: String {
        guard learnFirst.total > 0 else { return "Learn first: nothing yet" }
        var parts = ["Learn first: \(learnFirst.total)"]
        if let next = learnFirst.next {
            parts.append("next, \(next.title)")
        } else if learnFirst.steps > 0 {
            parts.append("all learned")
        }
        if learnFirst.steps > 0 { parts.append("\(learnFirst.stepsDone) of \(learnFirst.steps) learned") }
        if !learnFirst.materials.isEmpty { parts.append(learnFirst.materials) }
        return parts.joined(separator: ", ")
    }
}
