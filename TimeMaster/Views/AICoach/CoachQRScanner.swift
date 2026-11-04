#if os(iOS)
import AVFoundation
import SwiftUI
import UIKit

struct CoachQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> CoachQRScannerController {
        let controller = CoachQRScannerController()
        controller.onCode = onCode
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ controller: CoachQRScannerController, context: Context) {}
}

final class CoachQRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.timemaster.coach.qr")
    private var preview: AVCaptureVideoPreviewLayer?
    private var delivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configure() } else { self?.fail("Camera access is off. Allow it in Settings, or paste the invitation link instead.") }
                }
            }
        default:
            fail("Camera access is off. Allow it in Settings, or paste the invitation link instead.")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = session
        sessionQueue.async { if session.isRunning { session.stopRunning() } }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !session.inputs.isEmpty else { return }
        let session = session
        sessionQueue.async { if !session.isRunning { session.startRunning() } }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            fail("This device has no camera to scan with. Paste the invitation link instead.")
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            fail("The camera could not be set up. Paste the invitation link instead.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
        let session = session
        sessionQueue.async { session.startRunning() }
    }

    private func fail(_ message: String) {
        guard !delivered else { return }
        delivered = true
        onFailure?(message)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !delivered,
              let code = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first(where: { !$0.isEmpty }) else { return }
        delivered = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let session = session
        sessionQueue.async { if session.isRunning { session.stopRunning() } }
        onCode?(code)
    }
}
#endif
