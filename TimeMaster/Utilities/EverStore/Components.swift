import SwiftUI

struct EverScreenHeader: View {
    let title: String
    var context: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: EverSpacing.x4) {
            VStack(alignment: .leading, spacing: EverSpacing.x1) {
                Text(title)
                    .font(TimeMasterFont.title())
                    .foregroundStyle(EverColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let context {
                    Text(context)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(EverColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: EverSpacing.x3)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(TimeMasterFont.label())
                    .frame(minWidth: EverLayout.minimumTouchTarget, minHeight: EverLayout.minimumTouchTarget)
                    .buttonStyle(EverActionButtonStyle(isPrimary: true))
            }
        }
    }
}

struct EverSurfaceCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EverSpacing.x4)
            .background { EverSurfaceMaterial() }
    }
}

struct EverSurfaceMaterial: View {
    var radius: CGFloat = EverRadius.card
    var showsRim = true

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(EverColor.surfacePrimary)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.045), .clear, .black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                if showsRim {
                    EverSpecularRim(shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
            .modifier(EverArcStretch())
    }
}

struct EverActionRow<Trailing: View>: View {
    let title: String
    var detail: String?
    let symbol: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: EverSpacing.x3) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(EverColor.textPrimary)
                .frame(width: 28)
                .frame(minHeight: EverLayout.minimumTouchTarget)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: EverSpacing.x1) {
                Text(title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(EverColor.textPrimary)
                if let detail {
                    Text(detail)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: EverSpacing.x2)
            trailing()
        }
        .frame(minHeight: EverLayout.standardRowMinimum)
        .contentShape(Rectangle())
    }
}

extension EverActionRow where Trailing == EmptyView {
    init(title: String, detail: String? = nil, symbol: String) {
        self.init(title: title, detail: detail, symbol: symbol) {
            EmptyView()
        }
    }
}

enum EverStatusTone {
    case neutral
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .neutral: EverColor.textSecondary
        case .success: EverColor.success
        case .warning: EverColor.warning
        case .error: EverColor.error
        }
    }
}

struct EverStatusPill: View {
    let text: String
    let systemImage: String
    var tone: EverStatusTone = .neutral

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(TimeMasterFont.caption())
            .foregroundStyle(tone.color)
            .padding(.horizontal, EverSpacing.x3)
            .padding(.vertical, EverSpacing.x2)
            .background(EverColor.surfaceSecondary, in: Capsule())
            .overlay { Capsule().stroke(EverColor.borderSubtle, lineWidth: 1) }
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct EverPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(
            prominent: true,
            minimumSize: 52,
            fillsWidth: true,
            horizontalPadding: EverSpacing.x4
        )
        .makeBody(configuration: configuration)
        .font(TimeMasterFont.label())
    }
}

struct EverSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimeMasterActionButtonStyle(
            minimumSize: 52,
            fillsWidth: true,
            horizontalPadding: EverSpacing.x4
        )
        .makeBody(configuration: configuration)
        .font(TimeMasterFont.label())
    }
}

struct EverProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(EverColor.surfacePressed)
                Capsule()
                    .fill(EverColor.accent)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityValue(Text("\(Int(min(max(value, 0), 1) * 100)) percent"))
    }
}

struct EverStaticPlaceholder: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(EverColor.surfacePressed)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

struct EverSettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EverSpacing.x5) {
                content()
            }
            .padding(.horizontal, EverSpacing.x5)
            .padding(.top, EverSpacing.x4)
            .padding(.bottom, EverSpacing.x8)
            .frame(maxWidth: EverLayout.maximumReadableWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .scrollIndicators(.hidden)
        .everScreenBackground()
        .navigationTitle(title)
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}

struct EverSettingsSection<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x2) {
            Text(title.uppercased())
                .font(TimeMasterFont.caption())
                .foregroundStyle(EverColor.textTertiary)
                .tracking(0.4)
                .padding(.horizontal, EverSpacing.x1)
            EverSurfaceCard {
                VStack(alignment: .leading, spacing: EverSpacing.x2) {
                    content()
                }
            }
            if let detail {
                Text(detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, EverSpacing.x1)
            }
        }
    }
}
