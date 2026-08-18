import SwiftUI

struct SlotNavigationBar: View {
    @Binding private var selection: Int
    let items: [SlotNavigationItem]
    let onSelectionChanged: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reelOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
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

            ZStack {
                SlotNavigationArcShape()
                    .fill(Theme.surface)
                    .overlay {
                        SlotNavigationArcLineShape()
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
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
                } else {
                    withAnimation(selectionAnimation) {
                        reelOffset = nextOffset
                    }
                }
            }
            .onChange(of: selection) { newSelection in
                guard !isDragging else { return }
                let nextOffset = offset(for: newSelection, viewportWidth: size.width, slotWidth: slotWidth)
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
        let focus = max(0, 1 - min(distance / (slotWidth * 0.9), 1))
        let proximity = max(0, 1 - min(distance / (slotWidth * 2.3), 1))
        let iconSize = 40 + 18 * focus
        let itemScale = 0.88 + 0.18 * focus
        let itemOpacity = 0.28 + 0.72 * proximity
        let labelOpacity = focus * focus
        let arcY = SlotNavigationArcGeometry.curveY(at: itemX, in: arcRect)
        let itemHeight: CGFloat = 86
        let itemLift: CGFloat = 56

        VStack(spacing: 3) {
            Text(item.emoji)
                .font(.system(size: iconSize))
                .frame(height: 58)
                .accessibilityHidden(true)

            Text(item.title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 14)
                .opacity(labelOpacity)
                .accessibilityHidden(true)
        }
        .frame(width: slotWidth, height: itemHeight, alignment: .bottom)
        .scaleEffect(itemScale, anchor: .bottom)
        .opacity(itemOpacity)
        .contentShape(Rectangle())
        .position(
            x: itemX,
            y: arcY + itemLift - itemHeight / 2
        )
        .zIndex(focus)
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
