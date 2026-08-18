import SwiftUI

struct SlotNavigationBar: View {
    @Binding private var selection: Int
    let items: [SlotNavigationItem]
    let onSelectionChanged: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reelOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragIntensity: CGFloat = 0
    @State private var isDragging = false
    @State private var hasMeasured = false

    init(
        selection: Binding<Int>,
        items: [SlotNavigationItem] = SlotNavigationItem.timeMaster,
        onSelectionChanged: @escaping (Int) -> Void = { _ in }
    ) {
        _selection = selection
        self.items = items
        self.onSelectionChanged = onSelectionChanged
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
            let baseHeight = 58 + dragIntensity * 36
            let arcTranslation = displayOffset * 0.5

            ZStack {
                Rectangle()
                    .fill(Theme.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: baseHeight)
                    .ignoresSafeArea(edges: .bottom)
                ZStack {
                    SlotNavigationArcShape()
                        .fill(Theme.surface)
                    SlotNavigationArcLineShape()
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
                .scaleEffect(x: arcScaleX, y: arcScaleY, anchor: .bottom)
                .offset(x: arcTranslation)
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
            .frame(width: size.width, height: size.height)
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
        .frame(height: 126)
        .accessibilityElement(children: .contain)
    }

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
        let norm = distance / slotWidth
        let bubbleFactor = max(0, 1 - distance / 34)
        let labelAlpha = max(0, bubbleFactor * 2 - 0.6)
        let baseScale = 1 + dragIntensity * 0.2
        let itemScale = max(0.4, baseScale - norm * (0.25 + dragIntensity * 0.1))
        let itemOpacity = max(0.1, 1 - norm * (0.4 + dragIntensity * 0.15))
        let activeFontSize = 56 + dragIntensity * 24
        let baseFontSize = 48 + dragIntensity * 10
        let iconSize = baseFontSize + bubbleFactor * (activeFontSize - baseFontSize)
        let htmlBaseTy = -38 - dragIntensity * 40
        let restingBaseTy: CGFloat = -38
        let verticalOffset = max(
            htmlBaseTy,
            htmlBaseTy + norm * (20 + dragIntensity * 14)
        ) - restingBaseTy
        let arcY = transformedArcY(at: itemX, in: arcRect, translation: offset * 0.5)
        let itemHeight: CGFloat = 110
        let itemLift: CGFloat = 56

        VStack(spacing: 3 * labelAlpha) {
            Text(item.emoji)
                .font(.system(size: iconSize))
                .frame(height: iconSize)
                .accessibilityHidden(true)

            Text(item.title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 13 * labelAlpha)
                .opacity(labelAlpha)
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
        .zIndex(1 - min(norm, 10))
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
        return .interpolatingSpring(stiffness: 420, damping: 25)
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
                stiffness: 420,
                damping: 25,
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

    private func transformedArcY(
        at x: CGFloat,
        in rect: CGRect,
        translation: CGFloat
    ) -> CGFloat {
        let scaleX = 1 + dragIntensity * 0.15
        let scaleY = 1 + dragIntensity * 0.35
        let centerX = rect.midX
        let arcSampleX = centerX + (x - translation - centerX) / scaleX
        let unscaledY = SlotNavigationArcGeometry.curveY(at: arcSampleX, in: rect)
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
