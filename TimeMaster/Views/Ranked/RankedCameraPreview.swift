import SwiftUI
import AVFoundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct RankedCameraPreview: View {
    @ObservedObject var camera: RankedCamera

    var body: some View {
        ZStack {
            Color.black
            RankedCapturePreview(pipeline: camera.pipeline, mirrored: camera.mirrored)
            GeometryReader { geometry in
                if let pose = camera.pose {
                    let aspect = max(0.1, pose.aspect)
                    let width = min(geometry.size.width, geometry.size.height * aspect)
                    let height = width / aspect
                    let x = (geometry.size.width - width) / 2
                    let y = (geometry.size.height - height) / 2
                    Path { path in
                        for side in ["left", "right"] {
                            let names = [side + "Wrist", side + "Elbow", side + "Shoulder", side + "Hip", side + "Knee", side + "Ankle"]
                            var connected = false
                            for name in names {
                                guard let joint = pose.joints[name], joint.confidence >= 0.45 else { connected = false; continue }
                                let point = CGPoint(x: x + (camera.mirrored ? 1 - joint.x : joint.x) * width,
                                                    y: y + (1 - joint.y) * height)
                                if connected { path.addLine(to: point) } else { path.move(to: point) }
                                connected = true
                            }
                        }
                    }
                    .stroke(camera.tracking.usable ? Theme.toolbarOrange : Color.white.opacity(0.65), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
            .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: ProfileStyle.corner)
                .strokeBorder(camera.tracking.calibrated ? Theme.toolbarOrange : .white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .padding(ProfileStyle.inset)
                .allowsHitTesting(false)
            if camera.status != .running {
                VStack(spacing: ProfileStyle.spacing) {
                    Image(systemName: "video.slash").font(.largeTitle)
                    Text(camera.status.message).font(TimeMasterFont.secondary()).multilineTextAlignment(.center)
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ProfileStyle.corner))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera framing")
        .accessibilityValue(camera.status == .running ? camera.tracking.reason : camera.status.message)
    }
}

#if os(iOS)
private struct RankedCapturePreview: UIViewRepresentable {
    let pipeline: RankedCapturePipeline
    let mirrored: Bool
    func makeUIView(context: Context) -> RankedPreviewUIView {
        let view = RankedPreviewUIView()
        view.layerView.session = pipeline.session
        view.pipeline = pipeline
        return view
    }
    func updateUIView(_ view: RankedPreviewUIView, context: Context) {
        view.mirrored = mirrored
        view.setNeedsLayout()
    }
}

private final class RankedPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerView: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    weak var pipeline: RankedCapturePipeline?
    var mirrored = true
    override func layoutSubviews() {
        super.layoutSubviews()
        layerView.videoGravity = .resizeAspect
        let orientation: AVCaptureVideoOrientation
        switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: orientation = .landscapeLeft
        case .landscapeRight: orientation = .landscapeRight
        case .portraitUpsideDown: orientation = .portraitUpsideDown
        default: orientation = .portrait
        }
        if let connection = layerView.connection {
            if connection.isVideoOrientationSupported { connection.videoOrientation = orientation }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
        pipeline?.setOrientation(orientation)
    }
}
#else
private struct RankedCapturePreview: NSViewRepresentable {
    let pipeline: RankedCapturePipeline
    let mirrored: Bool
    func makeNSView(context: Context) -> RankedPreviewNSView {
        let view = RankedPreviewNSView()
        view.preview.session = pipeline.session
        return view
    }
    func updateNSView(_ view: RankedPreviewNSView, context: Context) {
        view.mirrored = mirrored
        view.needsLayout = true
    }
}

private final class RankedPreviewNSView: NSView {
    let preview = AVCaptureVideoPreviewLayer()
    var mirrored = true
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(preview)
        preview.videoGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        preview.frame = bounds
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
#endif
