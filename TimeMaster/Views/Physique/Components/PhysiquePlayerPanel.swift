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

            Rectangle()
                .fill(Theme.background)
                .aspectRatio(mediaAspectRatio, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        media
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .padding(ProfileStyle.spacing)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
                .overlay {
                    PhysiquePlayerCorners()
                        .stroke(
                            contrast == .increased ? Theme.textPrimary : ProfileStyle.secondary,
                            style: StrokeStyle(lineWidth: contrast == .increased ? 2 : 1, lineCap: .square)
                        )
                        .padding(5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay {
            Rectangle()
                .strokeBorder(
                    contrast == .increased ? Theme.textPrimary.opacity(0.65) : Theme.separator,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    private var mediaAspectRatio: CGFloat {
        #if os(macOS)
        16.0 / 9.0
        #else
        4.0 / 3.0
        #endif
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

private struct PhysiquePlayerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 14
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
