import SwiftUI

struct SlotNavigationBar: View {
    @Binding private var selection: Int
    let items: [SlotNavigationItem]
    let onSelectionChanged: (Int) -> Void
    private let bottomSafeArea: CGFloat
    private let barHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reelOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragIntensity: CGFloat = 0
    @State private var isDragging = false
    @State private var hasMeasured = false

    init(
        selection: Binding<Int>,
        items: [SlotNavigationItem] = SlotNavigationItem.timeMaster,
        bottomSafeArea: CGFloat = 0,
        barHeight: CGFloat = 126,
        onSelectionChanged: @escaping (Int) -> Void = { _ in }
    ) {
        _selection = selection
        self.items = items
        self.bottomSafeArea = max(0, bottomSafeArea)
        self.barHeight = max(126, barHeight)
        self.onSelectionChanged = onSelectionChanged
    }

    private var arcCurveOffset: CGFloat {
#if os(iOS)
        8
#else
        54
#endif
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotWidth = slotWidth(for: size.width)
            let arcRect = CGRect(origin: .zero, size: size)
            let centeredOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
            let displayOffset = hasMeasured ? reelOffset : centeredOffset
            let arcScaleX = 1 + dragIntensity * 0.15
            let arcScaleY = 1 + dragIntensity * 0.35

            ZStack {
                ZStack {
                    arcSurface
                }
                .scaleEffect(x: arcScaleX, y: arcScaleY, anchor: .bottom)
                .allowsHitTesting(false)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    slotView(
                        item: item,
                        index: index,
                        offset: displayOffset,
                        size: size,
                        arcRect: arcRect,
                        slotWidth: slotWidth
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size, slotWidth: slotWidth, fallbackOffset: centeredOffset))
            .onAppear {
                if !hasMeasured {
                    reelOffset = centeredOffset
                    hasMeasured = true
                }
            }
            .onChange(of: size.width) { _ in
                let nextOffset = offset(for: selection, viewportWidth: size.width, slotWidth: slotWidth)
                if isDragging {
                    reelOffset = nextOffset
                } else if abs(reelOffset - nextOffset) > 0.5 {
                    withAnimation(selectionAnimation) {
                        reelOffset = nextOffset
                    }
                }
            }
            .onChange(of: selection) { newSelection in
                guard !isDragging else { return }
                let nextOffset = offset(for: newSelection, viewportWidth: size.width, slotWidth: slotWidth)
                guard abs(reelOffset - nextOffset) > 0.5 else { return }
                withAnimation(selectionAnimation) {
                    reelOffset = nextOffset
                }
            }
        }
        .frame(height: barHeight)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var arcSurface: some View {
#if os(iOS)
        let shape = SlotNavigationArcShape(
            bottomExtension: bottomSafeArea,
            curveOffset: arcCurveOffset
        )
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
                .overlay {
                    iOSArcStyling(shape: shape)
                }
                .shadow(color: Color.black.opacity(0.38), radius: 14, y: -2)
        } else {
            shape
                .fill(.regularMaterial)
                .overlay {
                    iOSArcStyling(shape: shape)
                }
                .shadow(color: Color.black.opacity(0.38), radius: 14, y: -2)
        }
#else
        if #available(macOS 26.0, *) {
            let shape = SlotNavigationArcShape(
                bottomExtension: bottomSafeArea,
                curveOffset: arcCurveOffset
            )
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
                .overlay {
                    macArcStyling(shape: shape)
                }
        } else {
            let shape = SlotNavigationArcShape(
                bottomExtension: bottomSafeArea,
                curveOffset: arcCurveOffset
            )
            shape
                .fill(.regularMaterial)
                .overlay {
                    macArcStyling(shape: shape)
                }
        }
#endif
    }

    @ViewBuilder
    private func iOSArcStyling(shape: SlotNavigationArcShape) -> some View {
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.025),
                        Color.black.opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            shape.fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.025),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 240
                )
            )
            SlotNavigationArcLineShape(curveOffset: arcCurveOffset)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.07),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.25
                )
        }
    }

#if os(macOS)
    @ViewBuilder
    private func macArcStyling(shape: SlotNavigationArcShape) -> some View {
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.015),
                        Color.black.opacity(0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            shape.fill(Color.black.opacity(0.10))
            SlotNavigationArcLineShape(curveOffset: arcCurveOffset)
                .stroke(Color.white.opacity(0.10), lineWidth: 1.15)
            SlotNavigationArcInnerLineShape(curveOffset: arcCurveOffset)
                .stroke(Color.white.opacity(0.045), lineWidth: 0.8)
        }
    }
#endif


    @ViewBuilder
    private func slotView(
        item: SlotNavigationItem,
        index: Int,
        offset: CGFloat,
        size: CGSize,
        arcRect: CGRect,
        slotWidth: CGFloat
    ) -> some View {
        let centerX = size.width / 2
        let itemX = offset + CGFloat(index) * slotWidth + slotWidth / 2
        let distance = abs(itemX - centerX)
        let focus = max(0, 1 - min(distance / (slotWidth * 0.9), 1))
        let proximity = max(0, 1 - min(distance / (slotWidth * 2.3), 1))
        let norm = distance / slotWidth
        let bubbleFactor = max(0, 1 - distance / 34)
        let baseIconSize = 42 + 20 * focus
        let expandedIconSize = 50 + bubbleFactor * 34
        let iconSize = baseIconSize + dragIntensity * (expandedIconSize - baseIconSize)
        let baseScale = 0.88 + 0.18 * focus
        let expandedScale = max(0.4, 1.2 - norm * 0.35)
        let itemScale = baseScale + dragIntensity * (expandedScale - baseScale)
        let baseOpacity = 0.28 + 0.72 * proximity
        let expandedOpacity = max(0.1, 1 - norm * 0.55)
        let itemOpacity = baseOpacity + dragIntensity * (expandedOpacity - baseOpacity)
        let baseLabelOpacity = focus * focus
        let expandedLabelOpacity = max(0, bubbleFactor * 2 - 0.6)
        let labelOpacity = baseLabelOpacity + dragIntensity * (expandedLabelOpacity - baseLabelOpacity)
        let htmlExpansionOffset = max(
            -78,
            -78 + norm * 34
        ) + 38
        let verticalOffset = dragIntensity * htmlExpansionOffset
        let arcY = transformedArcY(at: itemX, in: arcRect)
        let itemHeight = 90 + dragIntensity * 24
        let itemLift: CGFloat = 56
        let iconFrameHeight = 60 + dragIntensity * max(0, expandedIconSize - 60)
        let zIndex = max(
            0,
            focus + dragIntensity * (1 - min(norm, 10) - focus)
        )

        VStack(spacing: 4) {
            Text(item.emoji)
                .font(.system(size: iconSize))
                .frame(height: iconFrameHeight)
                .accessibilityHidden(true)

            Text(item.title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 15)
                .opacity(labelOpacity)
                .accessibilityHidden(true)
        }
        .frame(width: slotWidth, height: itemHeight, alignment: .bottom)
        .scaleEffect(itemScale, anchor: .bottom)
        .opacity(itemOpacity)
        .contentShape(Rectangle())
        .position(
            x: itemX,
            y: arcY + itemLift - itemHeight / 2 + verticalOffset
        )
        .zIndex(1 + zIndex)
        .onTapGesture {
            select(
                index: index,
                viewportWidth: size.width,
                slotWidth: slotWidth
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(selection == index ? "Selected" : "Not selected")
        .accessibilityHint(item.accessibilityHint)
        .accessibilityAddTraits(selection == index ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAdjustableAction { direction in
            let nextIndex: Int
            switch direction {
            case .increment:
                nextIndex = min(selection + 1, items.count - 1)
            case .decrement:
                nextIndex = max(selection - 1, 0)
            @unknown default:
                return
            }
            select(
                index: nextIndex,
                viewportWidth: size.width,
                slotWidth: slotWidth
            )
        }
    }

    private var selectionAnimation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.16)
        }
        return .interpolatingSpring(stiffness: 260, damping: 28)
    }

    private var dragExpansionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.18)
    }

    private var dragWindDownAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.24)
    }

    private func dragGesture(
        size: CGSize,
        slotWidth: CGFloat,
        fallbackOffset: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartOffset = hasMeasured ? reelOffset : fallbackOffset
                    withAnimation(dragExpansionAnimation) {
                        dragIntensity = reduceMotion ? 0 : 1
                    }
                }

                let rawOffset = dragStartOffset + value.translation.width
                let boundedOffset = rubberBand(
                    rawOffset,
                    minimum: minimumOffset(viewportWidth: size.width, slotWidth: slotWidth),
                    maximum: maximumOffset(viewportWidth: size.width, slotWidth: slotWidth)
                )

                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    reelOffset = boundedOffset
                }
            }
            .onEnded { value in
                let projectedOffset = dragStartOffset + value.predictedEndTranslation.width
                let targetIndex = index(
                    for: projectedOffset,
                    viewportWidth: size.width,
                    slotWidth: slotWidth
                )
                isDragging = false
                withAnimation(dragWindDownAnimation) {
                    dragIntensity = 0
                }
                settle(
                    on: targetIndex,
                    viewportWidth: size.width,
                    slotWidth: slotWidth,
                    projectedTranslation: value.predictedEndTranslation.width - value.translation.width
                )
            }
    }

    private func select(index: Int, viewportWidth: CGFloat, slotWidth: CGFloat) {
        guard items.indices.contains(index) else { return }
        settle(
            on: index,
            viewportWidth: viewportWidth,
            slotWidth: slotWidth,
            projectedTranslation: 0
        )
    }

    private func settle(
        on index: Int,
        viewportWidth: CGFloat,
        slotWidth: CGFloat,
        projectedTranslation: CGFloat
    ) {
        guard items.indices.contains(index) else { return }

        let targetOffset = offset(for: index, viewportWidth: viewportWidth, slotWidth: slotWidth)
        let currentOffset = hasMeasured ? reelOffset : targetOffset
        let remainingDistance = max(abs(targetOffset - currentOffset), 1)
        let normalizedVelocity = projectedTranslation / remainingDistance
        let animation: Animation
        if reduceMotion {
            animation = .easeOut(duration: 0.16)
        } else {
            animation = .interpolatingSpring(
                stiffness: 260,
                damping: 28,
                initialVelocity: Double(normalizedVelocity)
            )
        }

        onSelectionChanged(index)
        withAnimation(animation) {
            reelOffset = targetOffset
            selection = index
            hasMeasured = true
        }
    }

    private func transformedArcY(at x: CGFloat, in rect: CGRect) -> CGFloat {
        let scaleX = 1 + dragIntensity * 0.15
        let scaleY = 1 + dragIntensity * 0.35
        let centerX = rect.midX
        let arcSampleX = centerX + (x - centerX) / scaleX
        let unscaledY = SlotNavigationArcGeometry.curveY(
            at: arcSampleX,
            in: rect,
            curveOffset: arcCurveOffset
        )
        return rect.maxY - (rect.maxY - unscaledY) * scaleY
    }

    private func slotWidth(for viewportWidth: CGFloat) -> CGFloat {
        min(max(viewportWidth * 0.22, 76), 92)
    }

    private func offset(for index: Int, viewportWidth: CGFloat, slotWidth: CGFloat) -> CGFloat {
        viewportWidth / 2 - (CGFloat(index) * slotWidth + slotWidth / 2)
    }

    private func minimumOffset(viewportWidth: CGFloat, slotWidth: CGFloat) -> CGFloat {
        offset(for: items.count - 1, viewportWidth: viewportWidth, slotWidth: slotWidth)
    }

    private func maximumOffset(viewportWidth: CGFloat, slotWidth: CGFloat) -> CGFloat {
        offset(for: 0, viewportWidth: viewportWidth, slotWidth: slotWidth)
    }

    private func index(
        for proposedOffset: CGFloat,
        viewportWidth: CGFloat,
        slotWidth: CGFloat
    ) -> Int {
        let boundedOffset = min(
            max(proposedOffset, minimumOffset(viewportWidth: viewportWidth, slotWidth: slotWidth)),
            maximumOffset(viewportWidth: viewportWidth, slotWidth: slotWidth)
        )
        let rawIndex = (viewportWidth / 2 - slotWidth / 2 - boundedOffset) / slotWidth
        return min(max(Int(rawIndex.rounded()), 0), items.count - 1)
    }

    private func rubberBand(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        if value < minimum {
            return minimum - (minimum - value) * 0.22
        }
        if value > maximum {
            return maximum + (value - maximum) * 0.22
        }
        return value
    }
}
