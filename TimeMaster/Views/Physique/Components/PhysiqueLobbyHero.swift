import SwiftUI

struct PhysiqueLobbyHero: View {
    let wide: Bool
    let availableWidth: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasEntered = false
    @State private var revealed = false
    @State private var energyConstrained = ProcessInfo.processInfo.isLowPowerModeEnabled
        || ProcessInfo.processInfo.thermalState == .serious
        || ProcessInfo.processInfo.thermalState == .critical

    private var presentationReady: Bool {
        presentationActive && scenePhase == .active
    }

    private var allowsMotion: Bool {
        presentationReady && !reduceMotion && !liveResizing && !energyConstrained
    }

    private var titleSize: CGFloat {
        wide ? min(74, availableWidth * 0.083) : min(48, availableWidth / 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: wide ? 20 : 14) {
            HStack(spacing: 10) {
                PhysiqueLobbyMark()
                    .fill(Theme.toolbarOrange)
                    .frame(width: 25, height: 22)
                    .accessibilityHidden(true)
                Text("TMAX / HEAD-TO-HEAD")
                    .font(TimeMasterFont.black(11, relativeTo: .caption))
                    .tracking(2)
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("Physique Duels")
                        .font(TimeMasterFont.heading())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    invitation
                    poseSequence
                    posePlate
                        .frame(maxWidth: 260)
                        .frame(maxWidth: .infinity)
                }
            } else if wide {
                HStack(alignment: .center, spacing: 32) {
                    VStack(alignment: .leading, spacing: 18) {
                        title
                        invitation
                        poseSequence
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    posePlate
                        .frame(width: min(350, availableWidth * 0.35))
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PHYSIQUE")
                        .font(TimeMasterFont.blackItalic(titleSize, relativeTo: .largeTitle))
                        .tracking(-1.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Physique Duels")
                        .accessibilityAddTraits(.isHeader)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DUELS")
                                .font(TimeMasterFont.blackItalic(titleSize * 1.5, relativeTo: .largeTitle))
                                .tracking(-2.4)
                                .foregroundStyle(Theme.toolbarOrange)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityHidden(true)
                            invitation
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        posePlate
                            .frame(width: availableWidth * 0.33)
                    }
                    .padding(.top, 2)
                    poseSequence
                        .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, wide ? 12 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            PhysiqueLobbyCourt(wide: wide)
                .opacity(revealed ? 1 : 0.55)
                .animation(allowsMotion ? .easeOut(duration: 0.6) : nil, value: revealed)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onAppear(perform: enterIfReady)
        .onChange(of: presentationReady) { ready in
            if ready { enterIfReady() }
            else if hasEntered { settleEntrance() }
        }
        .onChange(of: allowsMotion) { allowed in
            if !allowed, hasEntered { settleEntrance() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            updateEnergyState()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            updateEnergyState()
        }
        .onDisappear(perform: settleEntrance)
        .transaction { transaction in
            if !allowsMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: -3) {
            Text("PHYSIQUE")
                .font(TimeMasterFont.blackItalic(titleSize, relativeTo: .largeTitle))
                .tracking(-2)
            Text("DUELS")
                .font(TimeMasterFont.blackItalic(titleSize * 1.34, relativeTo: .largeTitle))
                .tracking(-3)
                .foregroundStyle(Theme.toolbarOrange)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Physique Duels")
        .accessibilityAddTraits(.isHeader)
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Three poses.\nOne matchup.")
                .font(wide ? TimeMasterFont.black(22, relativeTo: .title3) : TimeMasterFont.heading())
                .fixedSize(horizontal: false, vertical: true)
            Text("AI-judged competition.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var poseSequence: some View {
        HStack(alignment: .center, spacing: 10) {
            Rectangle()
                .fill(Theme.toolbarOrange)
                .frame(width: 24, height: 2)
                .accessibilityHidden(true)
            Text("FRONT / SIDE / REAR")
                .font(TimeMasterFont.black(11, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Three poses: front, side and rear")
    }

    private var posePlate: some View {
        VStack(spacing: 10) {
            PhysiqueAthleteIllustration(pose: .front)
                .frame(height: wide ? 260 : 172)
            Text("POSE ILLUSTRATION")
                .font(TimeMasterFont.black(9, relativeTo: .caption2))
                .tracking(1.3)
                .foregroundStyle(ProfileStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .offset(x: revealed ? 0 : 14, y: revealed ? 0 : 6)
        .scaleEffect(revealed ? 1 : 0.96, anchor: .bottom)
        .opacity(revealed ? 1 : 0.75)
        .animation(allowsMotion ? .easeOut(duration: 0.55) : nil, value: revealed)
        .accessibilityHidden(true)
    }

    private func enterIfReady() {
        guard presentationReady, !hasEntered else { return }
        hasEntered = true
        revealed = true
    }

    private func settleEntrance() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hasEntered = true
            revealed = true
        }
    }

    private func updateEnergyState() {
        let process = ProcessInfo.processInfo
        energyConstrained = process.isLowPowerModeEnabled
            || process.thermalState == .serious
            || process.thermalState == .critical
    }
}

private struct PhysiqueLobbyMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.47, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.25, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.maxX * 0.62, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.78, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.4, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PhysiqueLobbyCourt: View {
    let wide: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * (wide ? 0.81 : 0.84), y: size.height * 0.5)
            let breadth = size.width * (wide ? 0.18 : 0.2)
            let top = size.height * 0.1
            let bottom = size.height * 0.89
            let ink = Color.white.opacity(contrast == .increased ? 0.24 : 0.09)
            var gate = Path()
            gate.move(to: CGPoint(x: center.x - breadth * 0.55, y: top))
            gate.addLine(to: CGPoint(x: center.x + breadth * 0.55, y: top))
            gate.addLine(to: CGPoint(x: center.x + breadth, y: center.y * 0.7))
            gate.addLine(to: CGPoint(x: center.x + breadth * 0.78, y: bottom * 0.8))
            gate.addLine(to: CGPoint(x: center.x, y: bottom))
            gate.addLine(to: CGPoint(x: center.x - breadth * 0.78, y: bottom * 0.8))
            gate.addLine(to: CGPoint(x: center.x - breadth, y: center.y * 0.7))
            gate.closeSubpath()
            if !reduceTransparency {
                context.fill(gate, with: .color(Theme.toolbarOrange.opacity(0.035)))
            }
            context.stroke(gate, with: .color(ink), lineWidth: 1)

            var court = Path()
            court.move(to: CGPoint(x: center.x - breadth * 1.7, y: size.height * 0.98))
            court.addLine(to: CGPoint(x: center.x - breadth * 0.7, y: size.height * 0.72))
            court.addLine(to: CGPoint(x: center.x + breadth * 0.7, y: size.height * 0.72))
            court.addLine(to: CGPoint(x: center.x + breadth * 1.7, y: size.height * 0.98))
            court.closeSubpath()
            court.addEllipse(in: CGRect(x: center.x - breadth * 0.8, y: size.height * 0.84, width: breadth * 1.6, height: size.height * 0.1))
            context.stroke(court, with: .color(ink), lineWidth: 1)

            var accent = Path()
            accent.move(to: CGPoint(x: center.x - breadth * 0.55, y: top))
            accent.addLine(to: CGPoint(x: center.x + breadth * 0.1, y: top))
            accent.move(to: CGPoint(x: center.x - breadth * 1.7, y: size.height * 0.98))
            accent.addLine(to: CGPoint(x: center.x - breadth * 1.25, y: size.height * 0.98))
            accent.move(to: CGPoint(x: center.x + breadth * 1.25, y: size.height * 0.98))
            accent.addLine(to: CGPoint(x: center.x + breadth * 1.7, y: size.height * 0.98))
            context.stroke(accent, with: .color(Theme.toolbarOrange.opacity(contrast == .increased ? 0.9 : 0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .square))
        }
        .clipped()
    }
}
