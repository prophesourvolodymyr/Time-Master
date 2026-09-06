import SwiftUI

#if os(iOS)
import UIKit
import Metal
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
        } else if MTLCreateSystemDefaultDevice() == nil {
            let fallbackBlur = UIVisualEffectView(
                effect: UIBlurEffect(style: .systemMaterialDark)
            )
            fallbackBlur.backgroundColor = UIColor(
                red: 1,
                green: 0.478,
                blue: 0,
                alpha: 0.52
            )
            effectView = fallbackBlur
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
    let tint: Color
    let tintOpacity: Double

    init(
        cornerRadius: CGFloat,
        isInteractive: Bool,
        tint: Color = .orange,
        tintOpacity: Double = 0.4
    ) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.tint = tint
        self.tintOpacity = tintOpacity
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.9))
                } else {
                    TimeMasterLiquidGlassBackground(
                        cornerRadius: cornerRadius,
                        isInteractive: isInteractive
                    )
                }
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(tintOpacity))
            }
#else
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(reduceTransparency ? 0.9 : tintOpacity))
            }
#endif
    }
}
