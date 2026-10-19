import Foundation
import SwiftUI

struct CollectibleBadgeSkin: View {
    let item: CollectibleItem
    var active: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.everRasterizedContent) private var rasterizedContent
    @Environment(\.everPageTravelActive) private var pageTravelActive
    @State private var isVisible = false

    private var shouldAnimate: Bool {
        active && isVisible && scenePhase == .active && !reduceMotion && !rasterizedContent && !pageTravelActive
    }

    private var glyph: String {
        switch CollectibleArtworkPalette.variant(for: item) {
        case 0: return "chart.bar.fill"
        case 1: return "sparkles"
        default: return "chart.bar.fill"
        }
    }

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
                    artwork(phase: timeline.date.timeIntervalSinceReferenceDate * 0.34)
                }
            } else {
                artwork(phase: 0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("\(item.name) badge skin")
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func artwork(phase: Double) -> some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            let colors = CollectibleArtworkPalette.colors(for: item)
            let sweep = (sin(phase * 0.68) + 1) / 2
            let start = UnitPoint(x: sweep * 1.65 - 0.7, y: 0.15)
            let end = UnitPoint(x: sweep * 1.65 + 0.55, y: 0.85)
            ZStack {
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "shield")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.36))
                    .padding(unit * 0.012)
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.72))
                    .mask {
                        LinearGradient(colors: [.clear, .white, .clear], startPoint: start, endPoint: end)
                    }
                VStack(spacing: unit * 0.045) {
                    Image(systemName: glyph)
                        .font(.system(size: max(5, unit * 0.19), weight: .bold))
                    HStack(spacing: unit * 0.035) {
                        Capsule().frame(width: unit * 0.20, height: max(1, unit * 0.026))
                        Capsule().frame(width: unit * 0.14, height: max(1, unit * 0.026))
                        Capsule().frame(width: unit * 0.09, height: max(1, unit * 0.026))
                    }
                }
                .foregroundStyle(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.24), radius: max(0.5, unit * 0.018), y: max(0.5, unit * 0.012))
            }
            .frame(width: unit, height: unit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
