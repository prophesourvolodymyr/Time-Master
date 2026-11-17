import Foundation
import os

/// Low-volume breadcrumbs for field diagnosis (page and navigation changes), next to the stall notices.
enum PerfLog {
    private static let logger = Logger(subsystem: "com.timemaster.perf", category: "events")

    static func event(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}

/// Logs a notice when the main thread has not answered for a quarter of a second, with a snapshot of what the main
/// thread was executing at that moment, and again when it recovers, with how long it stalled. Read it with
/// `log show --predicate 'subsystem == "com.timemaster.perf"'`.
final class MainThreadStallMonitor: @unchecked Sendable {
    static let shared = MainThreadStallMonitor()

    private let logger = Logger(subsystem: "com.timemaster.perf", category: "stall")
    private let queue = DispatchQueue(label: "com.timemaster.stall-monitor", qos: .utility)
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var mainThread: mach_port_t = 0
    private var lastAnswer = ProcessInfo.processInfo.systemUptime
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var pingOutstanding = false
    private var reported = false
    private var reportedLong = false

    /// Call on the main thread: the stall snapshots read this thread's registers and stack.
    func start() {
        guard timer == nil, Thread.isMainThread else { return }
        mainThread = mach_thread_self()
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
        let shouldReportLong = silent > 1 && !reportedLong
        if shouldReportLong { reportedLong = true }
        let shouldPing = !pingOutstanding
        if shouldPing { pingOutstanding = true }
        lock.unlock()

        if shouldReport {
            logger.notice("main thread stalled: no answer for \(Int(silent * 1000)) ms")
            logMainThreadStack()
        } else if shouldReportLong {
            logger.notice("main thread still stalled after \(Int(silent * 1000)) ms")
            logMainThreadStack()
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
            self.reportedLong = false
            self.pingOutstanding = false
            self.lock.unlock()
            if wasReported {
                self.logger.notice("main thread recovered after \(Int(gap * 1000)) ms")
            }
        }
    }

    private func logMainThreadStack() {
        let addresses = MainThreadStack.capture(of: mainThread)
        for (index, address) in addresses.prefix(26).enumerated() {
            logger.notice("  #\(index) \(MainThreadStack.describe(address), privacy: .public)")
        }
    }
}

@_silgen_name("swift_demangle")
private func swiftDemangle(
    _ mangledName: UnsafePointer<CChar>?,
    _ mangledNameLength: UInt,
    _ outputBuffer: UnsafeMutablePointer<CChar>?,
    _ outputBufferSize: UnsafeMutablePointer<UInt>?,
    _ flags: UInt32
) -> UnsafeMutablePointer<CChar>?

/// Reads the program counter, link register and frame-pointer chain of the main thread from another thread. The
/// target is suspended only while raw words are copied into pre-allocated buffers (no allocation, no locks), so it
/// cannot deadlock against the main thread; names are resolved after it has been resumed.
enum MainThreadStack {
    private static let maxFrames = 48
    private static let frames = UnsafeMutablePointer<UInt>.allocate(capacity: maxFrames)
    private static let pair = UnsafeMutablePointer<UInt>.allocate(capacity: 2)

    static func capture(of thread: mach_port_t) -> [UInt] {
        #if arch(arm64)
        guard thread != 0 else { return [] }
        let frames = frames
        let pair = pair
        let limit = maxFrames
        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<UInt32>.size)
        var captured = 0

        guard thread_suspend(thread) == KERN_SUCCESS else { return [] }
        let status = withUnsafeMutablePointer(to: &state) { pointer in
            pointer.withMemoryRebound(to: natural_t.self, capacity: Int(count)) { words in
                thread_get_state(thread, thread_state_flavor_t(ARM_THREAD_STATE64), words, &count)
            }
        }
        if status == KERN_SUCCESS {
            frames[0] = UInt(truncatingIfNeeded: state.__pc)
            frames[1] = UInt(truncatingIfNeeded: state.__lr) & 0x0000_7FFF_FFFF_FFFF
            captured = 2
            var framePointer = UInt(truncatingIfNeeded: state.__fp)
            while captured < limit, framePointer != 0, framePointer & 0xF == 0 {
                var read: vm_size_t = 0
                let result = vm_read_overwrite(
                    mach_task_self_, vm_address_t(framePointer), 16, vm_address_t(bitPattern: pair), &read
                )
                guard result == KERN_SUCCESS, read == 16 else { break }
                let next = pair[0]
                let returnAddress = pair[1] & 0x0000_7FFF_FFFF_FFFF
                if returnAddress == 0 { break }
                frames[captured] = returnAddress
                captured += 1
                if next <= framePointer { break }
                framePointer = next
            }
        }
        thread_resume(thread)
        return Array(UnsafeBufferPointer(start: frames, count: captured))
        #else
        return []
        #endif
    }

    static func describe(_ address: UInt) -> String {
        var info = Dl_info()
        guard let pointer = UnsafeRawPointer(bitPattern: address), dladdr(pointer, &info) != 0 else {
            return "0x" + String(address, radix: 16)
        }
        let image = info.dli_fname.map { URL(fileURLWithPath: String(cString: $0)).lastPathComponent } ?? "?"
        if let symbol = info.dli_sname, let base = info.dli_saddr {
            let offset = address - UInt(bitPattern: base)
            return "\(image) \(demangled(symbol).prefix(150)) +\(offset)"
        }
        let offset = info.dli_fbase.map { address - UInt(bitPattern: $0) } ?? address
        return "\(image) +0x" + String(offset, radix: 16)
    }

    private static func demangled(_ symbol: UnsafePointer<CChar>) -> String {
        if let result = swiftDemangle(symbol, UInt(strlen(symbol)), nil, nil, 0) {
            defer { free(result) }
            return String(cString: result)
        }
        return String(cString: symbol)
    }
}
