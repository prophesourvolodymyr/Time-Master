import Foundation
import os

/// Low-volume breadcrumbs for field diagnosis (page and navigation changes), next to the stall notices.
enum PerfLog {
    private static let logger = Logger(subsystem: "com.timemaster.perf", category: "events")

    static func event(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}

/// Logs a notice when the main thread has not answered for a quarter of a second, and again when it recovers, with how
/// long it stalled. Read it with `log show --predicate 'subsystem == "com.timemaster.perf"'`.
final class MainThreadStallMonitor: @unchecked Sendable {
    static let shared = MainThreadStallMonitor()

    private let logger = Logger(subsystem: "com.timemaster.perf", category: "stall")
    private let queue = DispatchQueue(label: "com.timemaster.stall-monitor", qos: .utility)
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var lastAnswer = ProcessInfo.processInfo.systemUptime
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var pingOutstanding = false
    private var reported = false

    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: .milliseconds(100), leeway: .milliseconds(25))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        if now - lastTick > 0.5 { lastAnswer = now }
        lastTick = now
        let silent = now - lastAnswer
        let shouldReport = silent > 0.25 && !reported
        if shouldReport { reported = true }
        let shouldPing = !pingOutstanding
        if shouldPing { pingOutstanding = true }
        lock.unlock()

        if shouldReport {
            logger.notice("main thread stalled: no answer for \(Int(silent * 1000)) ms")
        }
        guard shouldPing else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let answeredAt = ProcessInfo.processInfo.systemUptime
            self.lock.lock()
            let gap = answeredAt - self.lastAnswer
            let wasReported = self.reported
            self.lastAnswer = answeredAt
            self.reported = false
            self.pingOutstanding = false
            self.lock.unlock()
            if wasReported {
                self.logger.notice("main thread recovered after \(Int(gap * 1000)) ms")
            }
        }
    }
}
