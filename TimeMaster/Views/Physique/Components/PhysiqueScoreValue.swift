import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct PhysiqueScoreValue: View {
    let value: Double?
    let label: String
    let unit: String
    var revealID: String? = nil
    var animate = false
    var prominent = false
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var glyphTravel: CGFloat = 6

    private var acceptedTenths: Int? {
        guard let value, value.isFinite, (0...100).contains(value) else { return nil }
        let scaled = value * 10
        let whole = scaled.rounded()
        guard abs(scaled - whole) <= Double.ulpOfOne * 1_000 * 32 else { return nil }
        return Int(whole)
    }

    var body: some View {
        let formatted = acceptedTenths.map {
            (Double($0) / 10).formatted(.number.precision(.fractionLength(1)).locale(locale))
        }
        PhysiqueNumericReveal(
            revealID: revealID,
            animate: animate && formatted != nil,
            contentID: formatted ?? "unavailable"
        ) { glyphProgress, _ in
            VStack(alignment: .leading, spacing: prominent ? 8 : 4) {
                Text(label)
                    .font(prominent ? TimeMasterFont.label() : TimeMasterFont.caption())
                    .foregroundStyle(prominent ? Theme.textPrimary : ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        numeral(formatted, progress: glyphProgress)
                        if prominent {
                            Text("/ \(100.formatted(.number.locale(locale)))")
                                .font(TimeMasterFont.heading().monospacedDigit())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    numeral(formatted, progress: glyphProgress)
                }
                Text(unit)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityValue(Text(verbatim: formatted.map { "\($0) \(unit)" } ?? "Score details unavailable"))
    }

    private func numeral(_ formatted: String?, progress: CGFloat) -> some View {
        Text(verbatim: formatted ?? "Unavailable")
            .font(formatted == nil ? TimeMasterFont.heading() : TimeMasterFont.black(prominent ? 64 : 34, relativeTo: .largeTitle).monospacedDigit())
            .foregroundStyle(Color(red: 0.97, green: 0.94, blue: 0.87))
            .offset(y: glyphTravel * (1 - progress))
            .scaleEffect(0.97 + 0.03 * progress, anchor: .leading)
            .opacity(0.88 + 0.12 * progress)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PhysiqueNumericReveal<Content: View>: View {
    let revealID: String?
    let animate: Bool
    let contentID: String
    var isRating = false
    var includesRail = false
    var isCelebration = false
    @ViewBuilder let content: (CGFloat, CGFloat) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermalState = ProcessInfo.processInfo.thermalState
    @State private var consumedID: String?
    @State private var activeRequest: Request?
    @State private var glyphProgress: CGFloat = 1
    @State private var railProgress: CGFloat = 1

    private struct Request: Hashable {
        let id: String?
        let enabled: Bool
        let contentID: String
    }

    private var motionAllowed: Bool {
        !reduceMotion && scenePhase == .active && presentationActive && !liveResizing && !lowPower
            && thermalState != .serious && thermalState != .critical
    }

    var body: some View {
        let request = Request(id: revealID, enabled: animate, contentID: contentID)
        let moving = activeRequest == request && motionAllowed
        ZStack(alignment: .leading) {
            content(moving ? glyphProgress : 1, moving ? railProgress : 1)
                .id(moving)
                .transition(.identity)
        }
            .transaction { transaction in
                if !moving { transaction.disablesAnimations = true }
            }
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: geometry.frame(in: .global)) { _ in
                            if activeRequest != nil { settle() }
                        }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
            .task(id: request) {
                await reveal(request)
            }
            .onChange(of: reduceMotion) { _ in
                if !motionAllowed { settle() }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active { settle() }
            }
            .onChange(of: presentationActive) { enabled in
                if !enabled { settle() }
            }
            .onChange(of: liveResizing) { resizing in
                if resizing { settle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                if lowPower { settle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification).receive(on: RunLoop.main)) { _ in
                thermalState = ProcessInfo.processInfo.thermalState
                if thermalState == .serious || thermalState == .critical { settle() }
            }
            .onDisappear { settle() }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willStartLiveResizeNotification).receive(on: RunLoop.main)) { _ in
                settle()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification).receive(on: RunLoop.main)) { _ in
                settle()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification).receive(on: RunLoop.main)) { _ in
                settle()
            }
            #elseif os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).receive(on: RunLoop.main)) { _ in
                settle()
            }
            #endif
    }

    @MainActor private func reveal(_ request: Request) async {
        guard let id = request.id else { settle(); return }
        guard consumedID != id else { settle(); return }
        consumedID = id
        guard request.enabled, motionAllowed else { settle(); return }
        let startedAt = ProcessInfo.processInfo.systemUptime
        withoutAnimation {
            activeRequest = request
            glyphProgress = 0
            railProgress = includesRail ? 0 : 1
        }
        do {
            try await Task.sleep(nanoseconds: isRating ? 200_000_000 : 16_000_000)
        } catch {
            settle(request)
            return
        }
        guard !Task.isCancelled, activeRequest == request, motionAllowed else {
            settle(request)
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let glyphEnd = isCelebration ? 0.58 : (isRating ? 0.65 : 0.22)
        let end = isCelebration ? 0.85 : (isRating || includesRail ? 0.65 : 0.22)
        guard elapsed < end else { settle(request); return }
        if elapsed < glyphEnd {
            withAnimation(.easeOut(duration: glyphEnd - elapsed)) { glyphProgress = 1 }
        } else {
            withoutAnimation { glyphProgress = 1 }
        }
        if includesRail {
            withAnimation(.easeOut(duration: end - elapsed)) { railProgress = 1 }
        }
        do {
            try await Task.sleep(nanoseconds: UInt64((end - elapsed) * 1_000_000_000))
        } catch {
            settle(request)
            return
        }
        settle(request)
    }

    private func settle(_ request: Request? = nil) {
        if let request, activeRequest != request { return }
        withoutAnimation {
            activeRequest = nil
            glyphProgress = 1
            railProgress = 1
        }
    }

    private func withoutAnimation(_ action: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, action)
    }
}
