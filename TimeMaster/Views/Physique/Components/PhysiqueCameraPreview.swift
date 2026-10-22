import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

struct PhysiqueCameraPreview: View {
    @ObservedObject var camera: PhysiqueCamera
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.scenePhase) private var scenePhase

    private var ownsCamera: Bool { camera.ownerID == windowID }
    private var visibleImage: CGImage? {
        guard ownsCamera, scenePhase == .active else { return nil }
        return camera.previewImage
    }
    private var title: String {
        if !ownsCamera, camera.ownerID != nil { return "Camera active in another window" }
        if scenePhase != .active { return "Camera protected" }
        if camera.isCapturing { return "Checking locally" }
        return camera.status.message
    }
    private var detail: String {
        if !ownsCamera, camera.ownerID != nil { return "Continue in the owning window or explicitly take control before resuming." }
        if scenePhase != .active { return "Resume explicitly when this window is active." }
        return camera.framingMessage
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.background
                if let image = visibleImage {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    VStack(spacing: ProfileStyle.spacing) {
                        Image(systemName: camera.isCapturing ? "eye.slash" : "camera.viewfinder")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.toolbarOrange)
                        Text(title)
                            .font(TimeMasterFont.heading())
                        Text(detail)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(ProfileStyle.inset)
                    .multilineTextAlignment(.center)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .background(Theme.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(camera.candidate == nil ? "Local camera preview" : "Exact local face-obscured capture")
        .accessibilityValue(visibleImage == nil ? "\(title). \(detail)" : camera.framingMessage)
        .transaction { $0.animation = nil }
        #if os(iOS)
        .background {
            PhysiqueCameraOrientationReader(active: ownsCamera && scenePhase == .active) { value in
                camera.setOrientation(value, owner: windowID)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        #endif
    }
}

#if os(iOS)
private struct PhysiqueCameraOrientationReader: UIViewRepresentable {
    let active: Bool
    let onOrientation: (AVCaptureVideoOrientation) -> Void

    func makeUIView(context: Context) -> PhysiqueCameraOrientationView {
        let view = PhysiqueCameraOrientationView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PhysiqueCameraOrientationView, context: Context) {
        view.active = active
        view.onOrientation = onOrientation
        view.reportOrientation()
    }

    static func dismantleUIView(_ view: PhysiqueCameraOrientationView, coordinator: ()) {
        view.active = false
        view.onOrientation = nil
    }
}

private final class PhysiqueCameraOrientationView: UIView {
    var active = false {
        didSet { if !active { reportedOrientation = nil } }
    }
    var onOrientation: ((AVCaptureVideoOrientation) -> Void)?
    private var reportedOrientation: AVCaptureVideoOrientation?
    private var reportScheduled = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportOrientation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportOrientation()
    }

    func reportOrientation() {
        guard active, !reportScheduled else { return }
        reportScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.reportScheduled = false
            guard self.active, let orientation = self.window?.windowScene?.interfaceOrientation else { return }
            let value: AVCaptureVideoOrientation
            switch orientation {
            case .portrait: value = .portrait
            case .portraitUpsideDown: value = .portraitUpsideDown
            case .landscapeLeft: value = .landscapeLeft
            case .landscapeRight: value = .landscapeRight
            default: return
            }
            guard self.reportedOrientation != value else { return }
            self.reportedOrientation = value
            self.onOrientation?(value)
        }
    }
}
#endif
