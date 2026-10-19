import SceneKit
import SwiftUI
#if os(iOS)
import UIKit
private typealias VerificationBadgeColor = UIColor
private typealias VerificationBadgeImage = UIImage
private typealias VerificationBadgePath = UIBezierPath
private typealias VerificationBadgeRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
private typealias VerificationBadgeColor = NSColor
private typealias VerificationBadgeImage = NSImage
private typealias VerificationBadgePath = NSBezierPath
private typealias VerificationBadgeRepresentable = NSViewRepresentable

private extension NSBezierPath {
    func addLine(to point: CGPoint) {
        line(to: point)
    }

    func addQuadCurve(to end: CGPoint, controlPoint control: CGPoint) {
        let start = currentPoint
        curve(to: end,
              controlPoint1: CGPoint(x: start.x + (control.x - start.x) * 2 / 3,
                                     y: start.y + (control.y - start.y) * 2 / 3),
              controlPoint2: CGPoint(x: end.x + (control.x - end.x) * 2 / 3,
                                     y: end.y + (control.y - end.y) * 2 / 3))
    }
}
#endif

struct ProfileVerificationBadge: View {
    let tier: LocalBadgeTier
    var compact: Bool = true
    var color: Color? = nil
    var size: CGFloat? = nil
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.everRasterizedContent) private var everRasterizedContent
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var isVisible = false

    private var resolvedSize: CGFloat { max(8, size ?? (compact ? 16 : 24)) }
    private var resolvedTierColor: Color {
        switch tier {
        case .blue: .blue
        case .silver: Color(red: 0.72, green: 0.76, blue: 0.81)
        case .gold: Color(red: 0.91, green: 0.68, blue: 0.18)
        }
    }

    private var animationEnabled: Bool {
        animated && !reduceMotion && isVisible && !everRasterizedContent
            && !lowPowerMode && scenePhase == .active
    }

    var body: some View {
        Group {
            if everRasterizedContent {
                #if os(iOS)
                Image(uiImage: VerificationBadgeScene.preview(tier: tier, color: VerificationBadgeColor(color ?? resolvedTierColor), size: resolvedSize))
                    .resizable()
                #elseif os(macOS)
                Image(nsImage: VerificationBadgeScene.preview(tier: tier, color: VerificationBadgeColor(color ?? resolvedTierColor), size: resolvedSize))
                    .resizable()
                #endif
            } else {
                VerificationBadgeScene(tier: tier, color: VerificationBadgeColor(color ?? resolvedTierColor), size: resolvedSize, animates: animationEnabled)
            }
        }
        .frame(width: resolvedSize, height: resolvedSize)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(tier == .blue ? "Blue, custom color checkmark" : "\(tier.title), metallic \(tier.rawValue) checkmark")
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

private struct VerificationBadgeScene: VerificationBadgeRepresentable {
    let tier: LocalBadgeTier
    let color: VerificationBadgeColor
    let size: CGFloat
    let animates: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    #if os(iOS)
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = false
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(tier: tier, color: color, animates: animates)
        view.preferredFramesPerSecond = size >= EverLayout.minimumTouchTarget ? 60 : 30
        view.isPlaying = animates
        view.setNeedsDisplay()
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        coordinator.stop()
        view.scene = nil
    }
    #elseif os(macOS)
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = false
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(tier: tier, color: color, animates: animates)
        view.preferredFramesPerSecond = size >= EverLayout.minimumTouchTarget ? 60 : 30
        view.isPlaying = animates
        view.needsDisplay = true
    }

    static func dismantleNSView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        coordinator.stop()
        view.scene = nil
    }
    #endif

    private static let previews: NSCache<NSString, VerificationBadgeImage> = {
        let cache = NSCache<NSString, VerificationBadgeImage>()
        cache.countLimit = 48
        return cache
    }()

    static func preview(tier: LocalBadgeTier, color: VerificationBadgeColor, size: CGFloat) -> VerificationBadgeImage {
        #if os(iOS)
        let pixels = ceil(size * UIScreen.main.scale)
        #elseif os(macOS)
        let pixels = ceil(size * (NSScreen.main?.backingScaleFactor ?? 1))
        #endif
        let key = "\(tier.rawValue)|\(color.description)|\(pixels)" as NSString
        if let cached = previews.object(forKey: key) { return cached }
        let coordinator = Coordinator()
        coordinator.update(tier: tier, color: color, animates: false)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = coordinator.scene
        renderer.pointOfView = coordinator.camera
        let image = renderer.snapshot(atTime: 0, with: CGSize(width: pixels, height: pixels), antialiasingMode: .multisampling4X)
        previews.setObject(image, forKey: key)
        return image
    }

    final class Coordinator {
        let scene = SCNScene()
        let camera = SCNNode()
        private let badge = SCNNode()
        private let seal = SCNNode(geometry: VerificationBadgeGeometry.seal.copy() as? SCNGeometry)
        private let frontMark = SCNNode(geometry: VerificationBadgeGeometry.mark)
        private let backMark = SCNNode(geometry: VerificationBadgeGeometry.mark)
        private let material = SCNMaterial()
        private var configuredTier: LocalBadgeTier?
        private var configuredColor: VerificationBadgeColor?
        private var isAnimating = false

        init() {
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 24
            camera.camera?.zNear = 0.1
            camera.camera?.zFar = 20
            camera.camera?.wantsHDR = true
            camera.camera?.exposureOffset = 0.1
            camera.position = SCNVector3(0, 0, 5)
            scene.rootNode.addChildNode(camera)
            scene.rootNode.addChildNode(badge)
            badge.addChildNode(seal)
            badge.addChildNode(frontMark)
            badge.addChildNode(backMark)
            badge.eulerAngles = SCNVector3(0.10, -0.14, 0)
            frontMark.position.z = 0.15
            backMark.position.z = -0.15
            backMark.eulerAngles.y = .pi
            material.lightingModel = .physicallyBased
            seal.geometry?.materials = [material]
            scene.lightingEnvironment.contents = VerificationBadgeGeometry.studio
            scene.lightingEnvironment.intensity = 1.2
            addLight(intensity: 780, temperature: 5700, position: SCNVector3(-3, 4, 5))
            addLight(intensity: 390, temperature: 7200, position: SCNVector3(4, 1, 2))
            addLight(intensity: 520, temperature: 6200, position: SCNVector3(-1, 2, -4))
        }

        func update(tier: LocalBadgeTier, color: VerificationBadgeColor, animates: Bool) {
            if configuredTier != tier || configuredColor != color {
                configuredTier = tier
                configuredColor = color
                switch tier {
                case .blue:
                    material.diffuse.contents = color
                    material.metalness.contents = 0.0
                    material.roughness.contents = 0.34
                case .silver:
                    material.diffuse.contents = VerificationBadgeColor(red: 0.78, green: 0.81, blue: 0.85, alpha: 1)
                    material.metalness.contents = 1.0
                    material.roughness.contents = 0.28
                case .gold:
                    material.diffuse.contents = VerificationBadgeColor(red: 1.0, green: 0.70, blue: 0.25, alpha: 1)
                    material.metalness.contents = 1.0
                    material.roughness.contents = 0.28
                }
            }
            guard animates != isAnimating else { return }
            isAnimating = animates
            if animates {
                badge.addAnimation(VerificationBadgeGeometry.turn, forKey: "badge-turn")
                frontMark.addAnimation(VerificationBadgeGeometry.frontMarkMotion, forKey: "mark-settle")
                backMark.addAnimation(VerificationBadgeGeometry.backMarkMotion, forKey: "mark-settle")
            } else {
                stop()
            }
        }

        func stop() {
            badge.removeAllAnimations()
            frontMark.removeAllAnimations()
            backMark.removeAllAnimations()
            isAnimating = false
        }

        private func addLight(intensity: CGFloat, temperature: CGFloat, position: SCNVector3) {
            let node = SCNNode()
            node.light = SCNLight()
            node.light?.type = .directional
            node.light?.intensity = intensity
            node.light?.temperature = temperature
            node.position = position
            node.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(node)
        }
    }
}

private enum VerificationBadgeGeometry {
    static let duration = 7.8

    static let seal: SCNShape = {
        let path = VerificationBadgePath()
        let segment = CGFloat.pi * 2 / 12
        let start = -CGFloat.pi / 2 - segment / 2
        func point(_ angle: CGFloat, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        path.move(to: point(start, 0.84))
        for bump in 0..<12 {
            let angle = start + segment * CGFloat(bump)
            path.addQuadCurve(to: point(angle + segment, 0.84), controlPoint: point(angle + segment / 2, 1))
        }
        path.close()
        path.flatness = 0.002
        let shape = SCNShape(path: path, extrusionDepth: 0.22)
        shape.chamferRadius = 0.035
        shape.chamferMode = .both
        return shape
    }()

    static let mark: SCNShape = {
        let path = VerificationBadgePath()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: (x - 0.5) * 1.18, y: (0.5 - y) * 1.18)
        }
        path.move(to: point(0.13, 0.48))
        path.addLine(to: point(0.24, 0.37))
        path.addLine(to: point(0.42, 0.55))
        path.addLine(to: point(0.74, 0.23))
        path.addQuadCurve(to: point(0.84, 0.23), controlPoint: point(0.79, 0.18))
        path.addLine(to: point(0.91, 0.30))
        path.addLine(to: point(0.48, 0.75))
        path.addQuadCurve(to: point(0.39, 0.75), controlPoint: point(0.43, 0.80))
        path.close()
        path.flatness = 0.002
        let shape = SCNShape(path: path, extrusionDepth: 0.07)
        shape.chamferRadius = 0.012
        shape.chamferMode = .both
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = VerificationBadgeColor.white
        material.roughness.contents = 0.3
        material.metalness.contents = 0.08
        material.emission.contents = VerificationBadgeColor(white: 0.12, alpha: 1)
        shape.materials = [material]
        return shape
    }()

    static let turn: CAAnimationGroup = {
        let spin = keyframes("eulerAngles.z") { time in
            let t = min(1, max(0, (time - 0.3) / 2.1))
            return -6 * .pi * (1 - pow(1 - t, 4))
        }
        let flip = keyframes("eulerAngles.y") { time in
            let t = min(1, max(0, (time - 2.8) / 1.35))
            let smooth = t * t * t * (t * (t * 6 - 15) + 10)
            return -0.14 + 2 * .pi * smooth
        }
        let tilt = keyframes("eulerAngles.x") { time in
            let t = min(1, max(0, (time - 2.8) / 1.35))
            return 0.10 + sin(t * .pi) * 0.22
        }
        return repeating([spin, flip, tilt])
    }()

    static let frontMarkMotion = markMotion(front: true)
    static let backMarkMotion = markMotion(front: false)

    private static func markMotion(front: Bool) -> CAAnimationGroup {
        let depth = keyframes("position.z") { time in
            (front ? 1 : -1) * (0.15 + bounce(time) * 0.10)
        }
        let nod = keyframes("eulerAngles.z") { time in bounce(time) * 0.16 }
        let lift = keyframes("position.y") { time in bounce(time) * 0.035 }
        return repeating([depth, nod, lift])
    }

    private static func bounce(_ time: Double) -> Double {
        let elapsed = time - 4.2
        guard elapsed >= 0 else { return 0 }
        return sin(elapsed * 13) * exp(-elapsed * 4.6)
    }

    private static func keyframes(_ path: String, value: (Double) -> Double) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: path)
        animation.values = (0...240).map { NSNumber(value: value(Double($0) / 240 * duration)) }
        animation.duration = duration
        animation.calculationMode = .linear
        return animation
    }

    private static func repeating(_ animations: [CAAnimation]) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.repeatCount = .infinity
        return group
    }

    static let studio: VerificationBadgeImage = {
        #if os(iOS)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 512, height: 256)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.48, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let boxes: [(CGRect, CGFloat)] = [
                (CGRect(x: 42, y: 20, width: 76, height: 180), 1.0),
                (CGRect(x: 220, y: 15, width: 150, height: 85), 0.86),
                (CGRect(x: 405, y: 70, width: 35, height: 155), 0.7)
            ]
            for (rect, brightness) in boxes {
                context.cgContext.setShadow(offset: .zero, blur: 18, color: UIColor(white: brightness, alpha: 1).cgColor)
                UIColor(white: brightness, alpha: 1).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
            }
        }
        #elseif os(macOS)
        let size = CGSize(width: 512, height: 256)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }
        let cgContext = context.cgContext
        // Match the top-left coordinate system of UIGraphicsImageRenderer.
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)
        cgContext.setFillColor(NSColor(white: 0.48, alpha: 1).cgColor)
        cgContext.fill(CGRect(origin: .zero, size: size))
        let boxes: [(CGRect, CGFloat)] = [
            (CGRect(x: 42, y: 20, width: 76, height: 180), 1.0),
            (CGRect(x: 220, y: 15, width: 150, height: 85), 0.86),
            (CGRect(x: 405, y: 70, width: 35, height: 155), 0.7)
        ]
        for (rect, brightness) in boxes {
            let color = NSColor(white: brightness, alpha: 1).cgColor
            cgContext.setShadow(offset: .zero, blur: 18, color: color)
            cgContext.setFillColor(color)
            cgContext.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
            cgContext.fillPath()
        }
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
        #endif
    }()
}
