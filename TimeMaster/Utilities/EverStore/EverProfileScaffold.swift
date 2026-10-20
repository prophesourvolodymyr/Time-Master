import SwiftUI

enum EverProfileGeometry {
    static let addButtonWidth = EverLayout.minimumTouchTarget * 2 + EverSpacing.x4
    static let addButtonHeight = EverLayout.primaryButtonMinimum

    static func expandedCore(coverHeight: CGFloat, avatarSize: CGFloat) -> CGFloat {
        EverLayout.minimumTouchTarget + coverHeight + avatarSize * 1.4
    }

    struct CompactHeader {
        let avatarX: CGFloat
        let titleX: CGFloat
        let titleWidth: CGFloat
        let statX: CGFloat
        let addX: CGFloat
        let firstAccessoryX: CGFloat
        let accessoryCount: Int

        func accessoryX(_ index: Int) -> CGFloat {
            firstAccessoryX + CGFloat(index) * (EverLayout.minimumTouchTarget + EverSpacing.x1)
        }
    }

    static func compactHeader(
        width: CGFloat,
        avatarSize: CGFloat,
        statWidth: CGFloat,
        addWidth: CGFloat,
        accessoryCount: Int
    ) -> CompactHeader {
        let control = EverLayout.minimumTouchTarget
        let inset = EverSpacing.x2
        let gap = EverSpacing.x1
        let avatarX = inset + control + gap + avatarSize / 2
        let titleStart = avatarX + avatarSize / 2 + gap
        let statisticsWidth = statWidth > 0 ? statWidth + gap : 0
        let titleEnd = width - inset - addWidth - gap - statisticsWidth
        let minimumTitleWidth = EverLayout.standardRowMinimum + EverSpacing.x6
        let available = max(0, titleEnd - titleStart - minimumTitleWidth)
        let visibleAccessories = min(accessoryCount, Int(available / (control + gap)))
        let accessoryWidth = CGFloat(visibleAccessories) * (control + gap)
        let addX = width - inset - accessoryWidth - addWidth / 2
        let end = titleEnd - accessoryWidth
        return CompactHeader(
            avatarX: avatarX,
            titleX: (titleStart + end) / 2,
            titleWidth: max(1, end - titleStart),
            statX: addX - addWidth / 2 - gap - statWidth / 2,
            addX: addX,
            firstAccessoryX: addX + addWidth / 2 + gap + control / 2,
            accessoryCount: visibleAccessories
        )
    }
}

struct EverProfileCoverMotion: ViewModifier {
    let width: CGFloat
    let coverHeight: CGFloat
    let compactHeight: CGFloat
    let progress: CGFloat
    var background: Color = EverColor.background
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let height = coverHeight + (compactHeight - coverHeight) * progress
        content
            .frame(width: width, height: coverHeight)
            .scaleEffect(max(1, height / max(1, coverHeight)) + (reduceMotion ? 0 : progress * 0.12), anchor: .top)
            .offset(y: reduceMotion ? 0 : -coverHeight * progress * 0.12)
            .blur(radius: EverSpacing.x2 * progress, opaque: true)
            .overlay(background.opacity(0.36 * progress))
            .frame(width: width, height: height, alignment: .top)
            .clipped()
    }
}

struct EverProfileScaffold<Chrome: View, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var coordinateSpace
    let compactHeight: CGFloat
    let expandedHeaderHeight: (CGFloat) -> CGFloat
    let tabHeight: CGFloat
    let rasterizesContent: Bool
    let chrome: (CGFloat, CGFloat) -> Chrome
    let content: Content
    @State private var scrollOffset: CGFloat = 0

    init(
        compactHeight: CGFloat,
        expandedHeaderHeight: @escaping (CGFloat) -> CGFloat,
        tabHeight: CGFloat,
        rasterizesContent: Bool = true,
        @ViewBuilder chrome: @escaping (CGFloat, CGFloat) -> Chrome,
        @ViewBuilder content: () -> Content
    ) {
        self.compactHeight = compactHeight
        self.expandedHeaderHeight = expandedHeaderHeight
        self.tabHeight = tabHeight
        self.rasterizesContent = rasterizesContent
        self.chrome = chrome
        self.content = content()
    }

    var body: some View {
        GeometryReader { viewport in
            let expandedHeight = max(compactHeight, expandedHeaderHeight(viewport.size.width))
            let collapseDistance = max(1, expandedHeight - compactHeight)
            let rawProgress = min(1, max(0, -scrollOffset / collapseDistance))
            let progress = reduceMotion ? (rawProgress >= 0.5 ? 1 : 0) : rawProgress
            let chromeHeight = interpolate(expandedHeight + tabHeight, compactHeight + tabHeight, progress)

            ScrollView {
                let scrolling = VStack(spacing: 0) {
                    Color.clear
                        .frame(height: expandedHeight + tabHeight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    content
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(0, viewport.size.height - compactHeight - tabHeight), alignment: .top)
                }
                .frame(maxWidth: .infinity)
                .background {
                    if #unavailable(iOS 18.0, macOS 15.0) {
                        GeometryReader { content in
                            Color.clear.preference(
                                key: EverProfileScrollOffsetKey.self,
                                value: content.frame(in: .named(coordinateSpace)).minY
                            )
                        }
                    }
                }
                Group {
                    if rasterizesContent {
                        scrolling.modifier(EverScrollSmear())
                    } else {
                        scrolling
                    }
                }
                .modifier(EverArcScrollableContent())
                .overlay(alignment: .top) {
                    chrome(viewport.size.width, progress)
                        .frame(height: chromeHeight, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .background(EverColor.background)
                        .offset(y: -scrollOffset)
                }
            }
            .modifier(EverVerticalScrollOffset(offset: $scrollOffset))
            .modifier(EverScrollMotion())
            .modifier(EverArcScrollOverflow())
            .coordinateSpace(name: coordinateSpace)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("profile-scroll")
            .onPreferenceChange(EverProfileScrollOffsetKey.self) { value in
                if #unavailable(iOS 18.0, macOS 15.0) { scrollOffset = value }
            }
        }
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

private struct EverProfileScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
