import SwiftUI
import TimeMasterCore

struct PageWidgetLearnFirstTile: View {
    let learnFirst: PageWidgetLearnFirst
    let onOpen: (PageWidgetTarget) -> Void

    var body: some View {
        PageWidgetTile(kind: .learnFirst, target: .dependencies, summary: summary, onOpen: onOpen) {
            if learnFirst.total == 0 {
                PageWidgetEmptyState(systemImage: "plus.circle", title: "Nothing to learn first")
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetLabel(text: "Learn first")
            Spacer(minLength: 0)
            if let next = learnFirst.next {
                WidgetTitle(text: next, size: 18, lines: 2)
            } else if learnFirst.steps > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.toolbarOrange)
                    WidgetTitle(text: "All learned", size: 18, lines: 1)
                }
            } else {
                WidgetTitle(text: learnFirst.materials, size: 18, lines: 2)
            }
            if learnFirst.steps > 0 {
                WidgetBar(fraction: Double(learnFirst.stepsDone) / Double(learnFirst.steps))
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
            parts.append("next, \(next)")
        } else if learnFirst.steps > 0 {
            parts.append("all learned")
        }
        if learnFirst.steps > 0 { parts.append("\(learnFirst.stepsDone) of \(learnFirst.steps) learned") }
        if !learnFirst.materials.isEmpty { parts.append(learnFirst.materials) }
        return parts.joined(separator: ", ")
    }
}
