import AVFoundation
import Combine
import ImageIO
import Vision
#if os(iOS)
import CoreMotion
#endif

enum RankedCameraStatus: Equatable {
    case idle, requesting, starting, running, denied, restricted, unavailable, interrupted, failed(String)
    var message: String {
        switch self {
        case .idle: return "Camera is off"
        case .requesting: return "Allow camera access to track your movement"
        case .starting: return "Starting camera"
        case .running: return "Camera active · Images stay on this device"
        case .denied: return "Camera access is off · Open Settings to allow it"
        case .restricted: return "Camera access is restricted by this device"
        case .unavailable: return "No usable camera is available"
        case .interrupted: return "Camera interrupted · Return here and retry"
        case .failed(let message): return "Camera could not start: \(message)"
        }
    }
}

@MainActor
final class RankedCamera: ObservableObject {
    @Published private(set) var status: RankedCameraStatus = .idle
    @Published private(set) var tracking = RankedTrackingState()
    @Published private(set) var pose: RankedPose?
    @Published private(set) var mirrored = true
    let pipeline: RankedCapturePipeline
    var onPose: ((RankedPose) -> Void)?
    private var activation = 0

    init(variation: RankedVariation) {
        pipeline = RankedCapturePipeline(variation: variation)
        pipeline.onStatus = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.status = status
                if status != .running { self.interruptTracking(status.message); self.pose = nil }
            }
        }
        pipeline.onFrame = { [weak self] pose, state, mirrored in
            Task { @MainActor in
                guard let self else { return }
                self.pose = pose
                self.tracking = state
                self.mirrored = mirrored
                self.onPose?(pose)
            }
        }
    }

    func start() async {
        guard !Task.isCancelled else { return }
        activation += 1
        let version = activation
        guard AVCaptureDevice.default(for: .video) != nil else {
            status = .unavailable
            interruptTracking(status.message)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            status = .requesting
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard version == activation, !Task.isCancelled else { return }
            if granted { pipeline.start() }
            else { status = .denied }
        case .authorized: pipeline.start()
        case .denied: status = .denied
        case .restricted: status = .restricted
        @unknown default: status = .restricted
        }
    }

    func stop() {
        activation += 1
        interruptTracking("Camera is off")
        pose = nil
        pipeline.stop()
    }
    func finishTracking() async -> RankedTrackingState {
        activation += 1
        let finalState = await withCheckedContinuation { continuation in
            pipeline.stop { continuation.resume(returning: $0) }
        }
        interruptTracking("Camera is off")
        pose = nil
        return finalState
    }
    func switchCamera() { if status == .running { pipeline.switchCamera() } }
    func begin(start: Double, end: Double) { pipeline.begin(start: start, end: end) }
    func recalibrate() {
        interruptTracking("Hold the starting position to calibrate")
        pipeline.recalibrate()
    }
    func expireStalePose() {
        guard status == .running, let pose, Self.monotonicTime - pose.time > 0.35,
              tracking.usable || tracking.calibrated else { return }
        interruptTracking("Waiting for fresh camera frames · Reset position")
    }
    private func interruptTracking(_ reason: String) {
        var state = tracking
        state.calibrated = false
        state.usable = false
        state.currentHold = 0
        state.phase = "Reset position"
        state.reason = reason
        tracking = state
    }
    static var monotonicTime: Double { CMClockGetTime(CMClockGetHostTimeClock()).seconds }
}

final class RankedCapturePipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    var onStatus: ((RankedCameraStatus) -> Void)?
    var onFrame: ((RankedPose, RankedTrackingState, Bool) -> Void)?
    private let queue = DispatchQueue(label: "TimeMaster.Ranked.capture", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let invertedRequest = VNDetectHumanBodyPoseRequest()
    private let handRequest = VNDetectHumanHandPoseRequest()
    private let variation: RankedVariation
    private var tracker: RankedMovementTracker
    private var lastFrame = -Double.infinity
    private var input: AVCaptureDeviceInput?
    private var front = true
    private var active = false
    private var observers: [NSObjectProtocol] = []
    private var orientation: AVCaptureVideoOrientation = .portrait
    private var moving = false
#if os(iOS)
    private let motion = CMMotionManager()
#endif

    init(variation: RankedVariation) {
        self.variation = variation
        tracker = RankedMovementTracker(variation: variation)
        super.init()
        handRequest.maximumHandCount = 2
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.didStopRunningNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] note in
                self?.queue.async { [weak self] in
                    guard let self, self.active else { return }
                    self.tracker.interrupt("Capture interrupted")
                    if name == AVCaptureSession.runtimeErrorNotification {
                        let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
                        self.onStatus?(.failed(error?.localizedDescription ?? "Capture service error"))
                    } else { self.onStatus?(.interrupted) }
                }
            })
        }
#if os(iOS)
        observers.append(NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.tracker.interrupt("Capture interrupted")
                self?.onStatus?(.interrupted)
            }
        })
#endif
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        output.setSampleBufferDelegate(nil, queue: nil)
#if os(iOS)
        motion.stopGyroUpdates()
#endif
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.active = true
            self.onStatus?(.starting)
            do {
                if self.input == nil { try self.configure() }
                self.tracker.interrupt("Hold the starting position to calibrate")
                if !self.session.isRunning { self.session.startRunning() }
                guard self.session.isRunning else { self.onStatus?(.failed("Capture did not start")); return }
#if os(iOS)
                if self.motion.isGyroAvailable {
                    self.motion.gyroUpdateInterval = 0.1
                    self.motion.startGyroUpdates()
                }
#endif
                self.onStatus?(.running)
            } catch RankedCameraError.noCamera { self.onStatus?(.unavailable) }
            catch { self.onStatus?(.failed(error.localizedDescription)) }
        }
    }

    func stop(snapshot: ((RankedTrackingState) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else { snapshot?(RankedTrackingState()); return }
            self.active = false
            let finalState = self.tracker.state
#if os(iOS)
            self.motion.stopGyroUpdates()
#endif
            if self.session.isRunning { self.session.stopRunning() }
            self.tracker.interrupt("Camera is off")
            self.onStatus?(.idle)
            snapshot?(finalState)
        }
    }

    func switchCamera() {
        queue.async { [weak self] in
            guard let self else { return }
            self.front.toggle()
            do {
                try self.configure()
                self.tracker = RankedMovementTracker(variation: self.variation)
            } catch { self.onStatus?(.failed(error.localizedDescription)) }
        }
    }

    func setOrientation(_ value: AVCaptureVideoOrientation) {
        queue.async { [weak self] in
            guard let self, self.orientation != value else { return }
            self.orientation = value
            if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = value
            }
            self.tracker.interrupt("Orientation changed · Recalibrate")
        }
    }

    func begin(start: Double, end: Double) {
        queue.async { [weak self] in self?.tracker.begin(at: start, end: end) }
    }

    func recalibrate() {
        queue.async { [weak self] in self?.tracker.interrupt("Hold the starting position to calibrate") }
    }

    private func configure() throws {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices
        guard let device = devices.first(where: { $0.position == (front ? .front : .back) }) ?? AVCaptureDevice.default(for: .video) else {
            onStatus?(.unavailable)
            throw RankedCameraError.noCamera
        }
        let next = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        if let input { session.removeInput(input) }
        guard session.canAddInput(next) else { throw RankedCameraError.configuration }
        session.addInput(next)
        input = next
        front = device.position == .front
        if !session.outputs.contains(output) {
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { throw RankedCameraError.configuration }
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video) {
#if os(macOS)
            orientation = .landscapeRight
#endif
            if connection.isVideoOrientationSupported { connection.videoOrientation = orientation }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard active, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard time.isFinite, time - lastFrame >= 0.09 else { return }
        lastFrame = time
        var cameraMoving = false
#if os(iOS)
        if let rate = motion.gyroData?.rotationRate {
            cameraMoving = sqrt(rate.x * rate.x + rate.y * rate.y + rate.z * rate.z) > 0.12
        }
#endif
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
            try handler.perform([bodyRequest])
            var bodies = bodyRequest.results ?? []
            var inverted = false
            if variation == .wallHandstandPushUp || variation == .freestandingHandstandPushUp {
                try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .down).perform([invertedRequest])
                let alternatives = invertedRequest.results ?? []
                if alternatives.reduce(0, { $0 + Double($1.confidence) }) > bodies.reduce(0, { $0 + Double($1.confidence) }) {
                    bodies = alternatives
                    inverted = true
                }
            }
            var joints: [String: RankedJoint] = [:]
            if bodies.count == 1, let points = try bodies.first?.recognizedPoints(.all) {
                let keys: [(String, VNHumanBodyPoseObservation.JointName)] = [
                    ("nose", .nose), ("leftShoulder", .leftShoulder), ("rightShoulder", .rightShoulder),
                    ("leftElbow", .leftElbow), ("rightElbow", .rightElbow), ("leftWrist", .leftWrist), ("rightWrist", .rightWrist),
                    ("leftHip", .leftHip), ("rightHip", .rightHip), ("leftKnee", .leftKnee), ("rightKnee", .rightKnee),
                    ("leftAnkle", .leftAnkle), ("rightAnkle", .rightAnkle)
                ]
                for (name, key) in keys {
                    if let p = points[key], p.location.x.isFinite, p.location.y.isFinite, p.confidence.isFinite {
                        joints[name] = .init(x: inverted ? 1 - p.location.x : p.location.x,
                                             y: inverted ? 1 - p.location.y : p.location.y,
                                             confidence: Double(p.confidence))
                    }
                }
            }
            let aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(CVPixelBufferGetHeight(buffer))
            var contact: Bool?
            if variation == .diamondPushUp {
                try handler.perform([handRequest])
                if let hands = handRequest.results, hands.count == 2 {
                    let tips = try hands.map { try $0.recognizedPoints(.all) }
                    if let a = tips[0][.thumbTip], let b = tips[1][.thumbTip],
                       let c = tips[0][.indexTip], let d = tips[1][.indexTip],
                       let aw = tips[0][.wrist], let bw = tips[1][.wrist],
                       [a, b, c, d, aw, bw].allSatisfy({ $0.confidence >= 0.45 }),
                       let lw = joints["leftWrist"], let rw = joints["rightWrist"] {
                        func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot((a.x - b.x) * aspect, a.y - b.y) }
                        let span = max(0.02, hypot((lw.x - rw.x) * aspect, lw.y - rw.y))
                        let attached = [aw, bw].allSatisfy { w in
                            min(distance(w.location, CGPoint(x: lw.x, y: lw.y)), distance(w.location, CGPoint(x: rw.x, y: rw.y))) < 0.1
                        }
                        contact = attached && distance(a.location, b.location) < span * 0.35 && distance(c.location, d.location) < span * 0.35
                    }
                }
            }
            let pose = RankedPose(time: time, aspect: aspect, people: bodies.count, joints: joints,
                                  light: Self.lightLevel(buffer), cameraMoving: cameraMoving, diamondContact: contact)
            let state = tracker.consume(pose)
            onFrame?(pose, state, front)
        } catch {
            tracker.interrupt("Pose processing interrupted · Retry calibration")
            onStatus?(.failed(error.localizedDescription))
        }
    }

    private static func lightLevel(_ buffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var light = 0.0
        for row in 0..<16 {
            for column in 0..<16 {
                let offset = min(height - 1, row * height / 16) * stride + min(width - 1, column * width / 16) * 4
                light += (0.0722 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) + 0.2126 * Double(pixels[offset + 2])) / 255
            }
        }
        return light / 256
    }
}

private enum RankedCameraError: LocalizedError {
    case noCamera, configuration
    var errorDescription: String? { self == .noCamera ? "No usable camera is available" : "Camera configuration was rejected" }
}
