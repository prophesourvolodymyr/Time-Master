import CoreGraphics

enum WorkoutWidgetPlacement {
    static func origin(container: CGSize, widget: CGSize, anchor: CGPoint, translation: CGSize = .zero) -> CGPoint {
        let width = max(0, container.width - widget.width)
        let height = max(0, container.height - widget.height)
        return CGPoint(
            x: min(width, max(0, anchor.x * width + translation.width)),
            y: min(height, max(0, anchor.y * height + translation.height))
        )
    }

    static func movedAnchor(_ anchor: CGPoint, by translation: CGSize, container: CGSize, widget: CGSize) -> CGPoint {
        let position = origin(container: container, widget: widget, anchor: anchor, translation: translation)
        let width = max(0, container.width - widget.width)
        let height = max(0, container.height - widget.height)
        return CGPoint(
            x: width > 0 ? position.x / width : anchor.x,
            y: height > 0 ? position.y / height : anchor.y
        )
    }
}
