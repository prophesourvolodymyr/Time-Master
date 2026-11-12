import SwiftUI

struct PhysiqueGlowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
        configuration.label
            .font(TimeMasterFont.black(17, relativeTo: .body))
            .foregroundStyle(.white)
            .shadow(color: TmaxGlow.rust.opacity(0.6), radius: 1.5, y: 1)
            .padding(.horizontal, ProfileStyle.inset)
            .padding(.vertical, ProfileStyle.spacing)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                shape.fill(TmaxGlow.fill)
                shape.fill(EllipticalGradient(
                    stops: [
                        .init(color: TmaxGlow.peach.opacity(0.55), location: 0),
                        .init(color: TmaxGlow.peach.opacity(0), location: 1)
                    ],
                    center: UnitPoint(x: 0.5, y: 1.3),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8
                ))
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(contrast == .increased ? 0.75 : 0.4), TmaxGlow.peach.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
                if isFocused {
                    shape.inset(by: -4)
                        .strokeBorder(Theme.textPrimary, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .background {
                shape.fill(TmaxGlow.flame.opacity(0.4))
                    .blur(radius: 14)
                    .offset(y: 6)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
            .background(SlotNavigationContentClearanceReader(primaryAction: true))
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: Theme.controlCornerRadius))
    }
}

struct PhysiqueGlowCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 22
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tmaxGlowSurface(cornerRadius: cornerRadius, glow: 0.75)
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.textPrimary.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
            .background(SlotNavigationContentClearanceReader())
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: cornerRadius))
    }
}

struct PhysiqueLobbyChip: View {
    let text: String
    let systemImage: String
    var accent = false
    var busy = false

    init(_ text: String, systemImage: String, accent: Bool = false, busy: Bool = false) {
        self.text = text
        self.systemImage = systemImage
        self.accent = accent
        self.busy = busy
    }

    var body: some View {
        HStack(spacing: EverSpacing.x2) {
            if busy {
                TmaxLoadingIndicator(size: 12)
            } else {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent ? TmaxGlow.blaze : ProfileStyle.secondary)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textPrimary.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.42)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct PhysiqueRankCrest: View {
    let rating: Int?
    let caption: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let side = max(1, min(geometry.size.width, geometry.size.height))
            ZStack {
                Image("RankedEloCrest")
                    .resizable()
                    .scaledToFit()
                    .saturation(rating == nil ? 0.2 : 1)
                VStack(spacing: side * 0.015) {
                    PhysiqueAthleteIllustration(pose: .front)
                        .frame(width: side * 0.22, height: side * 0.3)
                    Text(rating.map { $0.formatted() } ?? "—")
                        .font(TimeMasterFont.black(side * 0.17).monospacedDigit())
                        .dynamicTypeSize(.medium)
                        .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: rating)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(caption)
                        .font(TimeMasterFont.body(side * 0.08))
                        .dynamicTypeSize(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: side * 0.6)
                .offset(y: side * 0.025)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct PhysiqueResultPip: View {
    let systemImage: String
    var highlighted = false

    var body: some View {
        ZStack {
            Circle().fill(highlighted ? AnyShapeStyle(TmaxGlow.fill) : AnyShapeStyle(Color.black.opacity(0.45)))
            Circle().strokeBorder(highlighted ? TmaxGlow.peach.opacity(0.75) : Color.white.opacity(0.2), lineWidth: 1)
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textPrimary.opacity(highlighted ? 1 : 0.86))
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

struct PhysiqueLobbyNotice: View {
    let title: String
    let detail: String
    let systemImage: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) { expanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TmaxGlow.blaze)
                    .frame(width: 24, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TimeMasterFont.rowTitle())
                        .lineLimit(expanded ? nil : 1)
                    Text(detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                        .lineLimit(expanded ? nil : 1)
                        .fixedSize(horizontal: false, vertical: expanded)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: expanded ? "chevron.up" : "info.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ProfileStyle.secondary)
                    .frame(width: 22, height: 22)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
            .background(shape.fill(Color.black.opacity(0.45)))
            .overlay(shape.strokeBorder(TmaxGlow.flame.opacity(0.38), lineWidth: 1).allowsHitTesting(false))
            .contentShape(shape)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .accessibilityHint(expanded ? "Shows less" : "Shows the full message")
        .accessibilityAddTraits(.isButton)
    }
}

struct PhysiquePoseLoadout: View {
    let showsSharing: Bool

    var body: some View {
        HStack(spacing: ProfileStyle.spacing) {
            HStack(spacing: EverSpacing.x1) {
                ForEach(PhysiquePose.allCases) { pose in
                    VStack(spacing: 3) {
                        PhysiqueAthleteIllustration(pose: pose)
                            .frame(width: 26, height: 38)
                        Text(pose.shortTitle)
                            .font(TimeMasterFont.micro())
                            .foregroundStyle(ProfileStyle.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(minWidth: 36)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Three poses")
                    .font(TimeMasterFont.rowTitle())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: EverSpacing.x1) { chips }
                    VStack(alignment: .leading, spacing: EverSpacing.x1) { chips }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: EverSpacing.x1) {
                Image(systemName: "figure.stand")
                    .font(.title3.weight(.semibold))
                Text("Guide")
                    .font(TimeMasterFont.micro())
            }
            .foregroundStyle(TmaxGlow.blaze)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var chips: some View {
        PhysiqueLobbyChip("AI judged", systemImage: "sparkles", accent: true)
        if showsSharing {
            PhysiqueLobbyChip("Stills shared after result", systemImage: "eye")
        }
    }
}
