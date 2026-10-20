import SwiftUI

struct TmaxProgressBar: View {
    var value: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var startedAt = Date()

    init(value: Double? = nil) {
        self.value = value
    }

    private var fraction: Double? {
        value.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
    }

    var body: some View {
        ProgressView(value: fraction)
            .progressViewStyle(TmaxTrackStyle(fraction: fraction, reduceMotion: reduceMotion, isActive: scenePhase == .active, rightToLeft: layoutDirection == .rightToLeft, startedAt: startedAt))
            .frame(height: 5)
            .accessibilityLabel("Loading progress")
            .onChange(of: scenePhase) { phase in
                if phase == .active { startedAt = .now }
            }
    }
}

private struct TmaxTrackStyle: ProgressViewStyle {
    let fraction: Double?
    let reduceMotion: Bool
    let isActive: Bool
    let rightToLeft: Bool
    let startedAt: Date

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isActive || fraction == 1)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                let travel = elapsed.truncatingRemainder(dividingBy: 1.35) / 1.35
                let width = geometry.size.width
                let segment = fraction.map { width * $0 } ?? width * (reduceMotion ? 0.45 : 0.28)
                let position = fraction != nil ? 0 : reduceMotion ? (width - segment) / 2 : (width + segment) * travel - segment
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(Theme.toolbarOrange)
                        .frame(width: max(0, segment))
                        .overlay {
                            if !reduceMotion && fraction != 1 {
                                Canvas { canvas, size in
                                    let spacing: CGFloat = 12
                                    let shift = CGFloat(elapsed.truncatingRemainder(dividingBy: 0.6) / 0.6) * spacing
                                    var stripes = Path()
                                    for index in -1...Int(size.width / spacing) + 1 {
                                        let x = CGFloat(index) * spacing - shift
                                        stripes.move(to: CGPoint(x: x, y: size.height))
                                        stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                                    }
                                    canvas.stroke(stripes, with: .color(.white.opacity(0.24)), lineWidth: 2)
                                }
                                .clipShape(Capsule())
                            }
                        }
                        .offset(x: position)
                }
                .clipShape(Capsule())
                .scaleEffect(x: rightToLeft ? -1 : 1, y: 1)
            }
        }
    }
}
