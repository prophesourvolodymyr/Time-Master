import SwiftUI

struct PhysiqueLobbyHero<Leading: View, Trailing: View, Footer: View>: View {
    let artTopInset: CGFloat
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let footer: () -> Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
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

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Text("1V1")
                    .font(TimeMasterFont.black(max(1, size.width * 0.38)))
                    .foregroundStyle(.white.opacity(contrast == .increased ? 0.08 : 0.035))
                    .rotationEffect(.degrees(-12))
                    .offset(y: -size.height * 0.12)
                    .accessibilityHidden(true)
                Ellipse()
                    .fill(EllipticalGradient(
                        stops: [
                            .init(color: TmaxGlow.flame.opacity(0.34), location: 0),
                            .init(color: TmaxGlow.ember.opacity(0.16), location: 0.5),
                            .init(color: TmaxGlow.ember.opacity(0), location: 1)
                        ],
                        center: .center,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.5
                    ))
                    .frame(width: size.width * 0.82, height: size.height * 0.96)
                    .offset(y: size.height * 0.1)
                    .scaleEffect(revealed ? 1 : 0.82)
                    .opacity(revealed ? 1 : 0)
                    .accessibilityHidden(true)
                Ellipse()
                    .fill(EllipticalGradient(
                        stops: [
                            .init(color: TmaxGlow.peach.opacity(0.28), location: 0),
                            .init(color: TmaxGlow.flame.opacity(0), location: 1)
                        ],
                        center: .center,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.5
                    ))
                    .frame(width: size.width * 0.66, height: max(1, size.height * 0.12))
                    .offset(y: size.height * 0.42)
                    .accessibilityHidden(true)
                PhysiqueAthleteIllustration(pose: .front)
                    .aspectRatio(300.0 / 430.0, contentMode: .fit)
                    .padding(.top, artTopInset)
                    .padding(.bottom, ProfileStyle.spacing)
                    .frame(width: size.width, height: size.height)
                    .offset(y: revealed ? 0 : 14)
                    .opacity(revealed ? 1 : 0)
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                        leading()
                        Spacer(minLength: 0)
                        trailing()
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: ProfileStyle.spacing) {
                        footer()
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .animation(allowsMotion ? .spring(response: 0.62, dampingFraction: 0.86) : nil, value: revealed)
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
