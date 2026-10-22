import SwiftUI

struct PhysiqueBadgeMedallion: View {
    let badge: PhysiqueBadge
    let isNew: Bool

    init(badge: PhysiqueBadge, isNew: Bool = false) {
        self.badge = badge
        self.isNew = isNew
    }

    @Environment(\.colorSchemeContrast) private var contrast
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 40
    #else
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44
    #endif

    private var emblem: Emblem {
        switch badge.id {
        case "placed":
            switch badge.symbol.lowercased() {
            case "iron": return .iron
            case "bronze": return .bronze
            case "silver": return .silver
            case "gold": return .gold
            case "diamond": return .diamond
            case "champion": return .champion
            default: return .placed
            }
        case "firstBell": return .firstBell
        case "tenRounds": return .tenRounds
        case "threeStraight": return .threeStraight
        default: return .other
        }
    }

    var body: some View {
        let outline = MedalOutline(isTier: badge.id == "placed")
        let ink = LinearGradient(
            colors: [Theme.textPrimary, Theme.textPrimary.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        ZStack {
            outline.fill(
                LinearGradient(
                    stops: [
                        .init(color: Theme.textPrimary.opacity(contrast == .increased ? 1 : 0.86), location: 0),
                        .init(color: Theme.surface2, location: 0.42),
                        .init(color: Theme.toolbarOrange.opacity(0.88), location: 0.78),
                        .init(color: Theme.textPrimary.opacity(0.48), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            outline.inset(by: size * 0.045)
                .fill(Theme.background)
            outline.inset(by: size * 0.075)
                .fill(
                    LinearGradient(
                        colors: [Theme.surface2, Theme.surface, Theme.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            MedalFacets()
                .fill(Theme.textPrimary.opacity(contrast == .increased ? 0.09 : 0.045))
                .clipShape(outline.inset(by: size * 0.08))
            outline.inset(by: size * 0.115)
                .strokeBorder(
                    isNew ? Theme.toolbarOrange : Theme.textPrimary.opacity(contrast == .increased ? 0.62 : 0.22),
                    lineWidth: contrast == .increased ? 1.1 : 0.7
                )
            MedalRimCuts(isTier: badge.id == "placed")
                .stroke(Theme.textPrimary.opacity(0.8), style: StrokeStyle(lineWidth: size * 0.022, lineCap: .square))
            if emblem == .tenRounds {
                Circle()
                    .strokeBorder(ink, lineWidth: size * 0.024)
                    .padding(size * 0.205)
                Circle()
                    .strokeBorder(ink, lineWidth: size * 0.024)
                    .padding(size * 0.27)
                Text("10")
                    .font(.custom("Inter-Black", fixedSize: size * 0.30))
                    .tracking(-size * 0.01)
                    .foregroundStyle(ink)
            } else if emblem.isOutlined {
                MedalGlyph(emblem: emblem)
                    .stroke(ink, style: StrokeStyle(lineWidth: size * 0.043, lineCap: .square, lineJoin: .miter))
                    .padding(size * 0.235)
            } else {
                MedalGlyph(emblem: emblem)
                    .fill(ink)
                    .padding(size * 0.235)
            }
            if isNew {
                outline.inset(by: size * 0.045)
                    .strokeBorder(Theme.toolbarOrange, lineWidth: contrast == .increased ? 2 : 1.4)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private enum Emblem {
        case iron, bronze, silver, gold, diamond, champion, placed
        case firstBell, tenRounds, threeStraight, other

        var isOutlined: Bool {
            self == .diamond || self == .champion || self == .placed
        }
    }

    private struct MedalOutline: InsettableShape {
        let isTier: Bool
        var insetAmount: CGFloat = 0

        func inset(by amount: CGFloat) -> Self {
            var outline = self
            outline.insetAmount += amount
            return outline
        }

        func path(in rect: CGRect) -> Path {
            let field = rect.insetBy(dx: insetAmount, dy: insetAmount)
            guard field.width > 0, field.height > 0 else { return Path() }
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: field.minX + field.width * x, y: field.minY + field.height * y)
            }
            var path = Path()
            if isTier {
                path.move(to: point(0.32, 0.025))
                path.addLine(to: point(0.68, 0.025))
                path.addQuadCurve(to: point(0.74, 0.05), control: point(0.715, 0.025))
                path.addLine(to: point(0.95, 0.26))
                path.addQuadCurve(to: point(0.975, 0.32), control: point(0.975, 0.285))
                path.addLine(to: point(0.975, 0.68))
                path.addQuadCurve(to: point(0.95, 0.74), control: point(0.975, 0.715))
                path.addLine(to: point(0.74, 0.95))
                path.addQuadCurve(to: point(0.68, 0.975), control: point(0.715, 0.975))
                path.addLine(to: point(0.32, 0.975))
                path.addQuadCurve(to: point(0.26, 0.95), control: point(0.285, 0.975))
                path.addLine(to: point(0.05, 0.74))
                path.addQuadCurve(to: point(0.025, 0.68), control: point(0.025, 0.715))
                path.addLine(to: point(0.025, 0.32))
                path.addQuadCurve(to: point(0.05, 0.26), control: point(0.025, 0.285))
                path.addLine(to: point(0.26, 0.05))
                path.addQuadCurve(to: point(0.32, 0.025), control: point(0.285, 0.025))
            } else {
                path.move(to: point(0.5, 0.025))
                path.addCurve(to: point(0.975, 0.5), control1: point(0.762, 0.025), control2: point(0.975, 0.238))
                path.addCurve(to: point(0.63, 0.956), control1: point(0.975, 0.718), control2: point(0.829, 0.9))
                path.addLine(to: point(0.5, 0.868))
                path.addLine(to: point(0.37, 0.956))
                path.addCurve(to: point(0.025, 0.5), control1: point(0.171, 0.9), control2: point(0.025, 0.718))
                path.addCurve(to: point(0.5, 0.025), control1: point(0.025, 0.238), control2: point(0.238, 0.025))
            }
            path.closeSubpath()
            return path
        }
    }

    private struct MedalFacets: Shape {
        func path(in rect: CGRect) -> Path {
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
            }
            var path = Path()
            path.move(to: point(0.08, 0.46))
            path.addLines([point(0.52, 0.08), point(0.28, 0.52), point(0.08, 0.7)])
            path.closeSubpath()
            path.move(to: point(0.5, 0.92))
            path.addLines([point(0.92, 0.5), point(0.92, 0.73), point(0.7, 0.94)])
            path.closeSubpath()
            return path
        }
    }

    private struct MedalRimCuts: Shape {
        let isTier: Bool

        func path(in rect: CGRect) -> Path {
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
            }
            var path = Path()
            path.move(to: point(0.4, 0.068))
            path.addLine(to: point(0.6, 0.068))
            path.move(to: point(0.068, 0.43))
            path.addLine(to: point(0.068, 0.57))
            path.move(to: point(0.932, 0.43))
            path.addLine(to: point(0.932, 0.57))
            if isTier {
                path.move(to: point(0.4, 0.932))
                path.addLine(to: point(0.6, 0.932))
            } else {
                path.move(to: point(0.28, 0.886))
                path.addLine(to: point(0.35, 0.918))
                path.move(to: point(0.65, 0.918))
                path.addLine(to: point(0.72, 0.886))
            }
            return path
        }
    }

    private struct MedalGlyph: Shape {
        let emblem: Emblem

        func path(in rect: CGRect) -> Path {
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
            }
            func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
                CGRect(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y, width: rect.width * width, height: rect.height * height)
            }
            var path = Path()
            switch emblem {
            case .iron:
                path.move(to: point(0.08, 0.34))
                path.addLines([point(0.92, 0.34), point(0.82, 0.66), point(0.18, 0.66)])
                path.closeSubpath()
            case .bronze:
                path.move(to: point(0.08, 0.78))
                path.addLines([point(0.41, 0.25), point(0.58, 0.78)])
                path.closeSubpath()
                path.move(to: point(0.49, 0.78))
                path.addLines([point(0.78, 0.12), point(0.94, 0.78)])
                path.closeSubpath()
            case .silver:
                for x in [CGFloat(0.12), 0.41, 0.70] {
                    path.addRoundedRect(in: box(x, 0.19, 0.18, 0.62), cornerSize: CGSize(width: rect.width * 0.025, height: rect.height * 0.025))
                }
            case .gold:
                path.addRect(box(0.35, 0.35, 0.30, 0.30))
                path.move(to: point(0.5, 0.02))
                path.addLines([point(0.62, 0.24), point(0.38, 0.24)])
                path.closeSubpath()
                path.move(to: point(0.98, 0.5))
                path.addLines([point(0.76, 0.62), point(0.76, 0.38)])
                path.closeSubpath()
                path.move(to: point(0.5, 0.98))
                path.addLines([point(0.38, 0.76), point(0.62, 0.76)])
                path.closeSubpath()
                path.move(to: point(0.02, 0.5))
                path.addLines([point(0.24, 0.38), point(0.24, 0.62)])
                path.closeSubpath()
            case .diamond:
                path.move(to: point(0.25, 0.12))
                path.addLines([point(0.75, 0.12), point(0.94, 0.42), point(0.5, 0.94), point(0.06, 0.42)])
                path.closeSubpath()
                path.move(to: point(0.06, 0.42))
                path.addLine(to: point(0.94, 0.42))
                path.move(to: point(0.25, 0.12))
                path.addLines([point(0.38, 0.42), point(0.5, 0.94), point(0.62, 0.42), point(0.75, 0.12)])
            case .champion:
                path.move(to: point(0.15, 0.42))
                path.addLines([point(0.5, 0.12), point(0.85, 0.42)])
                path.move(to: point(0.15, 0.68))
                path.addLines([point(0.5, 0.38), point(0.85, 0.68)])
                path.move(to: point(0.32, 0.88))
                path.addLine(to: point(0.68, 0.88))
            case .placed:
                path.move(to: point(0.08, 0.76))
                path.addLine(to: point(0.92, 0.76))
                for x in [CGFloat(0.12), 0.31, 0.50, 0.69, 0.88] {
                    path.move(to: point(x, 0.25))
                    path.addLine(to: point(x, 0.58))
                }
            case .firstBell:
                path.move(to: point(0.18, 0.72))
                path.addQuadCurve(to: point(0.29, 0.49), control: point(0.29, 0.63))
                path.addLine(to: point(0.30, 0.39))
                path.addCurve(to: point(0.70, 0.39), control1: point(0.31, 0.13), control2: point(0.69, 0.13))
                path.addLine(to: point(0.71, 0.49))
                path.addQuadCurve(to: point(0.82, 0.72), control: point(0.71, 0.63))
                path.closeSubpath()
                path.addRoundedRect(in: box(0.15, 0.73, 0.70, 0.08), cornerSize: CGSize(width: rect.width * 0.03, height: rect.height * 0.03))
                path.addEllipse(in: box(0.43, 0.84, 0.14, 0.12))
                path.addRoundedRect(in: box(0.44, 0.06, 0.12, 0.12), cornerSize: CGSize(width: rect.width * 0.03, height: rect.height * 0.03))
            case .threeStraight:
                path.addRect(box(0.12, 0.82, 0.76, 0.06))
                for index in 0..<3 {
                    let x = CGFloat(index) * 0.29 + 0.12
                    let top = 0.28 - CGFloat(index) * 0.10
                    path.addRect(box(x, top, 0.075, 0.56 + CGFloat(index) * 0.10))
                    path.move(to: point(x + 0.075, top))
                    path.addLines([point(x + 0.26, top + 0.10), point(x + 0.075, top + 0.22)])
                    path.closeSubpath()
                }
            case .other:
                path.addRoundedRect(in: box(0.13, 0.23, 0.74, 0.12), cornerSize: CGSize(width: rect.width * 0.04, height: rect.height * 0.04))
                path.addRoundedRect(in: box(0.13, 0.47, 0.55, 0.12), cornerSize: CGSize(width: rect.width * 0.04, height: rect.height * 0.04))
                path.addRoundedRect(in: box(0.13, 0.71, 0.35, 0.12), cornerSize: CGSize(width: rect.width * 0.04, height: rect.height * 0.04))
            case .tenRounds:
                break
            }
            return path
        }
    }
}
