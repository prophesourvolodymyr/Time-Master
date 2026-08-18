import SwiftUI

#if os(iOS)
import UIKit
import LiquidGlassKit

struct TimeMasterLiquidGlassBackground: UIViewRepresentable {
    let cornerRadius: CGFloat
    let isInteractive: Bool

    func makeUIView(context: Context) -> TimeMasterLiquidGlassHost {
        TimeMasterLiquidGlassHost(
            cornerRadius: cornerRadius,
            isInteractive: isInteractive
        )
    }

    func updateUIView(_ uiView: TimeMasterLiquidGlassHost, context: Context) {
        uiView.cornerRadius = cornerRadius
    }
}

final class TimeMasterLiquidGlassHost: UIView {
    private let effectView: UIView
    var cornerRadius: CGFloat {
        didSet {
            guard oldValue != cornerRadius else { return }
            setNeedsLayout()
        }
    }

    init(cornerRadius: CGFloat, isInteractive: Bool) {
        self.cornerRadius = cornerRadius

        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = isInteractive
            effectView = UIVisualEffectView(effect: effect)
        } else {
            let effect = LiquidGlassEffect(style: .regular, isNative: false)
            effect.isInteractive = isInteractive
            effectView = LiquidGlassEffectView(effect: effect)
        }

        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        addSubview(effectView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        effectView.frame = bounds
        effectView.layer.cornerRadius = cornerRadius
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
    }
}
#endif

struct TimeMasterPrivateGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let isInteractive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        if reduceTransparency {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.surface2)
                }
        } else {
            content
                .background {
                    TimeMasterLiquidGlassBackground(
                        cornerRadius: cornerRadius,
                        isInteractive: isInteractive
                    )
                }
        }
#else
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
#endif
    }
}
