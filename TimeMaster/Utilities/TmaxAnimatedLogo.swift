import SwiftUI

struct TmaxAnimatedLogo: View {
    var isComplete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: isComplete || reduceMotion || scenePhase != .active)) { context in
                let isStill = isComplete || reduceMotion || scenePhase != .active
                let cycle = max(0, context.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 3.6)
                let fraction = 1 - abs(cycle / 1.8 - 1)
                let progress = isStill ? 1 : fraction * fraction * (3 - 2 * fraction)

                TmaxMark()
                    .fill(.white)
                    .mask {
                        if progress >= 1 {
                            Color.white
                        } else {
                            DrawingStroke()
                                .trim(from: 0, to: progress)
                                .stroke(.white, style: StrokeStyle(lineWidth: geometry.size.width * 0.24, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .drawingGroup()
            }
        }
        .aspectRatio(TmaxMark.aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tmax")
        .onChange(of: scenePhase) { phase in
            if phase == .active { startedAt = .now }
        }
    }

    private struct DrawingStroke: Shape {
        private static let stroke: Path = {
            var path = Path()
            path.move(to: CGPoint(x: 0.065, y: 1.04))
            path.addLine(to: CGPoint(x: 0.435, y: 0.10))
            path.addCurve(to: CGPoint(x: 0.585, y: 0.67), control1: CGPoint(x: 0.49, y: 0.19), control2: CGPoint(x: 0.52, y: 0.88))
            path.addCurve(to: CGPoint(x: 0.725, y: 0.40), control1: CGPoint(x: 0.64, y: 0.61), control2: CGPoint(x: 0.69, y: 0.29))
            path.addCurve(to: CGPoint(x: 0.96, y: 0.88), control1: CGPoint(x: 0.79, y: 0.58), control2: CGPoint(x: 0.79, y: 0.99))
            return path
        }()

        func path(in rect: CGRect) -> Path {
            Self.stroke.applying(CGAffineTransform(scaleX: rect.width, y: rect.height).concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
        }
    }
}
