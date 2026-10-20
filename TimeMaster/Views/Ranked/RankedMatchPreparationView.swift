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
            HStack {
                RankedMovementArt(variation: controller.variation)
                    .frame(width: ProfileStyle.touchTarget * 2, height: ProfileStyle.touchTarget * 1.5)
                Spacer()
                Text(controller.variation.fullTitle)
                    .font(TimeMasterFont.rowTitle())
                RankedMetric(value: "60", unit: "s")
            }
            RankedCameraPreview(camera: camera).aspectRatio(4 / 3, contentMode: .fit)
            Text(camera.status == .running ? camera.tracking.reason : camera.status.message)
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: ProfileStyle.spacing) {
                RankedInfoButton(label: "Calibration", message: camera.status == .running ? camera.tracking.reason : camera.status.message, symbol: camera.tracking.calibrated ? "checkmark.circle.fill" : "viewfinder")
                    .accessibilityValue(camera.tracking.calibrated ? "Calibrated" : "Not calibrated")
                RankedMetric(value: "1.5", unit: "s")
                Spacer(minLength: 0)
                RankedIconAction(symbol: "arrow.counterclockwise", label: "Recalibrate", id: "ranked-camera-recalibrate") { camera.recalibrate() }
                    .disabled(camera.status != .running)
                RankedIconAction(symbol: "arrow.triangle.2.circlepath.camera", label: "Switch camera", id: "ranked-camera-switch") { camera.switchCamera() }
                    .disabled(camera.status != .running)
            }
            HStack(spacing: ProfileStyle.spacing) {
                RankedIconAction(symbol: "figure.strengthtraining.traditional", label: "Movement guide", id: "ranked-camera-guide", action: onRules)
                RankedInfoButton(label: "Camera privacy", message: controller.mode == .practice ? "Images stay on your device. Practice never uses competitive slots or awards Elo." : "Only timestamped joint estimates are sent for scoring. Images and video stay on this device and are never shown to your opponent.", symbol: "lock.shield")
                Spacer(minLength: 0)
                if camera.status == .denied {
                    RankedIconAction(symbol: "gearshape", label: "Open camera settings", id: "ranked-camera-settings", action: openSettings)
                } else if camera.status != .running && camera.status != .restricted {
                    RankedIconAction(symbol: "arrow.clockwise", label: "Retry camera", id: "ranked-camera-retry") { Task { await camera.start() } }
                        .disabled(camera.status == .requesting || camera.status == .starting)
                }
                if controller.variation.isAdvanced {
                    RankedInfoButton(label: "Advanced movement safety", message: "Use only a skill you already control; stop if you lose balance or feel pain. Hand contact, wall support and feet-off-floor estimates are not proof against assistance. Rated verification is unavailable until validated recordings and support evidence establish sufficient evidence.", symbol: "hand.raised")
                }
            }
            Button { Task { await controller.prepare() } } label: {
                Label(controller.mode == .practice ? "Start Practice" : "Find opponent",
                      systemImage: controller.mode == .practice ? "play.fill" : "person.2")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .disabled(!camera.tracking.calibrated || camera.status != .running || controller.busy || (controller.mode == .duel && controller.variation.isAdvanced))
            .accessibilityLabel(controller.mode == .practice ? "Start Practice" : "Find opponent")
            .accessibilityHint(controller.variation.isAdvanced && controller.mode == .duel ? "Advanced rated verification is unavailable. Choose Practice." : "Requires a calibrated camera")
            .accessibilityIdentifier("ranked-camera-continue")
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
    @ObservedObject private var account = RankedAccountStore.shared

    var body: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            RankedEloBadge(variation: variation, elo: account.rating(for: variation)?.rating)
                .frame(width: ProfileStyle.touchTarget * 4, height: ProfileStyle.touchTarget * 4)
            VStack(spacing: EverSpacing.x1) {
                Text("Finding an opponent").font(TimeMasterFont.heading())
                Text(variation.fullTitle).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            TmaxLoadingIndicator().accessibilityLabel("Finding a fair match")
            HStack(spacing: ProfileStyle.inset) {
                RankedMetric(value: "1V1", unit: "")
                Label("Near your rating", systemImage: "scope")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.toolbarOrange)
                VStack(spacing: EverSpacing.x1) {
                    Text("Search limit").font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
                    RankedMetric(value: "90", unit: "s")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Finding an opponent for \(variation.fullTitle) near your earned rating. Search expires after 90 seconds.")
            HStack {
                RankedInfoButton(label: "Matchmaking", message: "Opponents perform this exact movement near your exercise-specific earned rating. If nobody is available, try again or choose solo Practice. Cancelling before Go uses no slot and changes no rating.", symbol: "person.2")
                Spacer()
                RankedIconAction(symbol: "xmark", label: "Cancel search", id: "ranked-search-cancel", action: onCancel)
            }
        }
        .frame(maxWidth: .infinity)
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
            HStack(alignment: .top, spacing: ProfileStyle.inset) {
                ForEach(match.participants) { participant in
                    Button { player = participant } label: {
                        VStack(spacing: ProfileStyle.spacing) {
                            Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(ProfileStyle.secondary)
                            Text(participant.displayName).font(TimeMasterFont.rowTitle()).lineLimit(1)
                            Label(participant.ready ? "Ready" : "Calibrating", systemImage: participant.ready ? "checkmark.circle.fill" : "viewfinder")
                                .font(TimeMasterFont.caption().weight(.semibold))
                                .foregroundStyle(participant.ready ? Theme.toolbarOrange : ProfileStyle.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TimeMasterCardButtonStyle())
                    .accessibilityLabel(participant.isYou ? "You, \(participant.displayName)" : participant.displayName)
                    .accessibilityValue(participant.ready ? "Ready" : "Calibrating")
                }
            }
            .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
            RankedMovementArt(variation: match.variation).frame(height: ProfileStyle.touchTarget * 3)
            RankedMetric(value: "60", unit: "s")
            HStack {
                RankedIconAction(symbol: "list.bullet.clipboard", label: "Movement rules", action: onRules)
                Spacer()
                RankedInfoButton(label: "Ready room", message: "Both cameras must stay calibrated. Both athletes must be ready before the shared countdown. Cancel before Go without using a slot.", symbol: "person.2")
            }
            if match.you?.ready == true {
                VStack(spacing: EverSpacing.x2) {
                    TmaxLoadingIndicator()
                    Text("Waiting for the other athlete")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            } else {
                Button(action: onReady) {
                    Label("I'm ready", systemImage: "checkmark")
                        .font(TimeMasterFont.label())
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .disabled(!calibrated || busy)
                .accessibilityLabel("I'm ready")
                .accessibilityIdentifier("ranked-ready-confirm")
            }
        }
        .sheet(item: $player) { RankedPublicPlayerView(publicID: $0.publicID) }
    }
}
