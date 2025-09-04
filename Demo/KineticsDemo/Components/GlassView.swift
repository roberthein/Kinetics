import SwiftUI
import UIKit

struct GlassView: UIViewRepresentable {
    var blurIntensity: CGFloat
    let style: UIBlurEffect.Style = .systemUltraThinMaterial

    func makeUIView(context: Context) -> GlassUIView {
        GlassUIView(style: style)
    }

    func updateUIView(_ uiView: GlassUIView, context: Context) {
        uiView.setFraction(blurIntensity)

        DispatchQueue.main.async {
            if let backdropLayer = uiView.layer.sublayers?.first {
                backdropLayer.filters?.removeAll {
                    String(describing: $0) != "gaussianBlur"
                }
            }
        }
    }
}

final class GlassUIView: UIVisualEffectView {
    private let animator: UIViewPropertyAnimator

    init(style: UIBlurEffect.Style) {
        let blurEffect = UIBlurEffect(style: style)
        self.animator = UIViewPropertyAnimator(duration: 1, curve: .linear)

        super.init(effect: nil)

        animator.addAnimations { [weak self] in
            self?.effect = blurEffect
        }

        animator.pausesOnCompletion = true
        animator.fractionComplete = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setFraction(_ value: CGFloat) {
        animator.fractionComplete = max(0, min(1, value))
    }

    func stopAnimation() {
        animator.stopAnimation(true)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            stopAnimation()
        }
    }
}
