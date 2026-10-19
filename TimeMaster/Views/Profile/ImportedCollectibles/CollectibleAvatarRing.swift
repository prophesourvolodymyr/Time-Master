import Foundation
import SwiftUI

struct CollectibleAvatarRing: View {
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

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
                    artwork(phase: timeline.date.timeIntervalSinceReferenceDate * 0.42)
                }
            } else {
                artwork(phase: 0.22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func artwork(phase: Double) -> some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let colors = CollectibleArtworkPalette.colors(for: item)
            let variant = CollectibleArtworkPalette.variant(for: item)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let unit = min(size.width, size.height)
                let lineWidth = max(1.2, unit * 0.045)
                switch variant {
                case 0:
                    let core = CGRect(x: center.x - unit * 0.45, y: center.y - unit * 0.45, width: unit * 0.90, height: unit * 0.90)
                    context.stroke(Path(ellipseIn: core), with: .color(colors[0]), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    var orbit = context
                    orbit.translateBy(x: center.x, y: center.y)
                    orbit.rotate(by: .degrees(-28 + sin(phase) * 6))
                    orbit.stroke(
                        Path(ellipseIn: CGRect(x: -unit * 0.53, y: -unit * 0.18, width: unit * 1.06, height: unit * 0.36)),
                        with: .color(colors[1]),
                        style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round)
                    )
                    let satelliteAngle = phase * 0.8 + 0.45
                    let satellite = CGPoint(
                        x: center.x + cos(satelliteAngle) * unit * 0.53,
                        y: center.y + sin(satelliteAngle) * unit * 0.19
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: satellite.x - unit * 0.065, y: satellite.y - unit * 0.065, width: unit * 0.13, height: unit * 0.13)),
                        with: .color(colors[2])
                    )
                case 1:
                    for index in 0..<3 {
                        var prism = context
                        prism.translateBy(x: center.x, y: center.y)
                        prism.rotate(by: .degrees(Double(index) * 60 + phase * 18))
                        let width = unit * (0.84 + Double(index) * 0.10)
                        let height = unit * (0.38 - Double(index) * 0.035)
                        prism.stroke(
                            Path(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height)),
                            with: .color(colors[index]),
                            style: StrokeStyle(lineWidth: lineWidth * (index == 1 ? 0.72 : 0.54), lineCap: .round)
                        )
                    }
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - unit * 0.44, y: center.y - unit * 0.44, width: unit * 0.88, height: unit * 0.88)),
                        with: .color(colors[1].opacity(0.65)),
                        style: StrokeStyle(lineWidth: lineWidth * 0.42, dash: [unit * 0.08, unit * 0.11], dashPhase: phase * unit * 0.11)
                    )
                default:
                    for index in 0..<10 {
                        var ray = Path()
                        let angle = Double(index) * .pi / 5 + phase * 0.16
                        let inner = unit * 0.46
                        let outer = unit * (index.isMultiple(of: 2) ? 0.55 : 0.51)
                        ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(ray, with: .color(colors[index % colors.count].opacity(index.isMultiple(of: 2) ? 0.95 : 0.62)), style: StrokeStyle(lineWidth: lineWidth * (index.isMultiple(of: 2) ? 0.72 : 0.44), lineCap: .round))
                    }
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - unit * 0.44, y: center.y - unit * 0.44, width: unit * 0.88, height: unit * 0.88)),
                        with: .color(colors[0]),
                        style: StrokeStyle(lineWidth: lineWidth * 1.16, lineCap: .round)
                    )
                    var flare = context
                    flare.translateBy(x: center.x, y: center.y)
                    flare.rotate(by: .degrees(38 + sin(phase) * 9))
                    flare.stroke(
                        Path(ellipseIn: CGRect(x: -unit * 0.54, y: -unit * 0.14, width: unit * 1.08, height: unit * 0.28)),
                        with: .color(colors[1]),
                        style: StrokeStyle(lineWidth: lineWidth * 0.70, lineCap: .round)
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .frame(width: unit, height: unit)
            .position(x: center.x, y: center.y)
        }
    }
}
