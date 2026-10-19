import MetalKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum EverLaunchTiming {
    static let flight = 1.8
    static let reveal = 0.58

    static func percentage(at elapsed: Double) -> Int {
        let progress = min(1, max(0, elapsed / (flight * 0.62)))
        return Int((progress * progress * (3 - 2 * progress) * 100).rounded())
    }
}

@MainActor
final class EverSpacetimeGPU {
    static let shared = EverSpacetimeGPU()
    let device: MTLDevice
    let queue: MTLCommandQueue
    let warp: MTLRenderPipelineState
    let stars: MTLRenderPipelineState
    let blackHole: MTLRenderPipelineState
    let flightBlur: MTLRenderPipelineState
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { return nil }
        func pipeline(_ vertex: String, _ fragment: String) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = .bgra8Unorm
            color.isBlendingEnabled = true
            color.sourceRGBBlendFactor = .one
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.sourceAlphaBlendFactor = .one
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        do {
            warp = try pipeline("everSpacetimeVertex", "everSpacetimeFragment")
            stars = try pipeline("everLightspeedVertex", "everLightspeedFragment")
            blackHole = try pipeline("everBlackHoleVertex", "everBlackHoleFragment")
            flightBlur = try pipeline("everBlackHoleVertex", "everFlightBlurFragment")
        } catch {
            return nil
        }
        self.device = device
        self.queue = queue
    }

    func texture(_ image: CGImage) -> MTLTexture? {
        let rowBytes = (image.width * 4 + 63) & ~63
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: image.width, height: image.height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = context.data, let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0,
                        withBytes: data, bytesPerRow: rowBytes)
        return texture
    }
}

struct EverWarpLayer {
    var texture: MTLTexture
    var rect: CGRect
    var secondaryTexture: MTLTexture?
    var travel: Float = 0
    var depth: Float = 0
    var opacity: Float = 1
    var dissolve: Float = 0
    var cornerRadius: Float = 0
    var vertical = false
    var flat = false
    var blur: Float = 0
    var connected = false
    var direction: Float?
    var textureRegion = CGRect(x: 0, y: 0, width: 1, height: 1)
    var horizonPull: Float = 0
    var horizonRadius: Float = 0
}

private struct EverWarpUniforms {
    var viewport: SIMD4<Float>
    var rect: SIMD4<Float>
    var motion: SIMD4<Float>
    var style: SIMD4<Float>
    var effect: SIMD4<Float>
    var sampling: SIMD4<Float>
}

@MainActor
final class EverSpacetimeCanvas: MTKView, MTKViewDelegate {
    let gpu: EverSpacetimeGPU
    var layers = [EverWarpLayer]()
    var flightLayers = [EverWarpLayer]()
    var flightTime: Double?
    var onFrame: ((CFTimeInterval) -> Void)?
    var clearAlpha: Double = 1
    private var presentedTexture: MTLTexture?
    private var flightRenderPass: MTLRenderPassDescriptor?

    init?(size: CGSize) {
        guard let gpu = EverSpacetimeGPU.shared else { return nil }
        self.gpu = gpu
        super.init(frame: CGRect(origin: .zero, size: size), device: gpu.device)
        colorPixelFormat = .bgra8Unorm
        #if os(iOS)
        contentScaleFactor = min(UIScreen.main.scale, 2)
        #endif
        framebufferOnly = false
        #if os(iOS)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        #elseif os(macOS)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        autoResizeDrawable = false
        updateBackingScale()
        setAccessibilityElement(false)
        #endif
        preferredFramesPerSecond = 60
        enableSetNeedsDisplay = false
        isPaused = true
        delegate = self
        layers.reserveCapacity(4)
        flightLayers.reserveCapacity(4)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    #if os(macOS)
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateBackingScale()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateBackingScale()
    }

    private func updateBackingScale() {
        let scale = min(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1, 2)
        layer?.contentsScale = scale
        drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }
    #endif

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        onFrame?(CACurrentMediaTime())
        guard bounds.width > 0, bounds.height > 0,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let command = gpu.queue.makeCommandBuffer() else { return }
        if flightTime == nil { flightRenderPass = nil }
        let flightPass = flightTime == nil ? nil : self.flightPass(matching: drawable.texture)
        let scenePass = flightPass ?? pass
        let clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: clearAlpha)
        pass.colorAttachments[0].clearColor = clearColor
        scenePass.colorAttachments[0].clearColor = clearColor
        guard var encoder = command.makeRenderCommandEncoder(descriptor: scenePass) else { return }
        var viewport = SIMD4<Float>(Float(bounds.width), Float(bounds.height), 0, 0)
        if let flightTime {
            viewport.z = Float(flightTime / EverLaunchTiming.flight)
            encoder.setRenderPipelineState(gpu.stars)
            encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 24000)
            encode(flightLayers, viewport: viewport, using: encoder)
            encoder.setRenderPipelineState(gpu.blackHole)
            encoder.setFragmentBytes(&viewport, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            viewport.w = 1
            encoder.setRenderPipelineState(gpu.stars)
            encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 24000)
        }
        if let texture = flightPass?.colorAttachments[0].texture {
            encoder.endEncoding()
            guard let composite = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder = composite
            encoder.setRenderPipelineState(gpu.flightBlur)
            encoder.setFragmentBytes(&viewport, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        encode(layers, viewport: viewport, using: encoder)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
        presentedTexture = drawable.texture
    }

    private func flightPass(matching texture: MTLTexture) -> MTLRenderPassDescriptor? {
        if let pass = flightRenderPass, let existing = pass.colorAttachments[0].texture,
           existing.width == texture.width, existing.height == texture.height {
            return pass
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: colorPixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = gpu.device.makeTexture(descriptor: descriptor) else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        flightRenderPass = pass
        return pass
    }

    private func encode(_ layers: [EverWarpLayer], viewport: SIMD4<Float>, using encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(gpu.warp)
        for layer in layers where layer.opacity > 0.001 {
            var uniforms = EverWarpUniforms(
                viewport: viewport,
                rect: SIMD4(Float(layer.rect.minX), Float(layer.rect.minY), Float(layer.rect.width), Float(layer.rect.height)),
                motion: SIMD4(layer.travel, layer.depth, layer.opacity, layer.dissolve),
                style: SIMD4(layer.cornerRadius, layer.direction ?? (layer.travel < 0 ? -1 : 1),
                              layer.vertical ? 1 : 0, layer.flat ? 1 : 0),
                effect: SIMD4(layer.horizonPull, layer.blur, layer.connected ? 1 : 0, layer.horizonRadius),
                sampling: SIMD4(Float(layer.textureRegion.minX), Float(layer.textureRegion.minY),
                                Float(layer.textureRegion.width), Float(layer.textureRegion.height))
            )
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<EverWarpUniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<EverWarpUniforms>.stride, index: 0)
            encoder.setFragmentTexture(layer.texture, index: 0)
            encoder.setFragmentTexture(layer.secondaryTexture ?? layer.texture, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: layer.flat ? 6 : (layer.connected ? 64 : 32) * 48 * 6)
        }
    }

    func snapshot() -> CGImage? {
        guard let texture = presentedTexture,
              let command = gpu.queue.makeCommandBuffer() else { return nil }
        let rowBytes = (texture.width * 4 + 255) & ~255
        let byteCount = rowBytes * texture.height
        guard let buffer = gpu.device.makeBuffer(length: byteCount, options: .storageModeShared),
              let blit = command.makeBlitCommandEncoder() else { return nil }
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                  to: buffer, destinationOffset: 0, destinationBytesPerRow: rowBytes, destinationBytesPerImage: byteCount)
        blit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        guard let provider = CGDataProvider(data: Data(bytes: buffer.contents(), count: byteCount) as CFData) else { return nil }
        return CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: rowBytes, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    func stop() {
        isPaused = true
        onFrame = nil
        layers.removeAll(keepingCapacity: true)
        flightLayers.removeAll(keepingCapacity: true)
        flightTime = nil
        presentedTexture = nil
        flightRenderPass = nil
        removeFromSuperview()
    }
}
