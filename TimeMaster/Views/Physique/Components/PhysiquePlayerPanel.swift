import SwiftUI

struct PhysiquePlayerPanel<Media: View>: View {
    let title: String
    let status: String
    private let media: Media

    @Environment(\.colorSchemeContrast) private var contrast

    init(title: String, status: String, @ViewBuilder media: () -> Media) {
        self.title = title
        self.status = status
        self.media = media()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                Text(title)
                    .font(TimeMasterFont.blackItalic(26, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .accessibilityAddTraits(.isHeader)

                Rectangle()
                    .fill(contrast == .increased ? ProfileStyle.secondary : Theme.separator)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                PhysiquePlayerStripe()
                    .fill(Theme.toolbarOrange)
                    .frame(width: 27, height: 17)
                    .accessibilityHidden(true)
            }
            .padding(ProfileStyle.inset)

            VStack(spacing: -6) {
                RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous)
                    .fill(Theme.background)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        GeometryReader { geometry in
                            media
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .padding(ProfileStyle.corner)
                        .transaction { transaction in
                            transaction.animation = nil
                            transaction.disablesAnimations = true
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous)
                            .strokeBorder(outline, lineWidth: contrast == .increased ? 2 : 1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, ProfileStyle.inset)
                    .zIndex(1)

                supportingBase
            }

            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Theme.toolbarOrange)
                    .frame(width: 16, height: 2)
                    .padding(.top, 10)
                    .accessibilityHidden(true)

                Text(status)
                    .font(TimeMasterFont.body(15))
                    .foregroundStyle(contrast == .increased ? Theme.textPrimary : ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(ProfileStyle.inset)
        }
        .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
    }

    private var outline: Color {
        contrast == .increased ? Theme.textPrimary.opacity(0.65) : ProfileStyle.secondary.opacity(0.35)
    }

    private var supportingBase: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: ProfileStyle.corner / 2, style: .continuous)
                .fill(Theme.surface2)
                .frame(height: ProfileStyle.corner)
                .overlay {
                    RoundedRectangle(cornerRadius: ProfileStyle.corner / 2, style: .continuous)
                        .strokeBorder(outline, lineWidth: 1)
                }
                .padding(.horizontal, ProfileStyle.spacing / 2)
                .padding(.bottom, ProfileStyle.spacing)

            RoundedRectangle(cornerRadius: ProfileStyle.corner / 2, style: .continuous)
                .fill(Theme.surface)
                .frame(height: ProfileStyle.corner)
                .overlay {
                    RoundedRectangle(cornerRadius: ProfileStyle.corner / 2, style: .continuous)
                        .strokeBorder(outline, lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Theme.toolbarOrange)
                        .frame(width: 72, height: 3)
                        .padding(.top, 4)
                }
        }
        .frame(height: ProfileStyle.corner + ProfileStyle.spacing)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PhysiquePlayerStripe: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.64, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.29, y: rect.maxY))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.width * 0.45, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

