import SwiftUI
import TimeMasterCore

struct PageWidgetProgressTile: View {
    let progress: SkillProgress
    let target: PageWidgetTarget
    let onOpen: (PageWidgetTarget) -> Void

    private var isEmpty: Bool { progress.total == 0 && progress.abandoned == 0 }

    var body: some View {
        PageWidgetTile(kind: .progress, target: target, summary: summary, onOpen: onOpen) {
            if isEmpty {
                PageWidgetEmptyState(systemImage: "circle.dotted", title: "No sub\u{2011}skills yet")
            } else {
                ring
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var ring: some View {
        ZStack {
            WidgetRing(fraction: progress.fraction, lineWidth: 10)
            if progress.fraction < 1 {
                VStack(spacing: 0) {
                    WidgetHero(text: "\(Int((progress.fraction * 100).rounded()))%", size: 28)
                    WidgetLabel(text: "done")
                }
                .padding(.horizontal, 18)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Theme.toolbarOrange)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var summary: String {
        guard !isEmpty else { return "Progress: no sub-skills yet" }
        return "Progress: \(progress.summary), \(progress.learning) in progress"
    }
}
