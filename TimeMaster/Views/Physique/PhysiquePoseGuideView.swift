import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiquePoseGuideView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var minimumChoiceWidth: CGFloat = 136
    @State private var selectedPose: PhysiquePose = .front
    @State private var howToExpanded = false
    @State private var framingExpanded = false
    @State private var energyRestricted = ProcessInfo.processInfo.isLowPowerModeEnabled
        || ProcessInfo.processInfo.thermalState == .serious
        || ProcessInfo.processInfo.thermalState == .critical
    @AccessibilityFocusState private var headingFocused: Bool

    private var allowsMotion: Bool {
        !reduceMotion && !energyRestricted && scenePhase == .active
    }

    var body: some View {
        GeometryReader { geometry in
            let roomy = usesRoomyLayout(in: geometry.size)
            let contentWidth = min(roomy ? 1180 : ProfileStyle.readableWidth, max(0, geometry.size.width - ProfileStyle.inset * 2))
            let selectorRowWidth = minimumChoiceWidth * CGFloat(PhysiquePose.allCases.count)
                + ProfileStyle.spacing * CGFloat(PhysiquePose.allCases.count - 1)
            let layout = roomy
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
            let detailLayout = roomy
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(alignment: .center, spacing: 24))

            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Pose guide")
                                .font(TimeMasterFont.display())
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($headingFocused)
                            Label("Illustrations only", systemImage: "book.closed")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(ProfileStyle.secondary)
                                .accessibilityLabel("Illustrations only. This guide does not open a camera, take photos, or send images.")
                        }

                        layout {
                            PhysiqueGuideSelector(
                                selection: selectedPose,
                                vertical: roomy || dynamicTypeSize.isAccessibilitySize || contentWidth < selectorRowWidth,
                                minimumChoiceWidth: minimumChoiceWidth,
                                onSelect: selectPose
                            )
                            .frame(width: roomy ? max(150, minimumChoiceWidth) : nil)

                            detailLayout {
                                PhysiqueGuidePlate(pose: selectedPose, allowsMotion: allowsMotion)
                                    .frame(maxWidth: roomy ? 360 : 420)
                                    .frame(maxWidth: roomy ? 360 : .infinity)

                                PhysiqueGuideInstructions(
                                    pose: selectedPose,
                                    howToExpanded: $howToExpanded,
                                    framingExpanded: $framingExpanded,
                                    allowsMotion: allowsMotion
                                )
                                .frame(maxWidth: roomy ? 440 : ProfileStyle.readableWidth, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .id("pose-reference")
                        }

                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Reading is not consent or camera permission. Camera setup is a separate, deliberate step.")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(ProfileStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            PhysiqueAction(title: "Open camera setup", systemImage: "camera", action: openCameraSetup)
                        }
                        .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: selectedPose) { _ in
                    reader.scrollTo("pose-reference", anchor: .top)
                }
            }
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .navigationTitle("Pose guide")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: closeGuide)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .transaction { transaction in
            if !allowsMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .onAppear { headingFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            updateEnergyState()
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            updateEnergyState()
        }
    }

    private func usesRoomyLayout(in size: CGSize) -> Bool {
        #if os(macOS)
        size.width >= 1060 && size.height >= 560 && !dynamicTypeSize.isAccessibilitySize
        #else
        false
        #endif
    }

    private func selectPose(_ pose: PhysiquePose) {
        guard pose != selectedPose else { return }
        selectedPose = pose
        let announcement = String(localized: "\(pose.title). \(PhysiqueGuideInstructions.cue(for: pose))")
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #elseif os(macOS)
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [.announcement: announcement, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
        #endif
    }

    private func updateEnergyState() {
        let process = ProcessInfo.processInfo
        energyRestricted = process.isLowPowerModeEnabled
            || process.thermalState == .serious
            || process.thermalState == .critical
    }

    private func closeGuide() {
        dismiss()
    }

    private func openCameraSetup() {
        onOpen(.camera)
    }
}

@MainActor
private struct PhysiqueGuideSelector: View {
    let selection: PhysiquePose
    let vertical: Bool
    let minimumChoiceWidth: CGFloat
    let onSelect: (PhysiquePose) -> Void

    @FocusState private var focusedPose: PhysiquePose?

    var body: some View {
        let layout = vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: ProfileStyle.spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: ProfileStyle.spacing))

        layout {
            ForEach(PhysiquePose.allCases) { pose in
                Button {
                    onSelect(pose)
                } label: {
                    HStack(spacing: 8) {
                        PhysiquePoseIcon(pose: pose, selected: selection == pose)
                            .accessibilityHidden(true)
                        Image(systemName: selection == pose ? "largecircle.fill.circle" : "circle")
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity)
                    #if os(iOS)
                    .frame(minHeight: ProfileStyle.touchTarget)
                    #endif
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
                }
                .accessibilityLabel(Text(LocalizedStringKey(pose.title)))
                .accessibilityValue(Text("Reference \(referenceNumber(for: pose)) of 3"))
                .accessibilityHint("Shows reference instructions only. Does not change the capture pose.")
                .accessibilityAddTraits(selection == pose ? [.isButton, .isSelected] : .isButton)
                .buttonStyle(.bordered)
                .tint(selection == pose ? Theme.toolbarOrange : Theme.textPrimary)
                .focused($focusedPose, equals: pose)
                .frame(minWidth: vertical ? nil : minimumChoiceWidth, maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reference pose")
        #if os(macOS)
        .onMoveCommand(perform: moveSelection)
        #endif
    }

    private func referenceNumber(for pose: PhysiquePose) -> Int {
        switch pose {
        case .front: return 1
        case .side: return 2
        case .rear: return 3
        }
    }

    #if os(macOS)
    private func moveSelection(_ direction: MoveCommandDirection) {
        guard let focusedPose,
              let index = PhysiquePose.allCases.firstIndex(of: focusedPose) else { return }
        let next: Int
        switch direction {
        case .left, .up: next = max(0, index - 1)
        case .right, .down: next = min(PhysiquePose.allCases.count - 1, index + 1)
        default: return
        }
        let pose = PhysiquePose.allCases[next]
        self.focusedPose = pose
        onSelect(pose)
    }
    #endif
}

private struct PhysiqueGuidePlate: View {
    let pose: PhysiquePose
    let allowsMotion: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                PhysiqueAthleteIllustration(pose: pose)
                    .padding(24)
                    .id(pose)
                    .transition(allowsMotion ? .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)) : .identity)
            }
            .animation(allowsMotion ? .easeOut(duration: 0.28) : nil, value: pose)

            Capsule()
                .fill(Theme.toolbarOrange)
                .frame(width: 72, height: 2)
                .padding(.bottom, 14)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .background(Theme.surface)
        .overlay {
            PhysiqueGuideFramingMarks()
                .stroke(contrast == .increased ? Theme.textPrimary : ProfileStyle.secondary, lineWidth: 1.5)
                .padding(8)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(description))
        .accessibilityAddTraits(.isImage)
    }

    private var description: LocalizedStringKey {
        switch pose {
        case .front:
            return "Front view of a covered figure with elbows bent, hands clear of the head, relaxed knees, and both legs and feet visible. The whole head, hands, elbows, and feet fit inside the frame. The figure demonstrates position, not a target body shape."
        case .side:
            return "Whole-body side view of a covered figure with head and feet facing the same direction, a neutral spine, naturally bent arms, and both feet supported. Either comfortable side is valid; the example is not a favored scoring side."
        case .rear:
            return "Rear view of a covered figure with both elbows bent, hands clear of the head, and both legs and feet visible. The top remains on and shorts cover the buttocks. The whole head, hands, elbows, and feet fit inside the frame."
        }
    }
}

private struct PhysiqueGuideFramingMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = min(18, rect.width * 0.08)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        return path
    }
}

private struct PhysiqueGuideInstructions: View {
    let pose: PhysiquePose
    @Binding var howToExpanded: Bool
    @Binding var framingExpanded: Bool
    let allowsMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text(LocalizedStringKey(pose.title))
                    .font(TimeMasterFont.title())
                    .accessibilityAddTraits(.isHeader)
                Text(Self.cue(for: pose))
                    .font(TimeMasterFont.body())
            }
            .fixedSize(horizontal: false, vertical: true)
            .id(pose)
            .transition(.opacity)
            .animation(allowsMotion ? .easeOut(duration: 0.18) : nil, value: pose)

            Label("Breathe normally. Stop if uncomfortable.", systemImage: "heart")
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)

            PhysiqueCard {
                DisclosureGroup("How to pose", isExpanded: $howToExpanded) {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        positioning
                        Text("A comfortable variation is not a negative body attribute. The same required comparison evidence must still be available for both people. An illustration cannot approve an adaptation or override a service check. Insufficient comparable evidence means no contest, not an invented low score.")
                    }
                    .font(TimeMasterFont.body())
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ProfileStyle.spacing)
                }
                .font(TimeMasterFont.sectionTitle())
                .animation(allowsMotion ? .easeInOut(duration: 0.2) : nil, value: howToExpanded)
            }

            PhysiqueCard {
                DisclosureGroup("Framing & clothing", isExpanded: $framingExpanded) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Frame the whole pose").font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
                            Text("Place the device securely, far enough back to include your whole head, hands, elbows, and feet together. Keep the camera roughly level and stable, with ordinary even lighting. Avoid steep angles, dramatic shadows, or placing a limb close to the lens to exaggerate size.")
                            Text("Camera height, distance, device price, body weight, and pixel size are not scoring targets. Move the device or adjust framing before attempting an uncomfortable pose. Leave room to lower your arms and turn safely without hitting furniture. Never step backwards blindly while facing away.")
                            Text("Keep shoulder, upper-arm, upper-back, thigh, and calf evidence in frame. Do not crop toward an intimate region. This static framing example does not assess or accept a real capture.")
                        }

                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Wear comfortable, permitted coverage").font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
                            Text("An opaque athletic top or opaque sports bra is permitted. A privately declared adult man may also pose shirtless in this nonsexual fitness context. Other participants wear an opaque athletic top or sports bra. Everyone keeps the groin and buttocks covered by opaque sports clothing throughout every turn and pose, including the rear view.")
                            Text("More visible skin is not an advantage. Wearing a permitted top is not a penalty. The common-region rubric uses observable shoulder, upper-arm, upper-back, and leg evidence. Front-chest and abdominal appearance are excluded for both people. Breast, nipple, groin, and buttock anatomy are not judging regions.")
                            Text("Required upper-arm and calf evidence must be usable without inventing anatomy under fabric. If permitted clothing obscures required evidence, the capture flow may explain the issue and offer a safe adjustment or recapture within its existing limits. It must not demand removal of required coverage, invent hidden anatomy, or score an unseen region as zero. A permitted garment does not guarantee sufficient evidence.")
                        }

                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Choose a private, safe space").font(TimeMasterFont.sectionTitle()).accessibilityAddTraits(.isHeader)
                            Text("Only you may appear. Check mirrors and the background for another person and identifying objects. A helper may position the device from outside the frame. A bystander invalidates a capture even if their face can be obscured or they say they consent.")
                            Text("This guide uses local illustrations only. It does not request camera, microphone, Photos, location, login, or image-processing permission. Actual capture has separate eligibility and affirmative AI-processing and opponent-sharing choices.")
                            Text("Before any actual candidate or selected still is transferred, face areas must be obscured locally and the exact redacted image previewed. If redaction fails, transfer stops; the original is never a fallback. Masking does not guarantee anonymity, and permitted opponent stills cannot be made absolutely copy-proof.")
                        }
                    }
                    .font(TimeMasterFont.body())
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ProfileStyle.spacing)
                }
                .font(TimeMasterFont.sectionTitle())
                .animation(allowsMotion ? .easeInOut(duration: 0.2) : nil, value: framingExpanded)
            }
        }
    }

    static func cue(for pose: PhysiquePose) -> String {
        switch pose {
        case .front: return String(localized: "Face forward. Raise your arms comfortably.")
        case .side: return String(localized: "Turn side-on. Keep your stance relaxed.")
        case .rear: return String(localized: "Face away. Raise your arms comfortably.")
        }
    }

    @ViewBuilder
    private var positioning: some View {
        switch pose {
        case .front:
            Text("Stand facing the camera on a stable surface, feet comfortably apart and knees relaxed.")
            Text("Raise your upper arms toward shoulder height only as comfortable, then bend your elbows into a recognizable double-biceps position. Keep your hands relaxed and breathe normally. Do not force a clench, arch, or twist.")
            Text("Keep both shoulder and upper-arm outlines and both thigh and calf outlines visible. Your whole head, hands, elbows, and feet stay inside the frame.")
        case .side:
            Text("Lower your arms before turning. Move your feet and torso together to face sideways rather than twisting at the waist. Use either comfortable side; this example is not a favored scoring side.")
            Text("Bend the near elbow naturally. Where comfortable, keep the far upper arm slightly clear of your torso. Do not clasp and pull, squeeze the chest, hinge forward, or arch to exaggerate size.")
            Text("Keep your head facing the same direction as your feet, your spine neutral, both feet supported, and shoulder, upper-arm, and leg contours interpretable. Breathe normally.")
        case .rear:
            Text("Lower your arms, then turn slowly until your back faces the camera. Regain a stable, relaxed stance before raising your arms.")
            Text("Raise your upper arms only as comfortable and bend your elbows. Breathe normally. Keep both shoulder and upper-arm outlines, an interpretable upper-back outline, and both thigh and calf outlines visible. Keep clothing coverage intact.")
            Text("Do not twist your neck around to inspect the screen or step backwards blindly. Use the capture flow’s accessible self-timer when actually taking a photo. This guide does not start a timer or camera.")
        }
    }
}
