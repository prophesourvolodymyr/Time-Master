import Foundation
import SwiftUI

struct CollectibleName: View {
    let text: String
    let item: CollectibleItem?
    var active: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.everRasterizedContent) private var rasterizedContent
    @Environment(\.everPageTravelActive) private var pageTravelActive
    @State private var isVisible = false

    private var shouldAnimate: Bool {
        item != nil && active && isVisible && scenePhase == .active && !reduceMotion && !rasterizedContent && !pageTravelActive
    }

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
                    artwork(phase: timeline.date.timeIntervalSinceReferenceDate * 0.36)
                }
            } else {
                artwork(phase: 0.55)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .accessibilityElement()
        .accessibilityLabel(text)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    @ViewBuilder
    private func artwork(phase: Double) -> some View {
        if let item {
            let colors = CollectibleArtworkPalette.colors(for: item)
            let sweep = (sin(phase * 0.72) + 1) / 2
            let start = UnitPoint(x: sweep * 1.7 - 0.85, y: 0.5)
            let end = UnitPoint(x: sweep * 1.7 + 0.35, y: 0.5)
            Text(text)
                .foregroundStyle(EverColor.textPrimary)
                .overlay {
                    Text(text)
                        .foregroundStyle(LinearGradient(colors: colors, startPoint: start, endPoint: end))
                        .mask {
                            Text(text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                }
        } else {
            Text(text)
        }
    }
}
