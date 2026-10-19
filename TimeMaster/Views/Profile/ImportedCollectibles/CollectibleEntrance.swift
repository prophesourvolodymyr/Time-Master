import Foundation
import SwiftUI

struct CollectibleEntrance: View {
    let item: CollectibleItem
    var trigger: Int = 0
    var active: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.everRasterizedContent) private var rasterizedContent
    @Environment(\.everPageTravelActive) private var pageTravelActive
    @State private var isVisible = false
    @State private var entranceStart: Date?

    private var motionAllowed: Bool {
        active && isVisible && scenePhase == .active && !reduceMotion && !rasterizedContent && !pageTravelActive
    }

    private var shouldAnimate: Bool {
        motionAllowed && entranceStart != nil
    }

    private var variant: Int {
        CollectibleArtworkPalette.variant(for: item)
    }

    var body: some View {
        Group {
            if shouldAnimate, let entranceStart {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(entranceStart)
                    artwork(progress: CollectibleArtworkPalette.smoothStep(elapsed / 0.86))
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
            if active && scenePhase == .active && !reduceMotion && !rasterizedContent && !pageTravelActive {
                entranceStart = Date()
            }
        }
        .onDisappear {
            isVisible = false
            entranceStart = nil
        }
        .onChange(of: trigger) { _ in restart() }
        .onChange(of: active) { value in
            if value { restart() } else { entranceStart = nil }
        }
        .onChange(of: scenePhase) { value in
            if value != .active { entranceStart = nil }
        }
        .onChange(of: reduceMotion) { value in
            if value { entranceStart = nil }
        }
        .task(id: entranceStart) {
            guard entranceStart != nil else { return }
            do {
                try await Task.sleep(nanoseconds: 900_000_000)
            } catch {
                return
            }
            if !Task.isCancelled { entranceStart = nil }
        }
    }

    private func restart() {
        guard motionAllowed else {
            entranceStart = nil
            return
        }
        entranceStart = Date()
    }

    private func artwork(progress: Double) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let unit = min(width, height)
            let colors = CollectibleArtworkPalette.colors(for: item)
            let visibility = sin(progress * .pi)
            let scale = 0.88 + progress * 0.12
            ZStack {
                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    let card = CGRect(x: size.width * 0.08, y: size.height * 0.08, width: size.width * 0.84, height: size.height * 0.84)
                    let lineWidth = max(1, unit * 0.025)
                    switch variant {
                    case 0:
                        context.stroke(Path(roundedRect: card, cornerRadius: unit * 0.13), with: .color(colors[0].opacity(0.88)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        var horizon = context
                        horizon.translateBy(x: size.width / 2, y: size.height / 2)
                        horizon.rotate(by: .degrees(-25 + (1 - progress) * 18))
                        horizon.stroke(
                            Path(ellipseIn: CGRect(x: -unit * 0.46, y: -unit * 0.14, width: unit * 0.92, height: unit * 0.28)),
                            with: .color(colors[1].opacity(0.82)),
                            style: StrokeStyle(lineWidth: lineWidth * 1.45, lineCap: .round)
                        )
                        horizon.stroke(
                            Path(ellipseIn: CGRect(x: -unit * 0.36, y: -unit * 0.10, width: unit * 0.72, height: unit * 0.20)),
                            with: .color(colors[2].opacity(0.66)),
                            style: StrokeStyle(lineWidth: lineWidth * 0.78, lineCap: .round)
                        )
                    case 1:
                        context.stroke(Path(roundedRect: card, cornerRadius: unit * 0.13), with: .color(colors[1].opacity(0.86)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        for index in 0..<4 {
                            var beam = Path()
                            let startX = size.width * (0.02 + Double(index) * 0.21) + (1 - progress) * unit * 0.36
                            beam.move(to: CGPoint(x: startX, y: card.minY))
                            beam.addLine(to: CGPoint(x: startX + unit * 0.28, y: card.maxY))
                            context.stroke(beam, with: .color(colors[index % colors.count].opacity(0.58)), style: StrokeStyle(lineWidth: lineWidth * (index.isMultiple(of: 2) ? 2.0 : 0.9), lineCap: .round))
                        }
                    default:
                        context.stroke(Path(roundedRect: card, cornerRadius: unit * 0.13), with: .color(colors[1].opacity(0.90)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        let center = CGPoint(x: size.width / 2, y: size.height * 0.54)
                        for index in 0..<8 {
                            var ray = Path()
                            let angle = Double(index) * .pi / 4
                            let inner = unit * 0.29
                            let outer = unit * (0.45 + (1 - progress) * 0.12)
                            ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                            ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                            context.stroke(ray, with: .color(colors[index % colors.count].opacity(0.76)), style: StrokeStyle(lineWidth: lineWidth * (index.isMultiple(of: 2) ? 1.8 : 0.85), lineCap: .round))
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(scale, anchor: .center)
            .opacity(visibility)
        }
    }
}
