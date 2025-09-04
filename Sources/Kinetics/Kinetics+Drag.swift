import SwiftUI
import CoreGraphics

// MARK: - Public State Model

/// Comprehensive state for drag gesture interactions.
/// Tracks current position, predicted end position, velocity, and active status.
public struct KineticsDragState: Equatable {
    /// Current translation from gesture start point
    public var translation: CGPoint = .zero
    /// Predicted final translation including momentum/fling
    public var projectedTranslation: CGPoint = .zero
    /// Current velocity vector in points per second
    public var velocity: CGPoint = .zero
    /// Whether the drag gesture is currently active
    public var isActive: Bool = false

    public init() {}
    public init(
        translation: CGPoint,
        projectedTranslation: CGPoint,
        velocity: CGPoint,
        isActive: Bool
    ) {
        self.translation = translation
        self.projectedTranslation = projectedTranslation
        self.velocity = velocity
        self.isActive = isActive
    }
}

// MARK: - Helper Functions

/// Scales only the projected "fling" component beyond the current finger position.
/// This preserves the current finger position while scaling the momentum prediction.
@inline(__always)
private func scaleProjected(_ predicted: CGSize, around translation: CGSize, by s: CGFloat) -> CGSize {
    // Only scale the fling "excess" beyond the current finger position
    CGSize(
        width: translation.width + (predicted.width - translation.width) * s,
        height: translation.height + (predicted.height - translation.height) * s
    )
}

// MARK: - Single State Binding Modifier (Recommended)

/// View modifier that provides drag gesture handling with a single state binding.
/// Recommended approach for most use cases due to simplicity.
public struct KineticsDragGestureStateModifier: ViewModifier {
    @Binding private var state: KineticsDragState
    private let minimumDistance: CGFloat
    private let velocityScale: CGFloat

    @GestureState private var _activeTick: Bool = false
    @State private var lastSample: (time: TimeInterval, translation: CGSize)?

    public init(
        state: Binding<KineticsDragState>,
        minimumDistance: CGFloat = 0,
        velocityScale: CGFloat = 0.25
    ) {
        self._state = state
        self.minimumDistance = minimumDistance
        self.velocityScale = velocityScale
    }

    public func body(content: Content) -> some View {
        let drag = DragGesture(minimumDistance: minimumDistance)
            .updating($_activeTick) { value, tick, _ in
                tick = true

                let now = value.time.timeIntervalSinceReferenceDate
                let tr = value.translation

                // Calculate velocity from position change over time
                var vel = CGPoint.zero
                if let last = lastSample {
                    let dt = max(now - last.time, 0.000_001)
                    let vx = (tr.width - last.translation.width) / dt
                    let vy = (tr.height - last.translation.height) / dt
                    vel = CGPoint(x: vx * velocityScale, y: vy * velocityScale)
                }

                // Scale the projected end position to match velocity feel
                let scaledPred = scaleProjected(value.predictedEndTranslation, around: tr, by: velocityScale)

                state.translation = CGPoint(x: tr.width, y: tr.height)
                state.projectedTranslation = CGPoint(x: scaledPred.width, y: scaledPred.height)
                state.velocity = vel
                state.isActive = true

                lastSample = (now, tr)
            }
            .onEnded { value in
                let now = value.time.timeIntervalSinceReferenceDate
                let tr = value.translation

                // Calculate final velocity for momentum calculations
                let finalVelocity: CGPoint = {
                    if let last = lastSample {
                        let dt = max(now - last.time, 0.000_001)
                        let vx = (tr.width - last.translation.width) / dt
                        let vy = (tr.height - last.translation.height) / dt
                        return CGPoint(x: vx * velocityScale, y: vy * velocityScale)
                    } else {
                        return .zero
                    }
                }()

                // Apply the same scaling to the final projected value
                let scaledPred = scaleProjected(value.predictedEndTranslation, around: tr, by: velocityScale)

                lastSample = nil

                state.translation = CGPoint(x: tr.width, y: tr.height)
                state.projectedTranslation = CGPoint(x: scaledPred.width, y: scaledPred.height)
                state.velocity = finalVelocity
                state.isActive = false
            }

        return content.gesture(drag)
    }
}

// MARK: - Granular Bindings Variant

/// View modifier that provides drag gesture handling with separate bindings.
/// Useful when you need fine-grained control over individual state components.
public struct KineticsDragGestureBindingsModifier: ViewModifier {
    @Binding private var translation: CGPoint
    @Binding private var projectedTranslation: CGPoint
    @Binding private var velocity: CGPoint
    @Binding private var isActive: Bool

    private let minimumDistance: CGFloat
    private let velocityScale: CGFloat

    @GestureState private var _activeTick: Bool = false
    @State private var lastSample: (time: TimeInterval, translation: CGSize)?

    public init(
        translation: Binding<CGPoint>,
        projectedTranslation: Binding<CGPoint>,
        velocity: Binding<CGPoint>,
        isActive: Binding<Bool>,
        minimumDistance: CGFloat = 0,
        velocityScale: CGFloat = 0.25
    ) {
        self._translation = translation
        self._projectedTranslation = projectedTranslation
        self._velocity = velocity
        self._isActive = isActive
        self.minimumDistance = minimumDistance
        self.velocityScale = velocityScale
    }

    public func body(content: Content) -> some View {
        let drag = DragGesture(minimumDistance: minimumDistance)
            .updating($_activeTick) { value, tick, _ in
                tick = true

                let now = value.time.timeIntervalSinceReferenceDate
                let tr = value.translation

                // Calculate velocity from position change over time
                var vel = CGPoint.zero
                if let last = lastSample {
                    let dt = max(now - last.time, 0.000_001)
                    let vx = (tr.width - last.translation.width) / dt
                    let vy = (tr.height - last.translation.height) / dt
                    vel = CGPoint(x: vx * velocityScale, y: vy * velocityScale)
                }

                // Scale the projected end position to match velocity feel
                let scaledPred = scaleProjected(value.predictedEndTranslation, around: tr, by: velocityScale)

                translation = CGPoint(x: tr.width, y: tr.height)
                projectedTranslation = CGPoint(x: scaledPred.width, y: scaledPred.height)
                velocity = vel
                isActive = true

                lastSample = (now, tr)
            }
            .onEnded { value in
                let now = value.time.timeIntervalSinceReferenceDate
                let tr = value.translation

                // Calculate final velocity for momentum calculations
                let finalVelocity: CGPoint = {
                    if let last = lastSample {
                        let dt = max(now - last.time, 0.000_001)
                        let vx = (tr.width - last.translation.width) / dt
                        let vy = (tr.height - last.translation.height) / dt
                        return CGPoint(x: vx * velocityScale, y: vy * velocityScale)
                    } else {
                        return .zero
                    }
                }()

                // Apply the same scaling to the final projected value
                let scaledPred = scaleProjected(value.predictedEndTranslation, around: tr, by: velocityScale)

                lastSample = nil

                translation = CGPoint(x: tr.width, y: tr.height)
                projectedTranslation = CGPoint(x: scaledPred.width, y: scaledPred.height)
                velocity = finalVelocity
                isActive = false
            }

        return content.gesture(drag)
    }
}

// MARK: - View Extensions

public extension View {
    /// Adds drag gesture handling with a single state binding.
    /// Recommended for most drag gesture implementations.
    func kineticsDragGesture(
        state: Binding<KineticsDragState>,
        minimumDistance: CGFloat = 0,
        velocityScale: CGFloat = 0.25
    ) -> some View {
        modifier(KineticsDragGestureStateModifier(state: state, minimumDistance: minimumDistance, velocityScale: velocityScale))
    }

    /// Adds drag gesture handling with separate bindings for each state component.
    /// Useful when you need fine-grained control over individual state values.
    func kineticsDragGesture(
        translation: Binding<CGPoint>,
        projectedTranslation: Binding<CGPoint>,
        velocity: Binding<CGPoint>,
        isActive: Binding<Bool>,
        minimumDistance: CGFloat = 0,
        velocityScale: CGFloat = 0.25
    ) -> some View {
        modifier(
            KineticsDragGestureBindingsModifier(
                translation: translation,
                projectedTranslation: projectedTranslation,
                velocity: velocity,
                isActive: isActive,
                minimumDistance: minimumDistance,
                velocityScale: velocityScale
            )
        )
    }
}
