import SwiftUI

struct ScheduleFlame: View {
    let difficulty: Int
    var isBurning = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    static func accent(for difficulty: Int) -> Color {
        switch difficulty {
        case 1: .mint
        case 2: .cyan
        case 3: .yellow
        case 4: .orange
        case 5: .red
        case 6: .purple
        default: Color(red: 0.72, green: 0.63, blue: 1)
        }
    }

    var body: some View {
        let accent = Self.accent(for: difficulty)
        let dark = difficulty == 7
        let gradient = Gradient(colors: isBurning
            ? [dark ? .black : accent, dark ? Color(white: 0.16) : accent.opacity(0.72)]
            : [.gray.opacity(0.45), .gray.opacity(0.2)])
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isBurning || scenePhase != .active)) { timeline in
            let phase = reduceMotion || !isBurning ? 0 : timeline.date.timeIntervalSinceReferenceDate * 2.4
            Canvas { context, size in
                let bounds = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.12, dy: size.height * 0.12)
                let path = flame(in: bounds, phase: phase, level: CGFloat(difficulty))
                context.addFilter(.shadow(color: accent.opacity(isBurning ? 0.48 : 0.08), radius: size.width * 0.1))
                context.fill(path, with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                    endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
                context.stroke(path, with: .color(accent.opacity(isBurning ? 0.9 : 0.35)), lineWidth: max(1, size.width * 0.025))
                let inner = CGRect(x: bounds.minX + bounds.width * 0.28, y: bounds.minY + bounds.height * 0.43,
                                   width: bounds.width * 0.45, height: bounds.height * 0.52)
                context.fill(flame(in: inner, phase: phase + 1.4, level: 1), with: .color(dark ? accent.opacity(0.7) : .white.opacity(0.8)))
                if isBurning && !reduceMotion {
                    for index in 0..<3 {
                        let travel = (phase * 0.22 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                        let x = size.width * (0.35 + Double(index) * 0.15 + sin(phase + Double(index)) * 0.05)
                        let y = size.height * (0.3 - travel * 0.22)
                        let radius = size.width * 0.025 * (1 - travel)
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                     with: .color(accent.opacity(1 - travel)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func flame(in rect: CGRect, phase: Double, level: CGFloat) -> Path {
        let sway = CGFloat(sin(phase)) * 0.055
        let wing = min(level, 7) * 0.018
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.5, 1))
        path.addCurve(to: point(0.1, 0.5 - wing), control1: point(0.02, 1), control2: point(-0.05, 0.7))
        path.addCurve(to: point(0.3, 0.64), control1: point(0.1, 0.62), control2: point(0.24, 0.65))
        path.addCurve(to: point(0.55 + sway, 0), control1: point(0.42, 0.43), control2: point(0.25 + sway, 0.24))
        path.addCurve(to: point(0.68, 0.49), control1: point(0.56 + sway, 0.2), control2: point(0.86, 0.3))
        path.addCurve(to: point(0.86, 0.36 - wing), control1: point(0.8, 0.59), control2: point(0.9, 0.43))
        path.addCurve(to: point(0.5, 1), control1: point(1.16, 0.7), control2: point(0.94, 1))
        path.closeSubpath()
        return path
    }
}
