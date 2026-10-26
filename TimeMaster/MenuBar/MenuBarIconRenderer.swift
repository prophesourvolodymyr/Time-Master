#if os(macOS)
import AppKit
import SwiftUI

enum MenuBarIconRenderer {
    private static let canvas = NSSize(width: 22, height: 18)
    private static let ringDiameter: CGFloat = 15
    private static let ringWidth: CGFloat = 2

    private static var orange: NSColor { NSColor(Theme.toolbarOrange) }
    private static var teal: NSColor { NSColor(Theme.accent) }
    private static var green: NSColor { NSColor(Color(hex: "34C759")) }

    static func image(for glyph: MenuBarItemPresentation.Glyph, progress: Double?) -> NSImage {
        switch glyph {
        case .idle:
            return markImage()
        case .upcoming:
            return templateSymbol("calendar")
        case .getReady:
            return ring(progress: progress ?? 0, tint: orange, symbol: "play.fill")
        case .countdown(let seconds):
            return ring(progress: progress ?? 0, tint: orange, number: seconds)
        case .exercise:
            return ring(progress: progress ?? 0, tint: orange, symbol: "figure.strengthtraining.traditional")
        case .rest:
            return ring(progress: progress ?? 0, tint: teal, symbol: "moon.zzz.fill")
        case .paused:
            return ring(progress: progress ?? 0, tint: NSColor.systemGray, symbol: "pause.fill")
        case .finished:
            return finishedImage()
        }
    }

    private static func markImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 26, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let height: CGFloat = 12
            let width = height * TmaxMark.aspectRatio
            let origin = CGPoint(x: (rect.width - width) / 2, y: (rect.height - height) / 2)
            let path = TmaxMark().path(in: CGRect(x: 0, y: 0, width: width, height: height)).cgPath
            var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: origin.x, ty: origin.y + height)
            if let placed = path.copy(using: &transform) {
                context.addPath(placed)
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func templateSymbol(_ name: String) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        let image = base ?? NSImage(size: canvas)
        image.isTemplate = true
        return image
    }

    private static func ring(progress: Double, tint: NSColor, symbol: String? = nil, number: Int? = nil) -> NSImage {
        let clamped = CGFloat(min(1, max(0, progress)))
        let image = NSImage(size: canvas, flipped: false) { rect in
            let circle = NSRect(
                x: (rect.width - ringDiameter) / 2,
                y: (rect.height - ringDiameter) / 2,
                width: ringDiameter,
                height: ringDiameter
            ).insetBy(dx: ringWidth / 2, dy: ringWidth / 2)

            let track = NSBezierPath(ovalIn: circle)
            track.lineWidth = ringWidth
            tint.withAlphaComponent(0.3).setStroke()
            track.stroke()

            if clamped > 0 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: NSPoint(x: circle.midX, y: circle.midY),
                    radius: circle.width / 2,
                    startAngle: 90,
                    endAngle: 90 - 360 * clamped,
                    clockwise: true
                )
                arc.lineWidth = ringWidth
                arc.lineCapStyle = .round
                tint.setStroke()
                arc.stroke()
            }

            if let symbol {
                drawSymbol(symbol, in: circle, color: tint, pointSize: 7.5)
            } else if let number {
                drawNumber(number, in: circle, color: tint)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func finishedImage() -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { rect in
            let circle = NSRect(
                x: (rect.width - ringDiameter) / 2,
                y: (rect.height - ringDiameter) / 2,
                width: ringDiameter,
                height: ringDiameter
            )
            green.setFill()
            NSBezierPath(ovalIn: circle).fill()
            drawSymbol("checkmark", in: circle, color: .black, pointSize: 8, weight: .heavy)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawSymbol(
        _ name: String,
        in rect: NSRect,
        color: NSColor,
        pointSize: CGFloat,
        weight: NSFont.Weight = .bold
    ) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        let size = symbol.size
        symbol.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }

    private static func drawNumber(_ number: Int, in rect: NSRect, color: NSColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSAttributedString(
            string: "\(number)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .heavy),
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        )
        let height = text.size().height
        text.draw(in: NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height))
    }
}
#endif
