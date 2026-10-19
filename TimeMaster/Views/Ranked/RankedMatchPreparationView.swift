import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct RankedCameraSetupView: View {
    @ObservedObject var controller: RankedMatchController
    @ObservedObject var camera: RankedCamera
    let onRules: () -> Void

    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            Text("Find your position").font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
            Text(controller.variation.fullTitle).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            RankedCameraPreview(camera: camera).frame(height: 300)
            VStack(spacing: ProfileStyle.spacing) {
                Label(camera.tracking.calibrated ? "Calibrated" : "Hold the starting position for 1.5 seconds",
                      systemImage: camera.tracking.calibrated ? "checkmark.circle.fill" : "viewfinder")
                    .font(TimeMasterFont.rowTitle()).foregroundStyle(Theme.toolbarOrange)
                Text(camera.status == .running ? camera.tracking.reason : camera.status.message)
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                Text(controller.variation.cue).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: ProfileStyle.spacing) {
                Button("Movement guide", action: onRules)
                Button("Recalibrate") { camera.recalibrate() }
                Button { camera.switchCamera() } label: { Label("Switch camera", systemImage: "arrow.triangle.2.circlepath.camera").labelStyle(.iconOnly) }
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            if camera.status == .denied {
                Button("Open camera settings", action: openSettings).buttonStyle(TimeMasterToolbarWideButtonStyle())
            } else if camera.status != .running && camera.status != .restricted {
                Button("Retry camera") { Task { await camera.start() } }.buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
            if controller.variation.isAdvanced {
                RankedServiceNotice(message: "Advanced movement. Use only a skill you already control; stop if you lose balance or feel pain. Hand contact, wall support and feet-off-floor estimates are not proof against assistance. Rated verification needs validated recordings and support evidence.")
            }
            Button {
                Task { await controller.prepare() }
            } label: {
                Label(controller.mode == .practice ? "Start Practice" : "Find opponent", systemImage: controller.mode == .practice ? "play.fill" : "person.2")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .disabled(!camera.tracking.calibrated || camera.status != .running || controller.busy || (controller.mode == .duel && controller.variation.isAdvanced))
            .accessibilityIdentifier("ranked-camera-continue")
            Text(controller.mode == .practice ? "Images stay on your device. Practice never uses competitive slots or awards Elo." : "Only timestamped joint estimates are sent for scoring. Images and video stay on this device and are never shown to your opponent.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary).multilineTextAlignment(.center)
        }
    }

    private func openSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
#else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") { NSWorkspace.shared.open(url) }
#endif
    }
}

struct RankedSearchView: View {
    let variation: RankedVariation
    let onCancel: () -> Void
    var body: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            RankedMovementArt(variation: variation).frame(height: 160)
            ProgressView()
            Text("Finding a fair match").font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
            Text(variation.fullTitle).font(TimeMasterFont.heading())
            Label("Same movement · Nearby earned rating", systemImage: "scope")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            Text("If nobody is available, try again or choose real solo Practice. Search expires after 90 seconds.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Button("Cancel search", action: onCancel).buttonStyle(TimeMasterToolbarWideButtonStyle())
            Text("No slot or rating change before Go").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
}

struct RankedOpponentReadyView: View {
    let match: RankedMatch
    let calibrated: Bool
    let busy: Bool
    let onReady: () -> Void
    let onRules: () -> Void
    @State private var player: RankedParticipant?
    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            Text("Opponent found").font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: ProfileStyle.inset) {
                ForEach(match.participants) { participant in
                    Button { player = participant } label: {
                        VStack(spacing: ProfileStyle.spacing) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 56)).foregroundStyle(ProfileStyle.secondary)
                            Text(participant.isYou ? "You" : participant.displayName).font(TimeMasterFont.rowTitle())
                            Label(participant.ready ? "Ready" : "Calibrating", systemImage: participant.ready ? "checkmark.circle.fill" : "viewfinder")
                                .font(TimeMasterFont.caption()).foregroundStyle(participant.ready ? Theme.toolbarOrange : ProfileStyle.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TimeMasterCardButtonStyle())
                }
            }
            .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
            RankedMovementArt(variation: match.variation).frame(height: 140)
            Text(match.variation.fullTitle).font(TimeMasterFont.heading())
            Text(match.variation.battleRule).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Button("Movement rules", action: onRules).buttonStyle(TimeMasterToolbarWideButtonStyle())
            if match.you?.ready == true {
                Label("Waiting for the other athlete", systemImage: "clock").font(TimeMasterFont.secondary())
            } else {
                Button("I'm ready", action: onReady).buttonStyle(TimeMasterToolbarWideButtonStyle())
                    .disabled(!calibrated || busy)
                    .accessibilityIdentifier("ranked-ready-confirm")
            }
            Text("Both cameras must stay calibrated. Cancel before Go without using a slot.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
        .multilineTextAlignment(.center)
        .sheet(item: $player) { RankedPublicPlayerView(publicID: $0.publicID) }
    }
}
