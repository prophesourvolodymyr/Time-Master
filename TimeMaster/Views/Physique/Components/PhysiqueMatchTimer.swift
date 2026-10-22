import Foundation
import SwiftUI

struct PhysiqueClock: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        case remaining, elapsed, countdown, ended, unavailable
    }

    let mode: Mode
    let label: String
    let endpoint: Double?
    let serverOffset: Double

    fileprivate func seconds(at serverTime: Double) -> Int? {
        guard mode != .ended, mode != .unavailable,
              serverOffset.isFinite, serverTime.isFinite,
              let endpoint, endpoint.isFinite else { return nil }
        let interval = mode == .elapsed ? serverTime - endpoint : endpoint - serverTime
        guard interval.isFinite else { return nil }
        let rounded = max(0, interval).rounded(mode == .elapsed ? .down : .up)
        return Int(exactly: rounded)
    }
}

struct PhysiqueTimerView: View {
    let clock: PhysiqueClock

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @State private var projection: PhysiqueClockProjection
    @State private var visible = false
    @State private var scheduleRevision = 0
    @State private var energyConstrained = false

    init(clock: PhysiqueClock) {
        self.clock = clock
        _projection = State(initialValue: PhysiqueClockProjection(serverOffset: clock.serverOffset))
    }

    var body: some View {
        let currentProjection = projection.serverOffset == clock.serverOffset
            ? projection : PhysiqueClockProjection(serverOffset: clock.serverOffset)
        presentation(projection: currentProjection)
            .onAppear {
                updateEnergyState()
                visible = true
            }
            .onDisappear { visible = false }
            .onChange(of: clock.serverOffset) { offset in
                projection = PhysiqueClockProjection(serverOffset: offset)
            }
            .onChange(of: scenePhase) { _ in
                scheduleRevision &+= 1
                updateEnergyState()
            }
            .onChange(of: presentationActive) { _ in
                scheduleRevision &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleRevision &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                updateEnergyState()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                updateEnergyState()
            }
    }

    @ViewBuilder
    private func presentation(projection: PhysiqueClockProjection) -> some View {
        if clock.mode == .ended || clock.mode == .unavailable {
            PhysiqueClockFace(clock: clock, serverTime: nil, animate: false)
        } else if visible, scenePhase == .active, presentationActive,
                  let schedule = schedule(projection: projection) {
            TimelineView(schedule) { _ in
                PhysiqueClockFace(
                    clock: clock,
                    serverTime: projection.serverTime(),
                    animate: !reduceMotion && !energyConstrained && !liveResizing
                )
            }
            .id(scheduleRevision)
        } else {
            PhysiqueClockFace(clock: clock, serverTime: projection.serverTime(), animate: false)
        }
    }

    private func schedule(projection: PhysiqueClockProjection) -> PhysiqueSecondSchedule? {
        let serverTime = projection.serverTime()
        let wallTime = Date.now
        guard clock.seconds(at: serverTime) != nil, let endpoint = clock.endpoint else { return nil }
        let boundary = wallTime.addingTimeInterval(endpoint - serverTime)
        if clock.mode == .elapsed {
            return PhysiqueSecondSchedule(boundary: boundary, end: nil)
        }
        guard endpoint > serverTime else { return nil }
        return PhysiqueSecondSchedule(boundary: boundary, end: boundary)
    }

    private func updateEnergyState() {
        let process = ProcessInfo.processInfo
        energyConstrained = process.isLowPowerModeEnabled || process.thermalState != .nominal
    }
}

private struct PhysiqueClockProjection {
    let serverOffset: Double
    let instant: ContinuousClock.Instant
    private let synchronizedTime: Double

    init(serverOffset: Double) {
        self.serverOffset = serverOffset
        instant = ContinuousClock.now
        synchronizedTime = Date.now.timeIntervalSince1970 + serverOffset
    }

    func serverTime() -> Double {
        let elapsed = instant.duration(to: ContinuousClock.now).components
        return synchronizedTime + Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }
}

private struct PhysiqueSecondSchedule: TimelineSchedule {
    let boundary: Date
    let end: Date?

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(nextDate: startDate, boundary: boundary, end: end)
    }

    struct Entries: Sequence, IteratorProtocol {
        var nextDate: Date?
        let boundary: Date
        let end: Date?

        mutating func next() -> Date? {
            guard let date = nextDate else { return nil }
            if let end, date >= end {
                nextDate = nil
            } else {
                let nextBoundary = boundary.addingTimeInterval(
                    floor(date.timeIntervalSince(boundary)) + 1
                )
                nextDate = end.map { Swift.min(nextBoundary, $0) } ?? nextBoundary
            }
            return date
        }
    }
}

private struct PhysiqueClockFace: View {
    let clock: PhysiqueClock
    let serverTime: Double?
    let animate: Bool

    @Environment(\.locale) private var locale
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let reading = PhysiqueClockReading(clock: clock, serverTime: serverTime, locale: locale)
        let animateValue = animate && reading.seconds != nil
        VStack(spacing: 8) {
            HStack(spacing: ProfileStyle.spacing) {
                PhysiqueClockPhaseMarks()
                    .stroke(Theme.toolbarOrange, lineWidth: 2)
                    .frame(width: 24, height: 12)
                    .accessibilityHidden(true)
                Text(clock.label)
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(Theme.toolbarOrange)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(animateValue ? .easeOut(duration: 0.18) : nil, value: clock.label)
                PhysiqueClockPhaseMarks()
                    .stroke(Theme.toolbarOrange, lineWidth: 2)
                    .rotationEffect(.degrees(180))
                    .frame(width: 24, height: 12)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)

            PhysiqueClockDisplay(clock: clock, reading: reading, animate: animateValue)
                .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.91))
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .leftToRight)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.top, ProfileStyle.inset)
        .padding(.bottom, ProfileStyle.inset + 6)
        .background(Theme.background)
        .overlay {
            PhysiqueClockChassis()
                .stroke(
                    contrast == .increased ? Color.white.opacity(0.48) : Color.white.opacity(0.16),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clock.label)
        .accessibilityValue(reading.spokenValue)
        .transaction { transaction in
            if !animateValue {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}

private struct PhysiqueClockDisplay: View {
    let clock: PhysiqueClock
    let reading: PhysiqueClockReading
    let animate: Bool

    var body: some View {
        if clock.mode == .ended {
            Text(reading.value)
                .font(TimeMasterFont.black(48, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
        } else if reading.seconds == nil {
            VStack(spacing: 2) {
                Text(reading.value)
                    .font(TimeMasterFont.black(88, relativeTo: .largeTitle))
                units
            }
        } else {
            ViewThatFits(in: .horizontal) {
                timeField(size: 112)
                timeField(size: 96)
                if clock.mode != .countdown, let seconds = reading.seconds {
                    PhysiqueClockStackedTime(seconds: seconds)
                } else {
                    timeField(size: 72)
                }
            }
        }
    }

    private var units: some View {
        Text(reading.units ?? "")
            .textCase(.uppercase)
            .tracking(2)
            .font(TimeMasterFont.technical())
            .foregroundStyle(ProfileStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func timeField(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            PhysiqueClockNumerals(clock: clock, reading: reading, animate: animate)
                .font(TimeMasterFont.black(size, relativeTo: .largeTitle))
                .tracking(-4)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
            units
        }
    }
}

private struct PhysiqueClockNumerals: View {
    let clock: PhysiqueClock
    let reading: PhysiqueClockReading
    let animate: Bool

    var body: some View {
        if clock.mode == .countdown {
            ZStack {
                Text(reading.value)
                    .id(reading.seconds)
                    .transition(animate ? .asymmetric(
                        insertion: .modifier(
                            active: PhysiqueCountdownEmphasis(progress: 0),
                            identity: PhysiqueCountdownEmphasis(progress: 1)
                        ),
                        removal: .opacity
                    ) : .identity)
            }
            .animation(animate ? .easeOut(duration: 0.22) : nil, value: reading.seconds)
        } else if #available(iOS 17.0, macOS 14.0, *) {
            Text(reading.value)
                .contentTransition(.numericText(countsDown: clock.mode != .elapsed))
                .animation(animate ? .easeOut(duration: 0.2) : nil, value: reading.value)
        } else {
            Text(reading.value)
                .contentTransition(.opacity)
                .animation(animate ? .easeOut(duration: 0.18) : nil, value: reading.value)
        }
    }
}

private struct PhysiqueClockStackedTime: View {
    let seconds: Int

    var body: some View {
        VStack(spacing: 4) {
            if seconds >= 3_600 {
                unit(seconds / 3_600, title: "hours")
            }
            unit((seconds / 60) % 60, title: "minutes")
            unit(seconds % 60, title: "seconds")
        }
    }

    private func unit(_ value: Int, title: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value, format: .number.grouping(.never))
                .font(TimeMasterFont.black(64, relativeTo: .largeTitle))
                .monospacedDigit()
            Text(title)
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PhysiqueClockPhaseMarks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for mark in 0..<3 {
            let x = rect.minX + CGFloat(mark) * rect.width * 0.3
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.width * 0.3, y: rect.minY))
        }
        return path
    }
}

private struct PhysiqueClockChassis: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 0.5
        let cut = min(18, rect.width * 0.06)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + inset))
        path.move(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + cut))
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - cut))
        for mark in 0..<5 {
            let x = rect.midX + CGFloat(mark - 2) * 8
            path.move(to: CGPoint(x: x, y: rect.maxY - 5))
            path.addLine(to: CGPoint(x: x, y: rect.maxY - 1))
        }
        return path
    }
}

private struct PhysiqueClockReading {
    let value: String
    let units: String?
    let spokenValue: String
    let seconds: Int?

    init(clock: PhysiqueClock, serverTime: Double?, locale: Locale) {
        if clock.mode == .ended {
            value = String(localized: "Ended", locale: locale)
            units = nil
            spokenValue = value
            seconds = nil
            return
        }
        guard let serverTime, let seconds = clock.seconds(at: serverTime) else {
            value = "—"
            units = String(localized: "Time unavailable", locale: locale)
            spokenValue = units ?? ""
            self.seconds = nil
            return
        }
        if clock.mode == .countdown, seconds == 0 {
            value = "—"
            units = String(localized: "Confirming start", locale: locale)
            spokenValue = units ?? ""
            self.seconds = nil
            return
        }
        self.seconds = seconds
        let duration = Duration.seconds(seconds)
        if clock.mode == .countdown {
            value = seconds.formatted(.number.grouping(.never).locale(locale))
            units = String(localized: "seconds", locale: locale)
        } else {
            let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3_600
                ? .hourMinuteSecond(padHourToLength: 1, fractionalSecondsLength: 0)
                : .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 0)
            value = duration.formatted(Duration.TimeFormatStyle(pattern: pattern, locale: locale))
            units = seconds >= 3_600
                ? String(localized: "hr : min : sec", locale: locale)
                : String(localized: "min : sec", locale: locale)
        }
        let spokenUnits: Set<Duration.UnitsFormatStyle.Unit> = seconds == 0 ? [.seconds] : [.hours, .minutes, .seconds]
        spokenValue = duration.formatted(
            .units(
                allowed: spokenUnits,
                width: .wide,
                zeroValueUnits: seconds == 0 ? .show(length: 1) : .hide
            ).locale(locale)
        )
    }
}

private struct PhysiqueCountdownEmphasis: AnimatableModifier {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let fraction = min(1, max(0, progress))
        content.scaleEffect(CGFloat(1 + 0.06 * sin(.pi * fraction)))
    }
}
