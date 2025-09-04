import SwiftUI
import CoreGraphics
import Kinetics

public struct RetargetingDemo: View {
    @Environment(\.displayScale) private var displayScale
    @StateObject private var anim = SpringAnimator<CGPoint>(
        initialValue: .zero,
        spring: .snappy,
        boundary: .none
    )

    private static let bounds: ClosedRange<Double> = -160 ... 160
    private static let dimension: Double = bounds.upperBound - bounds.lowerBound

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: AppStyling.cornerRadiusLarge, style: .continuous)
                    .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))
                    .frame(width: Self.dimension, height: Self.dimension)

                Circle()
                    .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))
                    .frame(width: 40, height: 40)
                    .offset(x: anim.targetValue.x, y: anim.targetValue.y)

                Circle()
                    .fill(AppStyling.greenGradient)
                    .frame(width: AppStyling.ballDiameter, height: AppStyling.ballDiameter)
                    .offset(x: anim.currentValue.x, y: anim.currentValue.y)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let p = centered(g.location, in: size)
                        let clamped = clamp(p, x: Self.bounds, y: Self.bounds)
                        anim.targetValue = clamped
                        Task { await anim.start() }
                    }
                    .onEnded { g in
                        let end = g.location
                        let p = centered(end, in: size)
                        let clamped = clamp(p, x: Self.bounds, y: Self.bounds)
                        Task { await anim.animate(to: clamped) }
                    }
            )
        }
        .overlay(alignment: .bottomLeading) {
            AnimationIndicator(state: Binding(get: { anim.state }, set: { _ in }))
        }
        .sensoryFeedback(.selection, trigger: anim.state.isAnimating)
        .bindSpring(to: anim)
    }
}

public struct RubberBandingDemo: View {
    @Environment(\.displayScale) private var displayScale
    @State private var dragState = KineticsDragState()
    @State private var dragAnchor: CGPoint = .zero

    @StateObject private var anim = SpringAnimator<CGPoint>(
        initialValue: .zero,
        spring: .bouncy,
        boundary: .none
    )

    private static let bounds: ClosedRange<Double> = -100 ... 100
    private static let dimension: Double = bounds.upperBound - bounds.lowerBound

    private static func rubberBandX() -> RubberBandConfig {
        .init(
            constant: 0.55,
            dimension: dimension,
            mode: .outside(bounds: bounds, freeOvershoot: 0),
            curve: .rational
        )
    }
    private static func rubberBandY() -> RubberBandConfig {
        .init(
            constant: 0.55,
            dimension: dimension,
            mode: .outside(bounds: bounds, freeOvershoot: 0),
            curve: .rational
        )
    }

    private let velocityScale: CGFloat = 0.5
    private let projectionConfig = ProjectionConfig(maxDistance: dimension)

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppStyling.cornerRadiusLarge, style: .continuous)
                .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))
                .frame(width: Self.dimension, height: Self.dimension)

            Circle()
                .fill(AppStyling.greenGradient)
                .frame(width: AppStyling.ballDiameter, height: AppStyling.ballDiameter)
                .offset(x: anim.currentValue.x, y: anim.currentValue.y)
                .kineticsDragGesture(state: $dragState, velocityScale: velocityScale)
                .onChange(of: dragState.isActive) { _, active in
                    if active {
                        dragAnchor = anim.currentValue
                    } else {
                        let current = anim.currentValue
                        let delta = CGPoint(
                            x: dragState.projectedTranslation.x - dragState.translation.x,
                            y: dragState.projectedTranslation.y - dragState.translation.y
                        )
                        let proposed = Projection.projectValue(current: current, predictedDelta: delta, cfg: projectionConfig)
                        let target = RubberBandCommit.releaseTarget(raw: proposed, perComponent: [0: Self.rubberBandX(), 1: Self.rubberBandY()])
                        Task { await anim.animate(to: target, velocity: dragState.velocity / velocityScale) }
                    }
                }
                .onChange(of: dragState) { _, s in
                    guard s.isActive else { return }
                    let rawX = dragAnchor.x + s.translation.x
                    let rawY = dragAnchor.y + s.translation.y
                    let mappedX = RubberBand.map(rawX, cfg: Self.rubberBandX())
                    let mappedY = RubberBand.map(rawY, cfg: Self.rubberBandY())
                    anim.setValue(CGPoint(x: mappedX, y: mappedY))
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            AnimationIndicator(state: Binding(
                get: { anim.state },
                set: { _ in }))
        }
        .sensoryFeedback(.selection, trigger: anim.state.isAnimating)
        .bindSpring(to: anim)
    }
}

public struct PullToReleaseDemo: View {
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var center: KineticsSpringCenter

    @State private var dragState = KineticsDragState()
    @State private var dragAnchor: CGPoint = .zero
    @State private var isFree = false

    @StateObject private var anim = SpringAnimator<CGPoint>(
        initialValue: .zero,
        spring: .bouncy,
        boundary: .none
    )

    private let velocityScale: CGFloat = 0.25
    private let threshold: Double = 200
    private let cfg = RubberBandConfig(
        constant: 0.55,
        dimension: 200,
        mode: .inside(anchor: 0, bandUntil: 200, snapBackInside: true),
        curve: .log10Normalized
    )

    public var body: some View {
        ZStack {
            Circle()
                .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))
                .frame(width: 120, height: 120)
                .offset(x: isFree ? anim.targetValue.x : 0, y: isFree ? anim.targetValue.y : 0)
                .animation(anim.animation, value: isFree)

            Circle()
                .fill(AppStyling.greenGradient)
                .frame(width: AppStyling.ballDiameter, height: AppStyling.ballDiameter)
                .offset(x: anim.currentValue.x, y: anim.currentValue.y)
                .kineticsDragGesture(state: $dragState, velocityScale: 0.25)
                .onChange(of: dragState.isActive) { _, active in
                    if active {
                        dragAnchor = anim.currentValue
                    } else {
                        isFree = false
                        Task { await anim.animate(to: .zero) }
                    }
                }
                .onChange(of: dragState) { _, s in
                    guard s.isActive else { return }

                    let raw = CGPoint(x: dragAnchor.x + s.translation.x,
                                      y: dragAnchor.y + s.translation.y)
                    let dist = hypot(raw.x, raw.y)

                    if !isFree {
                        if dist <= threshold {
                            let mapped = raw.rubberBanded(cfg)
                            anim.setValue(mapped)
                        } else {
                            isFree = true
                            Task { await anim.animate(to: raw, velocity: s.velocity / velocityScale) }
                        }
                    } else {
                        anim.targetValue = raw
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            AnimationIndicator(state: Binding(
                get: { anim.state },
                set: { _ in }))
        }
        .sensoryFeedback(.selection, trigger: anim.state.isAnimating)
        .bindSpring(to: anim)
    }
}

public struct BounceBoundaryDemo: View {
    @Environment(\.displayScale) private var displayScale
    @State private var dragState = KineticsDragState()
    @State private var dragAnchor: CGPoint = .zero

    private static let horizontalBounds: ClosedRange<Double> = -130 ... 130
    private static let verticalBounds: ClosedRange<Double> = 0 ... 0
    private static let dimension: Double = horizontalBounds.upperBound - horizontalBounds.lowerBound

    @StateObject private var anim = SpringAnimator<Double>(
        initialValue: .zero,
        spring: .playful,
        boundary: .bounce(
            BounceBoundary(
                xr: horizontalBounds,
                yr: verticalBounds,
                restitution: 0.9999,
                friction: 0.001
            )
        )
    )

    private let velocityScale: CGFloat = 0.5
    private static let projectionConfig = ProjectionConfig(maxDistance: dimension, fallbackTime: 0.40)

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppStyling.cornerRadiusLarge, style: .continuous)
                .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))
                .frame(width: Self.dimension + AppStyling.ballDiameter + 10, height: 70)

            Circle()
                .fill(AppStyling.greenGradient)
                .frame(width: AppStyling.ballDiameter, height: AppStyling.ballDiameter)
                .offset(x: anim.currentValue, y: 0)
                .kineticsDragGesture(state: $dragState, velocityScale: 0.5)
                .onChange(of: dragState.isActive) { _, active in
                    if active {
                        dragAnchor.x = anim.currentValue
                    } else {
                        let current = anim.currentValue
                        let delta: Double = dragState.projectedTranslation.x - dragState.translation.x
                        let projected = Projection.projectValue(current: current, predictedDelta: delta, cfg: Self.projectionConfig)
                        let clamped = clamp(projected, to: Self.horizontalBounds)
                        Task { await anim.animate(to: clamped, velocity: dragState.velocity.x / velocityScale) }
                    }
                }
                .onChange(of: dragState) { _, s in
                    guard s.isActive else { return }
                    let raw = dragAnchor.x + s.translation.x
                    let clamped = clamp(raw, to: Self.horizontalBounds)
                    anim.setValue(clamped)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            AnimationIndicator(state: Binding(
                get: { anim.state },
                set: { _ in }))
        }
        .sensoryFeedback(.selection, trigger: anim.state.isAnimating)
        .bindSpring(to: anim)
    }
}

public struct SnapTargetsDemo: View {
    @Environment(\.displayScale) private var displayScale
    @State private var dragState = KineticsDragState()
    @State private var dragAnchor: CGPoint = .zero

    private static let bounds: ClosedRange<Double> = -160 ... 160
    private static let dimension: Double = bounds.upperBound - bounds.lowerBound

    @StateObject private var anim = SpringAnimator<CGPoint>(
        initialValue: .zero,
        spring: .playful,
        boundary: .bounce(
            BounceBoundary(
                xr: bounds,
                yr: bounds,
                restitution: 0.9999,
                friction: 0.001
            )
        )
    )

    private let velocityScale: CGFloat = 0.5
    private static let projCfg = ProjectionConfig(maxDistance: dimension, fallbackTime: 0.40)

    private static let targets: [CGPoint] = {
        var pts: [CGPoint] = []
        for y in [bounds.lowerBound, 0, bounds.upperBound] {
            for x in [bounds.lowerBound, 0, bounds.upperBound] {
                pts.append(CGPoint(x: x, y: y))
            }
        }
        return pts
    }()

    public var body: some View {
        ZStack {
            ForEach(0 ..< Self.targets.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: AppStyling.cornerRadiusLarge, style: .continuous)
                    .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))
                    .frame(width: 40, height: 40)
                    .offset(x: Self.targets[i].x, y: Self.targets[i].y)
            }

            Circle()
                .fill(AppStyling.greenGradient)
                .frame(width: AppStyling.ballDiameter, height: AppStyling.ballDiameter)
                .offset(x: anim.currentValue.x, y: anim.currentValue.y)
                .kineticsDragGesture(state: $dragState, velocityScale: 0.5)
                .onChange(of: dragState.isActive) { _, active in
                    if active {
                        dragAnchor = anim.currentValue
                    } else {
                        let current = anim.currentValue
                        let delta = CGPoint(
                            x: dragState.projectedTranslation.x - dragState.translation.x,
                            y: dragState.projectedTranslation.y - dragState.translation.y
                        )
                        let proposed = Projection.projectValue(current: current, predictedDelta: delta, cfg: Self.projCfg)
                        let snapped = snapToClosest(proposed, among: Self.targets)
                        Task { await anim.animate(to: snapped, velocity: dragState.velocity / velocityScale) }
                    }
                }
                .onChange(of: dragState) { _, s in
                    guard s.isActive else { return }
                    let raw = CGPoint(x: dragAnchor.x + s.translation.x, y: dragAnchor.y + s.translation.y)
                    let clamped = clamp(raw, x: Self.bounds, y: Self.bounds)
                    anim.setValue(clamped)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            AnimationIndicator(state: Binding(
                get: { anim.state },
                set: { _ in }))
        }
        .sensoryFeedback(.selection, trigger: anim.state.isAnimating)
        .bindSpring(to: anim)
    }

    private func snapToClosest(_ proposed: CGPoint, among targets: [CGPoint]) -> CGPoint {
        guard var best = targets.first else { return proposed }
        var bestDist = hypot(proposed.x - best.x, proposed.y - best.y)
        for t in targets.dropFirst() {
            let d = hypot(proposed.x - t.x, proposed.y - t.y)
            if d < bestDist { bestDist = d; best = t }
        }
        return best
    }
}

public struct RotationProjectionDemo: View {
    @Environment(\.displayScale) private var displayScale
    @State private var rotState = KineticsRotationState()
    @State private var anchorAngle: Double = 0

    @StateObject private var anim = SpringAnimator<Double>(
        initialValue: 0,
        spring: .playful,
        boundary: .none
    )

    private let velocityScale: CGFloat = 0.5
    private let projectionFallbackTime: Double = 0.40

    public var body: some View {
        ZStack {
            ZStack {
                Circle()
                    .stroke(AppStyling.strokeColor, style: AppStyling.strokeStyle(for: displayScale))

                Circle()
                    .fill(AppStyling.greenGradient)
                    .frame(width: AppStyling.ballDiameter, height: AppStyling.ballDiameter)
                    .offset(y: -100)
                    .rotationEffect(.radians(anim.currentValue))
            }
            .frame(width: 200, height: 200)
            .contentShape(Circle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kineticsRotationGesture(state: $rotState, velocityScale: 0.5, projectionFallbackTime: 0.40)
        .onChange(of: rotState.isActive) { _, active in
            if active {
                anchorAngle = anim.currentValue
            } else {
                let target = anchorAngle + rotState.projectedRotation
                Task { await anim.animate(to: target, velocity: rotState.angularVelocity / velocityScale) }
            }
        }
        .onChange(of: rotState) { _, s in
            guard s.isActive else { return }
            anim.setValue(anchorAngle + s.rotation, velocity: s.angularVelocity)
        }
        .overlay(alignment: .bottomLeading) {
            AnimationIndicator(state: Binding(get: { anim.state }, set: { _ in }))
        }
        .sensoryFeedback(.selection, trigger: anim.state.isAnimating)
        .bindSpring(to: anim)
    }
}

@inline(__always)
private func centered(_ p: CGPoint, in size: CGSize) -> CGPoint {
    CGPoint(x: Double(p.x - size.width  * 0.5),
            y: Double(p.y - size.height * 0.5))
}

@inline(__always)
private func clamp(_ v: Double, to r: ClosedRange<Double>) -> Double {
    min(max(v, r.lowerBound), r.upperBound)
}

@inline(__always)
private func clamp(_ p: CGPoint, x: ClosedRange<Double>, y: ClosedRange<Double>) -> CGPoint {
    CGPoint(x: clamp(p.x, to: x), y: clamp(p.y, to: y))
}

private extension CGPoint {
    static func / (lhs: CGPoint, rhs: Double) -> CGPoint {
        return CGPoint(x: lhs.x / CGFloat(rhs), y: lhs.y / CGFloat(rhs))
    }
}

