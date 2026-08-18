import SwiftUI

/// A compact, circular control for screen-level Music Library actions.
///
/// On iOS 26 and later this uses SwiftUI's native Liquid Glass surface. Older
/// systems use a material surface with an explicit edge highlight so the
/// control keeps the same hierarchy without imitating the newer API.
private enum MusicGlassMetrics {
    static let controlSize: CGFloat = 44
}

public struct MusicGlassCircleButton<Label: View>: View {

    private let accessibilityLabel: String
    private let action: () -> Void
    private let label: () -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.label = label
    }

    /// Creates a Music Library glass button using an SF Symbol.
    public init(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) where Label == Image {
        self.init(accessibilityLabel: accessibilityLabel, action: action) {
            Image(systemName: systemImage)
        }
    }

    public var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 17, weight: .semibold))
                .frame(width: MusicGlassMetrics.controlSize, height: MusicGlassMetrics.controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(MusicGlassCircleButtonStyle(reduceMotion: reduceMotion))
        .modifier(
            TimeMasterPrivateGlassSurface(
                cornerRadius: MusicGlassMetrics.controlSize / 2,
                isInteractive: true
            )
        )
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

private struct MusicGlassCircleButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if reduceMotion {
            configuration.label
                .opacity(configuration.isPressed ? 0.78 : 1)
        } else {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.93 : 1)
                .animation(
                    .spring(response: 0.22, dampingFraction: 0.88),
                    value: configuration.isPressed
                )
        }
    }
}


/// Adds a stationary fade at the visible edges of scrollable content.
///
/// Apply this to the `ScrollView`, rather than its content, so the mask stays
/// attached to the viewport while rows or source cards move beneath it:
///
///     ScrollView(.horizontal) { ... }
///         .scrollEdgeFade(.horizontal)
public struct MusicScrollEdgeFade: ViewModifier {
    public let axis: Axis.Set
    public var fadeLength: CGFloat

    public init(axis: Axis.Set, fadeLength: CGFloat = 15) {
        self.axis = axis
        self.fadeLength = max(fadeLength, 0)
    }

    public func body(content: Content) -> some View {
        content.mask {
            GeometryReader { proxy in
                MusicScrollEdgeFadeMask(
                    axis: axis,
                    fadeLength: fadeLength,
                    size: proxy.size
                )
            }
        }
    }
}

private struct MusicScrollEdgeFadeMask: View {
    let axis: Axis.Set
    let fadeLength: CGFloat
    let size: CGSize

    var body: some View {
        let hasHorizontal = axis.contains(.horizontal)
        let hasVertical = axis.contains(.vertical)

        if hasHorizontal && hasVertical {
            // A two-axis ScrollView needs both masks. Multiplying the two
            // gradients keeps corners soft without adding an opaque overlay.
            Rectangle()
                .fill(.black)
                .mask {
                    horizontalMask
                }
                .mask {
                    verticalMask
                }
        } else if hasHorizontal {
            horizontalMask
        } else if hasVertical {
            verticalMask
        } else {
            Rectangle().fill(.black)
        }
    }

    private var horizontalMask: some View {
        let length = min(fadeLength, max(size.width / 2, 0))
        let edge = size.width > 0 ? length / size.width : 0

        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: edge),
                .init(color: .black, location: max(1 - edge, edge)),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var verticalMask: some View {
        let length = min(fadeLength, max(size.height / 2, 0))
        let edge = size.height > 0 ? length / size.height : 0

        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: edge),
                .init(color: .black, location: max(1 - edge, edge)),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

public extension View {
    /// Fades a scroll viewport at both ends of the requested axis.
    func scrollEdgeFade(_ axis: Axis.Set, fadeLength: CGFloat = 15) -> some View {
        modifier(MusicScrollEdgeFade(axis: axis, fadeLength: fadeLength))
    }
}
