#if canImport(UIKit)
import MetalKit
import SwiftUI
import UIKit

struct ProfileMembershipConfetti: UIViewRepresentable {
    let color: Color
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func makeUIView(context: Context) -> Surface { Surface() }

    func updateUIView(_ view: Surface, context: Context) {
        view.configure(color: UIColor(color), active: isActive && !reduceMotion && scenePhase == .active)
    }

    static func dismantleUIView(_ view: Surface, coordinator: ()) { view.stop() }

    final class Surface: UIView {
        private struct Piece {
            let x: CGFloat
            let delay: Double
            let fall: Double
            let pull: Double
            let width: CGFloat
            let height: CGFloat
            let drift: CGFloat
            let landing: CGFloat
            let phase: Double
            let cell: Int
        }

        private var canvas: EverSpacetimeCanvas?
        private var active = false
        private var hasRun = false
        private var color = UIColor.white
        private var pieces = [Piece]()

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            backgroundColor = .clear
            NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIApplication.willResignActiveNotification, object: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        deinit { NotificationCenter.default.removeObserver(self) }

        func configure(color: UIColor, active: Bool) {
            self.color = color
            self.active = active
            if active { begin() } else { stop() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { stop() } else { begin() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let canvas, canvas.bounds.size != bounds.size { stop() }
            begin()
        }

        private func begin() {
            guard active, !hasRun, window != nil, !bounds.isEmpty else { return }
            hasRun = true
            guard let canvas = EverSpacetimeCanvas(size: bounds.size),
                  let image = atlas(), let texture = canvas.gpu.texture(image) else { return }
            self.canvas = canvas
            canvas.frame = bounds
            canvas.clearAlpha = 0
            canvas.layers.reserveCapacity(48)
            addSubview(canvas)
            pieces.reserveCapacity(48)
            for index in 0..<48 {
                let seed = Double(index)
                func unit(_ salt: Double) -> Double {
                    let value = sin(seed * 127.1 + salt * 311.7) * 43758.5453
                    return value - floor(value)
                }
                pieces.append(Piece(
                    x: 0.04 + unit(1) * 0.92, delay: unit(2) * 1.1,
                    fall: 1.6 + unit(3) * 0.7, pull: 0.9 + unit(4) * 0.45,
                    width: 5 + unit(5) * 3, height: index % 3 == 0 ? 17 : 9,
                    drift: (unit(6) - 0.5) * 0.14, landing: 0.56 + unit(7) * 0.24,
                    phase: unit(8) * .pi * 2, cell: index % 3
                ))
            }
            let start = CACurrentMediaTime()
            canvas.onFrame = { [weak self, weak canvas] time in
                guard let self, let canvas else { return }
                let elapsed = time - start
                canvas.layers.removeAll(keepingCapacity: true)
                var pending = false
                for piece in self.pieces {
                    let age = elapsed - piece.delay
                    guard age < piece.fall + piece.pull else { continue }
                    pending = true
                    guard age >= 0 else { continue }
                    let falling = min(1, age / piece.fall)
                    let pull = max(0, (age - piece.fall) / piece.pull)
                    let flutter = sin(falling * 12 + piece.phase)
                    let x = self.bounds.width * (piece.x + piece.drift * falling) + flutter * 9 * (1 - pull)
                    let y = -piece.height + self.bounds.height * piece.landing * pow(falling, 1.45)
                    let rect = CGRect(x: x - piece.width / 2, y: y, width: piece.width * (0.4 + abs(cos(age * 5 + piece.phase)) * 0.6), height: piece.height)
                    let radius = max(hypot(rect.midX - self.bounds.midX, rect.midY - self.bounds.midY), piece.height)
                    let angle = Int(age * 8 + piece.phase) % 8
                    canvas.layers.append(EverWarpLayer(
                        texture: texture, rect: rect, flat: pull == 0,
                        textureRegion: CGRect(x: CGFloat(angle) / 8, y: CGFloat(piece.cell) / 3, width: 1.0 / 8, height: 1.0 / 3),
                        horizonPull: Float(pow(pull, 1.6) * 1.6), horizonRadius: Float(radius)
                    ))
                }
                if !pending { self.stop() }
            }
            canvas.isPaused = false
        }

        private func atlas() -> CGImage? {
            let cell: CGFloat = 32
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = false
            return UIGraphicsImageRenderer(size: CGSize(width: cell * 8, height: cell * 3), format: format).image { renderer in
                let context = renderer.cgContext
                let colors = [UIColor.white, UIColor(white: 0.68, alpha: 1), color]
                for row in 0..<3 {
                    for column in 0..<8 {
                        context.saveGState()
                        context.translateBy(x: (CGFloat(column) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
                        context.rotate(by: CGFloat(column) * .pi / 4)
                        context.setFillColor(colors[row].cgColor)
                        context.fill(CGRect(x: -cell * 0.2, y: -cell * 0.36, width: cell * 0.4, height: cell * 0.72))
                        context.restoreGState()
                    }
                }
            }.cgImage
        }

        @objc func stop() {
            canvas?.stop()
            canvas = nil
            pieces.removeAll(keepingCapacity: false)
        }
    }
}
#endif
