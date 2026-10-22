import Foundation
import AVFoundation
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Combine
#if os(iOS)
import UIKit
#endif

struct PhysiqueCameraDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

enum PhysiqueCameraStatus: Equatable {
    case idle, requesting, starting, running, denied, restricted, unavailable, interrupted, failed(String)

    var isRunning: Bool { self == .running }

    var message: String {
        switch self {
        case .idle: return "Camera off"
        case .requesting: return "Waiting for camera permission"
        case .starting: return "Starting camera"
        case .running: return "Camera active · Local preview"
        case .denied: return "Camera access is off. Allow it in system settings."
        case .restricted: return "Camera access is restricted on this device."
        case .unavailable: return "No usable camera is available."
        case .interrupted: return "Camera interrupted. Resume when you are ready."
        case .failed(let detail): return detail
        }
    }
}

@MainActor
final class PhysiqueCamera: ObservableObject {
    static let shared = PhysiqueCamera()

    @Published private(set) var status: PhysiqueCameraStatus = .idle
    @Published private(set) var candidate: Data?
    @Published private(set) var candidatePose: PhysiquePose?
    @Published private(set) var selected: [PhysiquePose: Data] = [:]
    @Published private(set) var selectedEvidenceIDs: [PhysiquePose: String] = [:]
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var isCapturing = false
    @Published private(set) var canCapture = false
    @Published private(set) var error: String?
    @Published private(set) var framingMessage = "Stand alone in a private space with arms and lower legs in view."
    @Published private(set) var ownerID: UUID?
    @Published private(set) var deviceName: String?
    @Published private(set) var devices: [PhysiqueCameraDevice] = []
    @Published private(set) var selectedDeviceID: String?

    private enum Phase { case stopped, live, capturing, review }

    private let pipeline = PhysiqueCapturePipeline()
    private var generation = UUID()
    private var orientationRevision: UInt64 = 0
    private var phase: Phase = .stopped
    private var phaseStartedAt = 0.0
    private var lastFrameAt: Double?
    private var candidateImage: CGImage?
    private var startup: CheckedContinuation<Void, Never>?
    private var watchdog: Task<Void, Never>?
    #if os(iOS)
    private var orientation: AVCaptureVideoOrientation = .portrait
    #else
    private var orientation: AVCaptureVideoOrientation = .landscapeRight
    #endif

    private init() {
        pipeline.onFrame = { [weak self] token, revision, frame in
            Task { @MainActor in self?.receive(frame, token: token, revision: revision) }
        }
        pipeline.onFailure = { [weak self] token, status, message in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.end(status: status, message: message)
            }
        }
        pipeline.onDevicesChanged = { [weak self] in
            Task { @MainActor in await self?.refreshDevices() }
        }
        Task { [weak self] in await self?.refreshDevices() }
    }

    func start(owner: UUID) async {
        guard !Task.isCancelled else { return }
        guard ownerID == nil || ownerID == owner else {
            error = "The camera is controlled by another Physique window."
            return
        }
        guard phase != .live, !isCapturing, status != .requesting else { return }
        invalidateAcquisition()
        ownerID = owner
        let token = generation
        candidate = nil
        candidatePose = nil
        candidateImage = nil
        previewImage = nil
        error = nil
        canCapture = false
        framingMessage = "Waiting for fresh camera frames."
        guard let usage = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
              !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            end(status: .failed("Camera access is not configured in this app."), message: "The app needs a camera usage description before capture is available.")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            status = .requesting
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard token == generation, ownerID == owner else { return }
            guard !Task.isCancelled else { stop(owner: owner); return }
            guard allowed else { end(status: .denied, message: PhysiqueCameraStatus.denied.message); return }
        case .denied:
            end(status: .denied, message: PhysiqueCameraStatus.denied.message)
            return
        case .restricted:
            end(status: .restricted, message: PhysiqueCameraStatus.restricted.message)
            return
        case .authorized: break
        @unknown default:
            end(status: .restricted, message: PhysiqueCameraStatus.restricted.message)
            return
        }
        await refreshDevices()
        guard token == generation, ownerID == owner else { return }
        guard !Task.isCancelled else { stop(owner: owner); return }
        guard let sourceID = selectedDeviceID, devices.contains(where: { $0.id == sourceID }) else {
            end(status: .unavailable, message: "Connect the selected camera or explicitly choose another source.")
            return
        }
        #if os(iOS)
        updateInterfaceOrientation(owner: owner)
        #endif
        status = .starting
        phase = .live
        phaseStartedAt = ProcessInfo.processInfo.systemUptime
        lastFrameAt = nil
        watchAcquisition(token: token)
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard generation == token, !Task.isCancelled else {
                    continuation.resume()
                    if generation == token { stop(owner: owner) }
                    return
                }
                startup = continuation
                pipeline.start(token: token, deviceID: sourceID, orientation: orientation, revision: orientationRevision)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.stop(owner: owner)
            }
        }
    }

    func capture(pose: PhysiquePose) async {
        guard !Task.isCancelled, canCapture, let owner = ownerID else {
            error = "Wait for a fresh, usable private frame."
            return
        }
        let token = generation
        phase = .capturing
        phaseStartedAt = ProcessInfo.processInfo.systemUptime
        isCapturing = true
        canCapture = false
        previewImage = nil
        candidate = nil
        candidatePose = nil
        candidateImage = nil
        selected.removeValue(forKey: pose)
        selectedEvidenceIDs.removeValue(forKey: pose)
        error = nil
        framingMessage = "Preparing face privacy locally. Nothing has been sent."
        let result = await withTaskCancellationHandler {
            await pipeline.capture(token: token, pose: pose, revision: orientationRevision)
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.stop(owner: owner)
            }
        }
        guard generation == token, ownerID == owner, phase == .capturing else { return }
        guard !Task.isCancelled else { stop(owner: owner); return }
        watchdog?.cancel()
        watchdog = nil
        pipeline.stop()
        isCapturing = false
        status = .idle
        switch result {
        case .success(let protected):
            phase = .review
            candidate = protected.data
            candidatePose = pose
            candidateImage = protected.image
            previewImage = protected.image
            framingMessage = "Exact face-obscured capture · Not sent"
        case .failure(let failure):
            phase = .stopped
            previewImage = nil
            error = failure.localizedDescription
            framingMessage = failure.localizedDescription
        }
    }

    func acceptCandidate(evidenceID: String? = nil) {
        guard phase == .review, !isCapturing, ownerID != nil, let candidate, let pose = candidatePose else { return }
        selected[pose] = candidate
        if let evidenceID, !evidenceID.isEmpty { selectedEvidenceIDs[pose] = evidenceID }
        else { selectedEvidenceIDs.removeValue(forKey: pose) }
        discardCandidate()
    }

    func discardCandidate() {
        if isCapturing {
            invalidateAcquisition()
            phase = .stopped
            status = .idle
        }
        candidate = nil
        candidatePose = nil
        candidateImage = nil
        if phase != .live {
            phase = .stopped
            previewImage = nil
            framingMessage = "Camera off. Resume explicitly to capture again."
        }
    }

    func pause(owner: UUID? = nil) {
        guard owner == nil || owner == ownerID else { return }
        invalidateAcquisition()
        phase = candidate == nil ? .stopped : .review
        previewImage = candidateImage
        status = .idle
    }

    func stop(owner: UUID? = nil) {
        guard owner == nil || owner == ownerID else { return }
        invalidateAcquisition()
        candidate = nil
        candidatePose = nil
        candidateImage = nil
        previewImage = nil
        phase = .stopped
        ownerID = nil
        status = .idle
        error = nil
        framingMessage = "Camera off. Resume explicitly when you are ready."
    }

    func clear() {
        stop()
        selected.removeAll()
        selectedEvidenceIDs.removeAll()
    }

    func selectDevice(_ id: String, owner: UUID) async {
        guard ownerID == nil || ownerID == owner else {
            error = "The camera is controlled by another Physique window."
            return
        }
        guard devices.contains(where: { $0.id == id }) else {
            error = "That camera is no longer connected."
            return
        }
        guard selectedDeviceID != id else { return }
        stop(owner: owner)
        selected.removeAll()
        selectedEvidenceIDs.removeAll()
        selectedDeviceID = id
        deviceName = devices.first(where: { $0.id == id })?.name
        await start(owner: owner)
    }

    func setOrientation(_ value: AVCaptureVideoOrientation, owner: UUID) {
        guard ownerID == owner, orientation != value else { return }
        orientation = value
        orientationRevision &+= 1
        if phase == .capturing {
            pause(owner: owner)
            error = "The camera orientation changed. Resume and capture again."
            framingMessage = error ?? "Resume the camera."
        } else if phase == .live {
            previewImage = nil
            canCapture = false
            lastFrameAt = nil
            phaseStartedAt = ProcessInfo.processInfo.systemUptime
            framingMessage = "Checking the new camera orientation."
            pipeline.setOrientation(value, token: generation, revision: orientationRevision)
        }
    }

    #if os(iOS)
    private func updateInterfaceOrientation(owner: UUID) {
        var activeScene: UIWindowScene?
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes
            where scene.activationState == .foregroundActive && scene.windows.contains(where: { $0.isKeyWindow }) {
            guard activeScene == nil else { return }
            activeScene = scene
        }
        guard let interfaceOrientation = activeScene?.interfaceOrientation else { return }
        let value: AVCaptureVideoOrientation
        switch interfaceOrientation {
        case .portrait: value = .portrait
        case .portraitUpsideDown: value = .portraitUpsideDown
        case .landscapeLeft: value = .landscapeLeft
        case .landscapeRight: value = .landscapeRight
        default: return
        }
        setOrientation(value, owner: owner)
    }
    #endif

    private func refreshDevices() async {
        let sources = await pipeline.discoverDevices()
        if devices != sources.devices { devices = sources.devices }
        if selectedDeviceID == nil { selectedDeviceID = sources.preferredID }
        if let source = devices.first(where: { $0.id == selectedDeviceID }) { deviceName = source.name }
        if let selectedDeviceID, ownerID != nil, !devices.contains(where: { $0.id == selectedDeviceID }) {
            end(status: .interrupted, message: "The selected camera is disconnected. Reconnect it or explicitly choose another source.")
        }
    }

    private func receive(_ frame: PhysiqueProtectedFrame, token: UUID, revision: UInt64) {
        guard generation == token, orientationRevision == revision, phase == .live, ownerID != nil else { return }
        guard ProcessInfo.processInfo.systemUptime - frame.time <= PhysiqueCaptureLimits.frameLifetime else {
            previewImage = nil
            canCapture = false
            framingMessage = "Waiting for fresh private camera frames."
            return
        }
        lastFrameAt = frame.time
        if frame.image != nil || previewImage != nil { previewImage = frame.image }
        let usable = frame.usable && frame.image != nil
        if canCapture != usable { canCapture = usable }
        if framingMessage != frame.message { framingMessage = frame.message }
        if status != .running { status = .running }
        finishStartup()
    }

    private func invalidateAcquisition() {
        generation = UUID()
        pipeline.stop()
        watchdog?.cancel()
        watchdog = nil
        canCapture = false
        isCapturing = false
        lastFrameAt = nil
        finishStartup()
    }

    private func finishStartup() {
        let continuation = startup
        startup = nil
        continuation?.resume()
    }

    private func end(status: PhysiqueCameraStatus, message: String) {
        invalidateAcquisition()
        previewImage = nil
        candidate = nil
        candidatePose = nil
        candidateImage = nil
        phase = .stopped
        ownerID = nil
        self.status = status
        error = message
        framingMessage = message
    }

    private func watchAcquisition(token: UUID) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { return }
                guard let self, self.generation == token else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if self.phase == .capturing {
                    if now - self.phaseStartedAt > 12 {
                        self.end(status: .failed("The camera did not finish the still capture."), message: "Nothing was shared. Resume the camera and try again.")
                        return
                    }
                } else if self.phase == .live {
                    if let lastFrameAt = self.lastFrameAt, now - lastFrameAt > PhysiqueCaptureLimits.frameLifetime {
                        self.end(status: .interrupted, message: "Camera frames stopped. Resume explicitly to obtain a fresh private view.")
                        return
                    }
                    if self.lastFrameAt == nil, now - self.phaseStartedAt > 10 {
                        self.end(status: .failed("The selected camera is not providing usable frames."), message: "The camera may be unavailable or busy. Resume or choose a connected source.")
                        return
                    }
                } else { return }
            }
        }
    }
}

private enum PhysiqueCaptureLimits {
    static let frameLifetime = 1.0
    static let previewDimension = 960
    static let stillDimension = 1600
    static let maximumJPEGBytes = 1_048_576
    static let jointConfidence: Float = 0.5
}

private struct PhysiqueProtectedFrame {
    let image: CGImage?
    let usable: Bool
    let message: String
    let time: Double
}

private struct PhysiqueProtectedCapture {
    let data: Data
    let image: CGImage
}

private struct PhysiqueCaptureFailure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private final class PhysiquePhotoRequest {
    let token: UUID
    let revision: UInt64
    let pose: PhysiquePose
    let id: Int64
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Result<PhysiqueProtectedCapture, Error>, Never>?
    var processed: Result<PhysiqueProtectedCapture, Error>?
    var sourceFailure: Error?
    var finished = false

    init(token: UUID, revision: UInt64, pose: PhysiquePose, id: Int64, continuation: CheckedContinuation<Result<PhysiqueProtectedCapture, Error>, Never>) {
        self.token = token
        self.revision = revision
        self.pose = pose
        self.id = id
        self.continuation = continuation
    }

    func complete(_ result: Result<PhysiqueProtectedCapture, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: result)
    }
}

private final class PhysiqueCapturePipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    var onFrame: ((UUID, UInt64, PhysiqueProtectedFrame) -> Void)?
    var onFailure: ((UUID, PhysiqueCameraStatus, String) -> Void)?
    var onDevicesChanged: (() -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Tmax.Physique.privateCapture", qos: .userInitiated)
    private let stateLock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private let output = AVCaptureVideoDataOutput()
    private let photos = AVCapturePhotoOutput()
    private let faces = VNDetectFaceRectanglesRequest()
    private let bodies = VNDetectHumanBodyPoseRequest()
    private let people = VNDetectHumanRectanglesRequest()
    private let upperBodies = VNDetectHumanRectanglesRequest()
    private var token: UUID?
    private var revision: UInt64 = 0
    private var streaming = false
    private var request: PhysiquePhotoRequest?
    private var deviceID: String?
    private var input: AVCaptureDeviceInput?
    private var activeRevision: UInt64 = 0
    private var previousFrameAt = 0.0
    private var previousSampleTime = -Double.infinity
    private var observers: [NSObjectProtocol] = []
    #if os(iOS)
    private var orientation: AVCaptureVideoOrientation = .portrait
    #else
    private var orientation: AVCaptureVideoOrientation = .landscapeRight
    #endif

    override init() {
        super.init()
        people.upperBodyOnly = false
        upperBodies.upperBodyOnly = true
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.didStopRunningNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] note in
                if name == AVCaptureSession.didStopRunningNotification, self?.session.isRunning == true { return }
                let failure = (note.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription
                self?.interrupt(message: failure ?? "The camera session stopped. Resume explicitly.")
            })
        }
        #if os(iOS)
        observers.append(NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.interrupt(message: "The camera is temporarily unavailable. Resume when it is available.")
        })
        #endif
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                guard let self else { return }
                if name == AVCaptureDevice.wasDisconnectedNotification, let device = note.object as? AVCaptureDevice {
                    self.interrupt(disconnectedID: device.uniqueID, message: "Camera disconnected. Reconnect it or explicitly choose another source.")
                }
                self.onDevicesChanged?()
            })
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        output.setSampleBufferDelegate(nil, queue: nil)
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func discoverDevices() async -> (devices: [PhysiqueCameraDevice], preferredID: String?) {
        await withCheckedContinuation { continuation in
            queue.async {
                let sources = Self.sources()
                #if os(iOS)
                let preferred = sources.first(where: { $0.position == .front }) ?? AVCaptureDevice.default(for: .video)
                #else
                let preferred = AVCaptureDevice.default(for: .video)
                #endif
                let preferredID = preferred.flatMap { device in sources.contains(where: { $0.uniqueID == device.uniqueID }) ? device.uniqueID : nil }
                continuation.resume(returning: (sources.map { PhysiqueCameraDevice(id: $0.uniqueID, name: $0.localizedName) }, preferredID ?? sources.first?.uniqueID))
            }
        }
    }

    func start(token: UUID, deviceID: String, orientation: AVCaptureVideoOrientation, revision: UInt64) {
        stateLock.lock()
        let oldRequest = request
        request = nil
        self.token = token
        self.deviceID = deviceID
        self.revision = revision
        streaming = false
        stateLock.unlock()
        oldRequest?.complete(.failure(PhysiqueCaptureFailure("Capture was cancelled. Nothing was shared.")))
        queue.async { [self] in
            guard isCurrent(token, revision: revision) else { return }
            do {
                if session.isRunning { session.stopRunning() }
                try configure(deviceID: deviceID)
                self.orientation = orientation
                activeRevision = revision
                applyOrientation()
                previousFrameAt = 0
                previousSampleTime = -Double.infinity
                guard isCurrent(token, revision: revision) else { return }
                setStreaming(true, token: token)
                session.startRunning()
                guard isCurrent(token, revision: revision) else {
                    if session.isRunning { session.stopRunning() }
                    return
                }
                guard session.isRunning else { throw PhysiqueCaptureFailure("The selected camera could not start. It may be busy or unavailable.") }
            } catch {
                fail(token: token, status: .failed(error.localizedDescription), message: error.localizedDescription)
            }
        }
    }

    func stop() {
        stateLock.lock()
        token = nil
        streaming = false
        let pending = request
        request = nil
        stateLock.unlock()
        pending?.complete(.failure(PhysiqueCaptureFailure("Capture was cancelled. Nothing was shared.")))
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setOrientation(_ value: AVCaptureVideoOrientation, token: UUID, revision: UInt64) {
        stateLock.lock()
        guard self.token == token else { stateLock.unlock(); return }
        self.revision = revision
        stateLock.unlock()
        queue.async { [self] in
            guard isCurrent(token, revision: revision) else { return }
            orientation = value
            activeRevision = revision
            applyOrientation()
            previousFrameAt = 0
        }
    }

    func capture(token: UUID, pose: PhysiquePose, revision: UInt64) async -> Result<PhysiqueProtectedCapture, Error> {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard isCurrent(token, revision: revision), isStreaming(token), session.isRunning,
                      let connection = photos.connection(with: .video), connection.isActive,
                      AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                    continuation.resume(returning: .failure(PhysiqueCaptureFailure("No current authorized camera is available. Resume and try again.")))
                    return
                }
                let formats = photos.availablePhotoPixelFormatTypes
                let preferred = [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange].first(where: { formats.contains($0) })
                let settings: AVCapturePhotoSettings
                if let preferred { settings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: preferred]) }
                else if photos.availablePhotoCodecTypes.contains(.jpeg) { settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]) }
                else {
                    continuation.resume(returning: .failure(PhysiqueCaptureFailure("This camera cannot provide a supported still image.")))
                    return
                }
                settings.photoQualityPrioritization = .speed
                let pending = PhysiquePhotoRequest(token: token, revision: revision, pose: pose, id: settings.uniqueID, continuation: continuation)
                stateLock.lock()
                guard self.token == token, self.revision == revision, request == nil else {
                    stateLock.unlock()
                    pending.complete(.failure(PhysiqueCaptureFailure("Capture ownership changed. Nothing was shared.")))
                    return
                }
                request = pending
                stateLock.unlock()
                photos.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let current = currentStream(), current.revision == activeRevision else { return }
        let time = ProcessInfo.processInfo.systemUptime
        guard time - previousFrameAt >= 0.2 else { return }
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard sampleTime.isFinite, sampleTime > previousSampleTime else { return }
        previousSampleTime = sampleTime
        previousFrameAt = time
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            fail(token: current.token, status: .denied, message: "Camera access changed. Review the system camera permission.")
            return
        }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        autoreleasepool {
            do {
                try validateSource()
                let image = try rasterize(CIImage(cvPixelBuffer: buffer), maximumDimension: PhysiqueCaptureLimits.previewDimension)
                let protected = try protect(image, pose: nil, requireFraming: false)
                guard isCurrent(current.token, revision: current.revision), isStreaming(current.token) else { return }
                onFrame?(current.token, current.revision, PhysiqueProtectedFrame(image: protected.image, usable: protected.framed, message: protected.framed ? "Face obscured locally · Keep only you in frame" : "Include arms and lower legs in view.", time: time))
            } catch {
                guard isCurrent(current.token, revision: current.revision), isStreaming(current.token) else { return }
                onFrame?(current.token, current.revision, PhysiqueProtectedFrame(image: nil, usable: false, message: error.localizedDescription, time: time))
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let pending = photoRequest(id: photo.resolvedSettings.uniqueID) else { return }
        queue.async { [self] in
            guard isCurrent(pending.token, revision: pending.revision) else { return }
            do { try validateSource() }
            catch { pending.sourceFailure = error }
            setStreaming(false, token: pending.token)
            if session.isRunning { session.stopRunning() }
            let result: Result<PhysiqueProtectedCapture, Error> = autoreleasepool {
                do {
                    if let error { throw error }
                    if let failure = pending.sourceFailure { throw failure }
                    let raw: CIImage
                    if let buffer = photo.pixelBuffer { raw = CIImage(cvPixelBuffer: buffer) }
                    else if let image = photo.cgImageRepresentation() { raw = CIImage(cgImage: image) }
                    else { throw PhysiqueCaptureFailure("The camera did not provide a still image. Nothing was shared.") }
                    let imageOrientation: CGImagePropertyOrientation
                    #if os(macOS)
                    if let bytes = photo.fileDataRepresentation(),
                       let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                       let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                       let value = metadata[kCGImagePropertyOrientation as String] as? NSNumber,
                       let actual = CGImagePropertyOrientation(rawValue: value.uint32Value) {
                        imageOrientation = actual
                    } else { imageOrientation = .up }
                    #else
                    guard let value = photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber,
                          let actual = CGImagePropertyOrientation(rawValue: value.uint32Value) else {
                        throw PhysiqueCaptureFailure("The still image orientation could not be established. Capture again.")
                    }
                    imageOrientation = actual
                    #endif
                    guard ![CGImagePropertyOrientation.upMirrored, .downMirrored, .leftMirrored, .rightMirrored].contains(imageOrientation) else {
                        throw PhysiqueCaptureFailure("The camera supplied a mirrored still. Choose an unmirrored source.")
                    }
                    let image = try rasterize(raw.oriented(imageOrientation), maximumDimension: PhysiqueCaptureLimits.stillDimension)
                    let protected = try protect(image, pose: pending.pose, requireFraming: true)
                    guard isCurrent(pending.token, revision: pending.revision) else { throw PhysiqueCaptureFailure("Capture was cancelled. Nothing was shared.") }
                    return .success(try encode(protected.image))
                } catch { return .failure(error) }
            }
            pending.processed = result
            if pending.finished { finish(pending, result: result) }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard let pending = photoRequest(id: resolvedSettings.uniqueID) else { return }
        queue.async { [self] in
            guard isCurrent(pending.token, revision: pending.revision) else { return }
            do { try validateSource() }
            catch { pending.sourceFailure = error }
            pending.finished = true
            setStreaming(false, token: pending.token)
            if session.isRunning { session.stopRunning() }
            if let error { finish(pending, result: .failure(error)) }
            else if let failure = pending.sourceFailure { finish(pending, result: .failure(failure)) }
            else if let result = pending.processed { finish(pending, result: result) }
        }
    }

    private static func sources() -> [AVCaptureDevice] {
        #if os(macOS)
        let types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .external, .continuityCamera]
        #else
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(iOS 17, *) { types += [.external, .continuityCamera] }
        #endif
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified).devices
    }

    private func configure(deviceID: String) throws {
        guard let device = Self.sources().first(where: { $0.uniqueID == deviceID }), device.isConnected else {
            throw PhysiqueCaptureFailure("The selected camera is disconnected. Reconnect it or choose another source.")
        }
        guard !device.isSuspended else { throw PhysiqueCaptureFailure("The selected camera is suspended or unavailable. Resume it before trying again.") }
        let next = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let input { session.removeInput(input) }
        input = nil
        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        else if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        guard session.canAddInput(next) else { throw PhysiqueCaptureFailure("The selected camera cannot be opened. It may be busy or unavailable.") }
        session.addInput(next)
        input = next
        if !session.outputs.contains(output) {
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            guard session.canAddOutput(output) else { throw PhysiqueCaptureFailure("The camera cannot supply a local preview.") }
            session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: queue)
        }
        if !session.outputs.contains(photos) {
            guard session.canAddOutput(photos) else { throw PhysiqueCaptureFailure("The camera cannot supply protected still captures.") }
            session.addOutput(photos)
            photos.maxPhotoQualityPrioritization = .speed
        }
    }

    private func applyOrientation() {
        for connection in [output.connection(with: .video), photos.connection(with: .video)].compactMap({ $0 }) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = orientation }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }

    private func validateSource() throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw PhysiqueCaptureFailure("Camera permission changed. Nothing was shared.")
        }
        guard let device = input?.device, device.isConnected, !device.isSuspended else {
            throw PhysiqueCaptureFailure("The selected camera is disconnected or suspended. Resume it explicitly.")
        }
        guard !device.isPortraitEffectActive, !device.isStudioLightActive, !device.isCenterStageActive else {
            throw PhysiqueCaptureFailure("Turn off camera portrait, lighting, and automatic framing effects before capture.")
        }
        if #available(iOS 18, macOS 15, *), device.isBackgroundReplacementActive {
            throw PhysiqueCaptureFailure("Turn off camera background replacement before capture.")
        }
    }

    private func rasterize(_ image: CIImage, maximumDimension: Int) throws -> CGImage {
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite, extent.width > 0, extent.height > 0 else {
            throw PhysiqueCaptureFailure("The camera supplied invalid image dimensions.")
        }
        let scale = min(1, CGFloat(maximumDimension) / max(extent.width, extent.height))
        let normalized = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let bounds = CGRect(x: 0, y: 0, width: floor(extent.width * scale), height: floor(extent.height * scale))
        guard let result = context.createCGImage(normalized, from: bounds, format: .RGBA8, colorSpace: colorSpace) else {
            throw PhysiqueCaptureFailure("Local image processing is unavailable. Nothing was shared.")
        }
        return result
    }

    private func protect(_ image: CGImage, pose: PhysiquePose?, requireFraming: Bool) throws -> (image: CGImage, framed: Bool) {
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([faces, bodies, people, upperBodies])
        let detectedFaces = faces.results ?? []
        guard let detectedBodies = bodies.results, let detectedPeople = people.results,
              let detectedUpperBodies = upperBodies.results else {
            throw PhysiqueCaptureFailure("Can't establish face privacy. Adjust the view and try again.")
        }
        guard detectedBodies.count <= 1, detectedPeople.count <= 1, detectedUpperBodies.count <= 1, detectedFaces.count <= 1 else {
            throw PhysiqueCaptureFailure("Only you in frame. Check the background and mirrors.")
        }
        guard let body = detectedBodies.first, let person = detectedPeople.first,
              let upperBody = detectedUpperBodies.first,
              body.confidence >= PhysiqueCaptureLimits.jointConfidence,
              person.confidence >= PhysiqueCaptureLimits.jointConfidence,
              upperBody.confidence >= PhysiqueCaptureLimits.jointConfidence else {
            throw PhysiqueCaptureFailure("Can't establish a single participant. Include your body and check mirrors.")
        }
        let points = try body.recognizedPoints(.all)
        func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let point = points[name], point.confidence.isFinite, point.confidence >= PhysiqueCaptureLimits.jointConfidence,
                  point.location.x.isFinite, point.location.y.isFinite,
                  (0...1).contains(point.location.x), (0...1).contains(point.location.y) else { return nil }
            return point.location
        }
        guard let neck = point(.neck), let left = point(.leftShoulder), let right = point(.rightShoulder),
              let leftHip = point(.leftHip), let rightHip = point(.rightHip) else {
            throw PhysiqueCaptureFailure("Can't locate the head safely. Include shoulders and torso in the view.")
        }
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let shoulderSpan = hypot((left.x - right.x) * width, (left.y - right.y) * height)
        let hip = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        let torsoHeight = (neck.y - hip.y) * height
        guard torsoHeight > 0, abs(neck.x - hip.x) * width < torsoHeight * 0.65,
              abs(left.y - right.y) * height < torsoHeight * 0.25,
              person.boundingBox.insetBy(dx: -0.03, dy: -0.03).contains(neck),
              person.boundingBox.contains(hip),
              upperBody.boundingBox.insetBy(dx: -0.03, dy: -0.03).contains(neck),
              upperBody.boundingBox.insetBy(dx: -0.03, dy: -0.03).contains(left),
              upperBody.boundingBox.insetBy(dx: -0.03, dy: -0.03).contains(right) else {
            throw PhysiqueCaptureFailure("Can't establish an upright private view. Keep the camera level and include your torso.")
        }
        let headWidth = max(shoulderSpan * 0.8, torsoHeight * 0.85)
        let bottom = max(max(left.y, right.y) * height + 1, neck.y * height - torsoHeight * 0.035)
        let personTop = person.boundingBox.maxY * height
        let projectedTop = bottom + torsoHeight * 0.8
        guard headWidth > 0, personTop > bottom, personTop <= projectedTop + torsoHeight * 0.15 else {
            throw PhysiqueCaptureFailure("Can't locate the whole head safely. Keep arms clear of the head and try again.")
        }
        let headLeft = min(neck.x * width - headWidth / 2, person.boundingBox.minX * width)
        let headRight = max(neck.x * width + headWidth / 2, person.boundingBox.maxX * width)
        var mask = CGRect(x: headLeft, y: bottom, width: headRight - headLeft, height: max(personTop + torsoHeight * 0.06, projectedTop) - bottom)
        if let face = detectedFaces.first {
            let bounds = face.boundingBox
            guard face.confidence >= PhysiqueCaptureLimits.jointConfidence,
                  person.boundingBox.insetBy(dx: -0.03, dy: -0.03).contains(CGPoint(x: bounds.midX, y: bounds.midY)) else {
                throw PhysiqueCaptureFailure("The face and body view is ambiguous. Check the background and mirrors.")
            }
            let faceMask = CGRect(x: bounds.minX * width, y: bounds.minY * height, width: bounds.width * width, height: bounds.height * height).insetBy(dx: -bounds.width * width * 0.4, dy: -bounds.height * height * 0.3)
            guard mask.insetBy(dx: -headWidth * 0.25, dy: -torsoHeight * 0.15).contains(CGPoint(x: faceMask.midX, y: faceMask.midY)),
                  faceMask.minY >= max(left.y, right.y) * height else {
                throw PhysiqueCaptureFailure("Face privacy would hide required shoulder evidence. Adjust the camera and capture again.")
            }
            mask = mask.union(faceMask)
        }
        for name in [VNHumanBodyPoseObservation.JointName.leftElbow, .rightElbow, .leftWrist, .rightWrist] {
            if let limb = point(name), mask.contains(CGPoint(x: limb.x * width, y: limb.y * height)) {
                throw PhysiqueCaptureFailure("Keep arms clear of the face privacy area.")
            }
        }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        mask = mask.integral.intersection(bounds)
        guard !mask.isNull, !mask.isEmpty,
              let drawing = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw PhysiqueCaptureFailure("Face privacy processing is unavailable. Nothing was shared.")
        }
        drawing.draw(image, in: bounds)
        drawing.setFillColor(CGColor(gray: 0, alpha: 1))
        drawing.fill(mask)
        guard let protected = drawing.makeImage() else { throw PhysiqueCaptureFailure("Face privacy failed. Nothing was shared.") }
        func visible(_ name: VNHumanBodyPoseObservation.JointName) -> Bool {
            guard let location = point(name) else { return false }
            return location.x > 0.01 && location.x < 0.99 && location.y > 0.01 && location.y < 0.99
        }
        let required: [VNHumanBodyPoseObservation.JointName]
        if pose == .side || pose == nil {
            let leftSide: [VNHumanBodyPoseObservation.JointName] = [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
            let rightSide: [VNHumanBodyPoseObservation.JointName] = [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]
            required = leftSide.allSatisfy(visible) ? leftSide : rightSide
        } else {
            required = [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
        }
        let framed = required.allSatisfy(visible)
        if requireFraming, !framed { throw PhysiqueCaptureFailure("Include the required arms and lower legs, then capture again.") }
        return (protected, framed)
    }

    private func encode(_ protected: CGImage) throws -> PhysiqueProtectedCapture {
        guard protected.width >= 128, protected.height >= 128 else {
            throw PhysiqueCaptureFailure("The camera image is too small for a protected still. Choose another source.")
        }
        for quality in [0.84, 0.7, 0.55, 0.4] {
            let bytes = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else { break }
            CGImageDestinationAddImage(destination, protected, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { break }
            let data = try stripMetadata(bytes as Data)
            guard data.count <= PhysiqueCaptureLimits.maximumJPEGBytes else { continue }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let exact = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { break }
            return PhysiqueProtectedCapture(data: data, image: exact)
        }
        throw PhysiqueCaptureFailure("The protected image could not be prepared within the upload limit. Nothing was shared.")
    }

    private func stripMetadata(_ data: Data) throws -> Data {
        try data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            let failure = PhysiqueCaptureFailure("The protected JPEG could not be sanitized. Nothing was shared.")
            guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { throw failure }
            var clean = Data()
            clean.reserveCapacity(bytes.count)
            clean.append(contentsOf: bytes[0..<2])
            var offset = 2
            var sawScan = false
            while offset < bytes.count {
                let markerStart = offset
                guard bytes[offset] == 0xFF else { throw failure }
                while offset < bytes.count, bytes[offset] == 0xFF { offset += 1 }
                guard offset < bytes.count else { throw failure }
                let marker = bytes[offset]
                offset += 1
                if marker == 0xD9 {
                    guard sawScan, offset == bytes.count else { throw failure }
                    clean.append(contentsOf: bytes[markerStart..<offset])
                    return clean
                }
                guard marker != 0, marker != 0xD8, marker != 0x01, !(0xD0...0xD7).contains(marker),
                      offset + 1 < bytes.count else { throw failure }
                let length = Int(bytes[offset]) * 256 + Int(bytes[offset + 1])
                guard length >= 2, length <= bytes.count - offset else { throw failure }
                let end = offset + length
                if !(0xE0...0xEF).contains(marker), marker != 0xFE {
                    clean.append(contentsOf: bytes[markerStart..<end])
                }
                offset = end
                if marker == 0xDA {
                    sawScan = true
                    let scanStart = offset
                    while offset < bytes.count {
                        guard bytes[offset] == 0xFF else { offset += 1; continue }
                        guard offset + 1 < bytes.count else { throw failure }
                        let following = bytes[offset + 1]
                        if following == 0 || (0xD0...0xD7).contains(following) { offset += 2 }
                        else { break }
                    }
                    clean.append(contentsOf: bytes[scanStart..<offset])
                }
            }
            throw failure
        }
    }

    private func currentStream() -> (token: UUID, revision: UInt64)? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard streaming, request == nil, let token else { return nil }
        return (token, revision)
    }

    private func isCurrent(_ token: UUID, revision: UInt64) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return self.token == token && self.revision == revision
    }

    private func isStreaming(_ token: UUID) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return self.token == token && streaming
    }

    private func setStreaming(_ value: Bool, token: UUID) {
        stateLock.lock()
        if self.token == token { streaming = value }
        stateLock.unlock()
    }

    private func photoRequest(id: Int64) -> PhysiquePhotoRequest? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard request?.id == id else { return nil }
        return request
    }

    private func finish(_ pending: PhysiquePhotoRequest, result: Result<PhysiqueProtectedCapture, Error>) {
        stateLock.lock()
        guard token == pending.token, revision == pending.revision, request === pending else { stateLock.unlock(); return }
        request = nil
        stateLock.unlock()
        pending.complete(result)
    }

    private func interrupt(disconnectedID: String? = nil, message: String) {
        stateLock.lock()
        guard let current = token, disconnectedID == nil ? streaming : deviceID == disconnectedID else { stateLock.unlock(); return }
        token = nil
        streaming = false
        let pending = request
        request = nil
        stateLock.unlock()
        pending?.complete(.failure(PhysiqueCaptureFailure(message)))
        onFailure?(current, .interrupted, message)
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }

    private func fail(token: UUID, status: PhysiqueCameraStatus, message: String) {
        stateLock.lock()
        guard self.token == token else { stateLock.unlock(); return }
        self.token = nil
        streaming = false
        let pending = request
        request = nil
        stateLock.unlock()
        pending?.complete(.failure(PhysiqueCaptureFailure(message)))
        if session.isRunning { session.stopRunning() }
        onFailure?(token, status, message)
    }
}
