import SwiftUI

struct StoreArtwork: View {
    let style: StoreArtworkStyle

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let unit = min(w, h)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(style.color))
            switch style {
            case .orbit:
                let planet = CGRect(x: w * 0.42, y: h * 0.20, width: unit * 0.70, height: unit * 0.70)
                context.fill(Path(ellipseIn: planet), with: .color(style.ink))
                for index in 0..<3 {
                    var ring = context
                    ring.translateBy(x: planet.midX, y: planet.midY)
                    ring.rotate(by: .degrees(-28))
                    let diameter = unit * (1.03 + Double(index) * 0.14)
                    ring.stroke(Path(ellipseIn: CGRect(x: -diameter / 2, y: -unit * 0.15, width: diameter, height: unit * 0.30)), with: .color(index == 0 ? style.color : style.ink), lineWidth: unit * 0.012)
                }
                for index in 0..<9 {
                    let x = w * (0.10 + Double((index * 7) % 13) / 18)
                    let y = h * (0.10 + Double((index * 3) % 9) / 12)
                    let r = index.isMultiple(of: 3) ? unit * 0.009 : unit * 0.004
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(style.ink))
                }
            case .frame:
                let rect = CGRect(x: w * 0.17, y: h * 0.08, width: w * 0.66, height: h * 0.84)
                context.fill(Path(roundedRect: rect, cornerRadius: unit * 0.04), with: .color(style.ink))
                let inner = rect.insetBy(dx: unit * 0.04, dy: unit * 0.04)
                context.fill(Path(roundedRect: inner, cornerRadius: unit * 0.025), with: .color(Color(red: 0.98, green: 0.81, blue: 0.62)))
                context.fill(Path(ellipseIn: CGRect(x: w * 0.48, y: h * 0.16, width: unit * 0.23, height: unit * 0.23)), with: .color(style.color))
                var mountain = Path()
                mountain.move(to: CGPoint(x: inner.minX, y: inner.maxY))
                mountain.addLine(to: CGPoint(x: inner.minX, y: h * 0.65))
                mountain.addLine(to: CGPoint(x: w * 0.40, y: h * 0.42))
                mountain.addLine(to: CGPoint(x: w * 0.60, y: h * 0.68))
                mountain.addLine(to: CGPoint(x: inner.maxX, y: h * 0.48))
                mountain.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
                mountain.closeSubpath()
                context.fill(mountain, with: .color(style.ink))
            case .tempo:
                let disc = CGRect(x: w * 0.25, y: h * 0.12, width: unit * 0.8, height: unit * 0.8)
                context.fill(Path(ellipseIn: disc), with: .color(style.ink))
                for index in 1..<6 {
                    let inset = unit * Double(index) * 0.048
                    context.stroke(Path(ellipseIn: disc.insetBy(dx: inset, dy: inset)), with: .color(style.color.opacity(0.4)), lineWidth: unit * 0.003)
                }
                context.fill(Path(ellipseIn: disc.insetBy(dx: unit * 0.3, dy: unit * 0.3)), with: .color(style.color))
                context.fill(Path(ellipseIn: disc.insetBy(dx: unit * 0.385, dy: unit * 0.385)), with: .color(style.ink))
                for index in 0..<18 {
                    let barHeight = h * (0.08 + Double((index * 7) % 9) * 0.014)
                    let rect = CGRect(x: w * 0.08 + Double(index) * w * 0.048, y: h * 0.89 - barHeight / 2, width: w * 0.013, height: barHeight)
                    context.fill(Path(roundedRect: rect, cornerRadius: w * 0.006), with: .color(style.ink))
                }
            case .grove:
                context.fill(Path(ellipseIn: CGRect(x: w * 0.66, y: h * 0.08, width: unit * 0.28, height: unit * 0.28)), with: .color(Color(red: 0.92, green: 0.92, blue: 0.70)))
                for layer in 0..<3 {
                    var hill = Path()
                    hill.move(to: CGPoint(x: 0, y: h))
                    hill.addLine(to: CGPoint(x: 0, y: h * (0.35 + Double(layer) * 0.16)))
                    hill.addCurve(to: CGPoint(x: w, y: h * (0.42 + Double(layer) * 0.14)), control1: CGPoint(x: w * 0.34, y: h * (-0.15 + Double(layer) * 0.3)), control2: CGPoint(x: w * 0.55, y: h * (1.1 - Double(layer) * 0.13)))
                    hill.addLine(to: CGPoint(x: w, y: h))
                    hill.closeSubpath()
                    context.fill(hill, with: .color(style.ink.opacity(0.30 + Double(layer) * 0.30)))
                }
            case .pixel:
                let side = unit * 0.14
                let cells = [(2,0),(3,0),(1,1),(2,1),(3,1),(4,1),(0,2),(1,2),(2,2),(3,2),(4,2),(5,2),(0,3),(2,3),(3,3),(5,3),(1,4),(4,4)]
                for (x,y) in cells {
                    let rect = CGRect(x: w * 0.5 - side * 3 + Double(x) * side, y: h * 0.16 + Double(y) * side, width: side * 0.91, height: side * 0.91)
                    context.fill(Path(roundedRect: rect, cornerRadius: unit * 0.012), with: .color(style.ink))
                }
            case .prism:
                for index in 0..<8 {
                    var petal = context
                    petal.translateBy(x: w * 0.52, y: h * 0.52)
                    petal.rotate(by: .degrees(Double(index) * 45))
                    petal.fill(Path(ellipseIn: CGRect(x: -unit * 0.11, y: -unit * 0.40, width: unit * 0.22, height: unit * 0.42)), with: .color(style.ink.opacity(index.isMultiple(of: 2) ? 1 : 0.7)))
                }
                context.fill(Path(ellipseIn: CGRect(x: w * 0.52 - unit * 0.065, y: h * 0.52 - unit * 0.065, width: unit * 0.13, height: unit * 0.13)), with: .color(style.color))
            case .paper:
                for index in 0..<6 {
                    let y = h * 0.2 + Double(index) * h * 0.12
                    var line = Path()
                    line.move(to: CGPoint(x: w * 0.13, y: y))
                    line.addLine(to: CGPoint(x: w * 0.87, y: y))
                    context.stroke(line, with: .color(style.ink.opacity(0.18)), lineWidth: unit * 0.004)
                }
                var curve = Path()
                curve.move(to: CGPoint(x: w * 0.2, y: h * 0.65))
                curve.addCurve(to: CGPoint(x: w * 0.74, y: h * 0.27), control1: CGPoint(x: w * 0.75, y: h * 0.95), control2: CGPoint(x: w * 0.20, y: h * 0.08))
                context.stroke(curve, with: .color(style.ink), style: StrokeStyle(lineWidth: unit * 0.035, lineCap: .round))
            case .mono:
                for index in 0..<4 {
                    var layer = context
                    layer.translateBy(x: w * 0.50, y: h * 0.48)
                    layer.rotate(by: .degrees(Double(index) * 15 - 22))
                    let side = unit * (0.65 - Double(index) * 0.12)
                    layer.fill(Path(roundedRect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerRadius: unit * 0.055), with: .color(index.isMultiple(of: 2) ? style.ink : style.color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
