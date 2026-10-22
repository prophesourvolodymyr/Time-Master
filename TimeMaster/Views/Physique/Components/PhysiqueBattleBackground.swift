import Combine
import SwiftUI

@available(iOS 16.0, macOS 14.0, *)
struct PhysiqueBattleBackground: View {
    let stage: PhysiqueStage
    let cameraActive: Bool
    let motionAllowed: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @Environment(\.isEnabled) private var isEnabled
    @State private var isVisible = false
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermalState = ProcessInfo.processInfo.thermalState

    init(stage: PhysiqueStage, cameraActive: Bool, motionAllowed: Bool = true) {
        self.stage = stage
        self.cameraActive = cameraActive
        self.motionAllowed = motionAllowed
    }

    private var showsArena: Bool {
        switch stage {
        case .idle, .searching, .noOpponent:
            return false
        default:
            return true
        }
    }

    private var activeArena: Bool {
        stage == .capture || stage == .submitting || stage == .judging
    }

    private var showsLight: Bool {
        !reduceTransparency && contrast != .increased
    }

    private var animates: Bool {
        let waiting = stage == .ready || stage == .submitting || stage == .judging
        return waiting && motionAllowed && isVisible && presentationActive
            && !liveResizing && isEnabled && scenePhase == .active && !cameraActive
            && !reduceMotion && showsLight && !lowPowerMode && thermalState == .nominal
    }

    var body: some View {
        GeometryReader { geometry in
            let arenaWidth = min(
                ProfileStyle.readableWidth * 1.5,
                max(0, geometry.size.width - ProfileStyle.spacing)
            )
            let hasDecorativeSpace = arenaWidth >= ProfileStyle.touchTarget * 2
                && geometry.size.height >= ProfileStyle.touchTarget

            ZStack(alignment: .top) {
                Theme.background
                    .ignoresSafeArea()

                if showsArena && hasDecorativeSpace {
                    PhysiqueArenaEnvelope()
                        .fill(LinearGradient(
                            colors: [Theme.surface, Theme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: arenaWidth)

                    PhysiqueArenaCourt()
                        .stroke(
                            Color.white.opacity(contrast == .increased ? 0.20 : 0.07),
                            lineWidth: 1
                        )
                        .frame(width: arenaWidth)

                    PhysiqueArenaTrack()
                        .stroke(
                            Color.white.opacity(contrast == .increased ? 0.24 : 0.11),
                            lineWidth: 1
                        )
                        .frame(width: arenaWidth)

                    PhysiqueArenaRim()
                        .stroke(
                            contrast == .increased
                                ? Color.white.opacity(0.42)
                                : activeArena ? Theme.toolbarOrange.opacity(0.36) : Color.white.opacity(0.22),
                            lineWidth: 1
                        )
                        .frame(width: arenaWidth)

                    if showsLight {
                        PhysiqueArenaAtmosphere(animates: animates)
                            .frame(width: arenaWidth)
                            .id(animates)
                            .transition(.identity)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transaction { transaction in
            transaction.animation = nil
        }
        .onAppear {
            updateEnergyState()
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
        .onChange(of: scenePhase) { _ in
            updateEnergyState()
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

    private func updateEnergyState() {
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
    }
}

private struct PhysiqueArenaAtmosphere: View {
    let animates: Bool
    @State private var illuminated = false

    var body: some View {
        ZStack {
            PhysiqueArenaLightBeams()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Theme.toolbarOrange.opacity(0.24), location: 0),
                        .init(color: Theme.toolbarOrange.opacity(0.08), location: 0.45),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            PhysiqueArenaLightBanks()
                .stroke(Theme.toolbarOrange.opacity(0.8), lineWidth: 2)
        }
        .opacity(illuminated ? 1 : 0.45)
        .animation(
            animates ? .easeInOut(duration: 6).repeatForever(autoreverses: true) : nil,
            value: illuminated
        )
        .onAppear {
            illuminated = animates
        }
    }
}

private struct PhysiqueArenaEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        let cut = min(36, rect.width * 0.1)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct PhysiqueArenaCourt: Shape {
    func path(in rect: CGRect) -> Path {
        let horizon = rect.minY + rect.height * 0.26
        let farHalfWidth = rect.width * 0.18
        let nearHalfWidth = rect.width * 0.78
        var path = Path()
        for lane in -3...3 {
            let fraction = CGFloat(lane) / 3
            path.move(to: CGPoint(x: rect.midX + farHalfWidth * fraction, y: horizon))
            path.addLine(to: CGPoint(x: rect.midX + nearHalfWidth * fraction, y: rect.maxY))
        }
        for line in 0...5 {
            let fraction = CGFloat(line) / 5
            let depth = fraction * fraction
            let halfWidth = farHalfWidth + (nearHalfWidth - farHalfWidth) * depth
            let y = horizon + (rect.maxY - horizon) * depth
            path.move(to: CGPoint(x: rect.midX - halfWidth, y: y))
            path.addLine(to: CGPoint(x: rect.midX + halfWidth, y: y))
        }
        return path
    }
}

private struct PhysiqueArenaTrack: Shape {
    func path(in rect: CGRect) -> Path {
        let trackHeight = min(rect.height * 0.6, rect.width * 1.04)
        var path = Path()
        for lane in 0..<4 {
            let inset = CGFloat(lane) * 12
            path.addEllipse(in: CGRect(
                x: rect.minX - rect.width * 0.28 + inset,
                y: rect.minY + rect.height * 0.44 + inset * 0.65,
                width: rect.width * 1.56 - inset * 2,
                height: max(1, trackHeight - inset * 1.3)
            ))
        }
        return path
    }
}

private struct PhysiqueArenaRim: Shape {
    func path(in rect: CGRect) -> Path {
        let cut = min(32, rect.width * 0.1)
        let left = rect.minX + 0.5
        let right = rect.maxX - 0.5
        var path = Path()
        path.move(to: CGPoint(x: left, y: rect.minY + cut * 2))
        path.addLine(to: CGPoint(x: left, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: left + cut, y: rect.minY + 0.5))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.minY + 0.5))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.11, y: rect.minY + 9))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.11, y: rect.minY + 9))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.minY + 0.5))
        path.addLine(to: CGPoint(x: right - cut, y: rect.minY + 0.5))
        path.addLine(to: CGPoint(x: right, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: right, y: rect.minY + cut * 2))
        for side in 0..<2 {
            let x = side == 0 ? left : right
            path.move(to: CGPoint(x: x, y: rect.minY + rect.height * 0.2))
            path.addLine(to: CGPoint(x: x, y: rect.minY + rect.height * 0.4))
            path.move(to: CGPoint(x: x, y: rect.minY + rect.height * 0.6))
            path.addLine(to: CGPoint(x: x, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: x + (side == 0 ? cut : -cut), y: rect.maxY - 0.5))
        }
        return path
    }
}

private struct PhysiqueArenaLightBeams: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for side in 0..<2 {
            let direction: CGFloat = side == 0 ? 1 : -1
            let edge = side == 0 ? rect.minX : rect.maxX
            path.move(to: CGPoint(x: edge + direction * 8, y: rect.minY + rect.height * 0.12))
            path.addLine(to: CGPoint(x: edge + direction * 24, y: rect.minY + rect.height * 0.14))
            path.addLine(to: CGPoint(x: edge + direction * rect.width * 0.3, y: rect.minY + rect.height * 0.78))
            path.addLine(to: CGPoint(x: edge - direction * rect.width * 0.08, y: rect.minY + rect.height * 0.78))
            path.closeSubpath()
        }
        return path
    }
}

private struct PhysiqueArenaLightBanks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for bank in 0..<3 {
            let y = rect.minY + rect.height * (0.16 + CGFloat(bank) * 0.34)
            for light in 0..<4 {
                let inset = CGFloat(light) * 3 + 3
                let offset = CGFloat(light) * 6
                path.move(to: CGPoint(x: rect.minX + inset, y: y + offset))
                path.addLine(to: CGPoint(x: rect.minX + inset + 8, y: y + offset - 8))
                path.move(to: CGPoint(x: rect.maxX - inset, y: y + offset))
                path.addLine(to: CGPoint(x: rect.maxX - inset - 8, y: y + offset - 8))
            }
        }
        return path
    }
}
