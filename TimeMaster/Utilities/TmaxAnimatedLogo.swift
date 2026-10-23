import SwiftUI

struct TmaxAnimatedLogo: View {
    var isComplete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: isComplete || reduceMotion || scenePhase != .active)) { context in
            let isStill = isComplete || reduceMotion || scenePhase != .active
            let cycle = max(0, context.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 3.6)
            let fraction = 1 - abs(cycle / 1.8 - 1)
            let progress = fraction * fraction * (3 - 2 * fraction)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let mark = TmaxMark().path(in: rect)
                if isStill {
                    context.fill(mark, with: .color(.white))
                } else {
                    let lineWidth = size.width * 0.24
                    let start = CGPoint(x: size.width * DrawingStroke.start.x, y: size.height * DrawingStroke.start.y)
                    context.clip(to: mark)
                    context.stroke(
                        DrawingStroke().path(in: rect).trimmedPath(from: 0, to: progress),
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: start.x - lineWidth / 2, y: start.y - lineWidth / 2,
                            width: lineWidth, height: lineWidth
                        )),
                        with: .color(.white)
                    )
                }
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
        static let start = CGPoint(x: 0.065, y: 1.04)

        private static let stroke: Path = {
            var path = Path()
            path.move(to: start)
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

struct TmaxStartupDeparture: View, Animatable {
    let logoFrame: CGRect
    var progress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let maximumScale = max(size.width, size.height) / max(1, logoFrame.width) * 3
            let scale = reduceMotion ? 1 : 1 + (maximumScale - 1) * progress * progress
            let frame = CGRect(
                x: logoFrame.midX - logoFrame.width * scale / 2,
                y: logoFrame.midY - logoFrame.height * scale / 2,
                width: logoFrame.width * scale,
                height: logoFrame.height * scale
            )
            context.fill(TmaxMark().path(in: frame), with: .color(.white))
            let bloom = reduceMotion ? progress : min(1, max(0, (progress - 0.45) / 0.5))
            let white = bloom * bloom * (3 - 2 * bloom)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(Double(white))))
        }
    }
}
