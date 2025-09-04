import SwiftUI
import CoreGraphics

// MARK: - Public Rotation State

/// Comprehensive state for rotation gesture interactions.
/// Tracks accumulated rotation, predicted rotation, angular velocity, and active status.
public struct KineticsRotationState: Equatable {
    /// Accumulated rotation delta since gesture start (radians).
    /// Positive values indicate clockwise rotation in default orientation.
    public var rotation: Double = 0
    
    /// Predicted final rotation including momentum: rotation + ω * projectionFallbackTime
    /// Used for responsive UI updates during gesture.
    public var projectedRotation: Double = 0
    
    /// Angular velocity ω (radians per second).
    /// Positive values indicate clockwise rotation in default orientation.
    public var angularVelocity: Double = 0
    
    /// Whether the rotation gesture is currently active.
    public var isActive: Bool = false

    public init() {}
}

/// Sign convention for rotation deltas.
/// Controls how rotation direction is interpreted relative to gesture motion.
public enum KineticsRotationOrientation {
    /// Clockwise positive - matches typical knob feel in iOS screen coordinates.
    /// Natural for most rotation interactions.
    case clockwise
    
    /// Counter-clockwise positive - mathematical convention.
    /// Useful for mathematical or scientific applications.
    case counterClockwise
}

/// Preference key for capturing view size during rotation gestures.
private struct _KineticsSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

// MARK: - One-Finger Rotation via DragGesture

/// View modifier that provides rotation gesture handling using drag gestures.
/// Converts linear finger motion to angular rotation with momentum prediction.
public struct KineticsRotationGestureStateModifier: ViewModifier {
    @Binding private var state: KineticsRotationState

    private let minimumDistance: CGFloat
    private let velocityScale: Double
    private let projectionFallbackTime: Double
    private let coordinateSpace: CoordinateSpace
    private let orientation: KineticsRotationOrientation
    private let historyWindow: Int

    @GestureState private var _tick: Bool = false

    // MARK: - Internal State
    
    /// Current view size for coordinate calculations
    @State private var viewSize: CGSize = .zero
    /// Previous angle for delta calculation
    @State private var previousAngle: Double? = nil
    /// Previous timestamp for velocity calculation
    @State private var previousTime: TimeInterval? = nil
    /// Accumulated rotation since gesture start
    @State private var accumulated: Double = 0
    /// Recent rotation deltas for velocity averaging
    @State private var recentDeltas: [Double] = []
    /// Recent time deltas for velocity averaging
    @State private var recentDTs: [Double] = []

    public init(
        state: Binding<KineticsRotationState>,
        minimumDistance: CGFloat = 0,
        velocityScale: Double = 1.0,
        projectionFallbackTime: Double = 0.40,
        coordinateSpace: CoordinateSpace = .local,
        orientation: KineticsRotationOrientation = .clockwise,
        historyWindow: Int = 5 // samples to average ω & infer direction
    ) {
        self._state = state
        self.minimumDistance = minimumDistance
        self.velocityScale = velocityScale
        self.projectionFallbackTime = projectionFallbackTime
        self.coordinateSpace = coordinateSpace
        self.orientation = orientation
        self.historyWindow = max(2, historyWindow)
    }

    public func body(content: Content) -> some View {
        content
            .background(GeometryReader { proxy in
                Color.clear.preference(key: _KineticsSizeKey.self, value: proxy.size)
            })
            .onPreferenceChange(_KineticsSizeKey.self) { viewSize = $0 }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: minimumDistance, coordinateSpace: coordinateSpace)
                    .updating($_tick) { value, tick, _ in
                        tick = true
                        guard viewSize.width > 0, viewSize.height > 0 else { return }

                        let now = value.time.timeIntervalSinceReferenceDate
                        let currentAngle = fingerAngle(at: value.location, in: viewSize)

                        // Initialize on first valid sample
                        guard let prevAngle = previousAngle, let t0 = previousTime else {
                            previousAngle = currentAngle
                            previousTime = now
                            accumulated = 0
                            recentDeltas.removeAll(keepingCapacity: true)
                            recentDTs.removeAll(keepingCapacity: true)

                            state.isActive = true
                            state.rotation = 0
                            state.angularVelocity = 0
                            state.projectedRotation = 0
                            return
                        }

                        // Calculate shortest signed angle delta (handles wrapping)
                        var dTheta = shortestAngleDelta(from: prevAngle, to: currentAngle)
                        if orientation == .counterClockwise { dTheta = -dTheta }

                        let dt = max(now - t0, 1e-6)
                        pushDelta(dTheta, dt: dt)

                        accumulated += dTheta

                        // Calculate windowed average angular velocity
                        let omegaAvg = averagedOmega() * velocityScale

                        state.isActive = true
                        state.rotation = accumulated
                        state.angularVelocity = omegaAvg
                        state.projectedRotation = accumulated + omegaAvg * projectionFallbackTime

                        previousAngle = currentAngle
                        previousTime = now
                    }
                    .onEnded { value in
                        defer { reset() }
                        guard viewSize.width > 0, viewSize.height > 0 else { return }

                        // Include final delta if we have a new end location
                        if let prevAngle = previousAngle, let t0 = previousTime {
                            let now = value.time.timeIntervalSinceReferenceDate
                            let endAngle = fingerAngle(at: value.location, in: viewSize)
                            var dThetaEnd = shortestAngleDelta(from: prevAngle, to: endAngle)
                            if orientation == .counterClockwise { dThetaEnd = -dThetaEnd }
                            let dtEnd = max(now - t0, 1e-6)
                            pushDelta(dThetaEnd, dt: dtEnd)
                            accumulated += dThetaEnd
                        }

                        // Determine rotation direction from recent history
                        let histSum = recentDeltas.reduce(0, +)
                        var dirSign = sign(of: histSum)

                        // If history is ambiguous, use predicted end direction
                        if dirSign == 0 {
                            let predicted = value.predictedEndLocation
                            let a0 = fingerAngle(at: value.location, in: viewSize)
                            let a1 = fingerAngle(at: predicted, in: viewSize)
                            var dθp = shortestAngleDelta(from: a0, to: a1)
                            if orientation == .counterClockwise { dθp = -dθp }
                            dirSign = sign(of: dθp)
                        }

                        // Calculate final angular velocity magnitude from windowed average
                        var omegaMag = abs(averagedOmega()) * velocityScale

                        // Optionally upgrade magnitude from predicted delta
                        let predicted = value.predictedEndLocation
                        let a0 = fingerAngle(at: value.location, in: viewSize)
                        let a1 = fingerAngle(at: predicted, in: viewSize)
                        var dθp = shortestAngleDelta(from: a0, to: a1)
                        if orientation == .counterClockwise { dθp = -dθp }
                        let omegaPred = abs(dθp) / max(projectionFallbackTime, 1e-6)
                        
                        // Take the larger magnitude to preserve fast flick feel
                        omegaMag = max(omegaMag, omegaPred)
                        
                        // If direction still ambiguous, use predicted sign
                        if dirSign == 0 { dirSign = sign(of: dθp) }

                        // Final fallback: use last non-zero sample direction or current ω sign
                        if dirSign == 0 {
                            dirSign = sign(of: state.angularVelocity)
                        }

                        let finalOmega = dirSign * omegaMag

                        state.rotation = accumulated
                        state.angularVelocity = finalOmega
                        state.projectedRotation = accumulated + finalOmega * projectionFallbackTime
                        state.isActive = false
                    }
            )
    }

    // MARK: - Helper Methods

    /// Resets internal state for the next gesture
    private func reset() {
        previousAngle = nil
        previousTime = nil
        recentDeltas.removeAll(keepingCapacity: true)
        recentDTs.removeAll(keepingCapacity: true)
        accumulated = 0
    }

    /// Adds a rotation delta to the history window for velocity averaging
    private func pushDelta(_ dθ: Double, dt: Double) {
        recentDeltas.append(dθ)
        recentDTs.append(dt)
        if recentDeltas.count > historyWindow {
            recentDeltas.removeFirst()
            recentDTs.removeFirst()
        }
    }

    /// Calculates windowed average angular velocity from recent deltas
    private func averagedOmega() -> Double {
        let dSum = recentDeltas.reduce(0, +)
        let tSum = recentDTs.reduce(0, +)
        guard tSum > 0 else { return 0 }
        return dSum / tSum
    }
}

// MARK: - View Extensions

public extension View {
    /// Adds rotation gesture handling with comprehensive state tracking.
    /// Converts linear finger motion to angular rotation with momentum prediction.
    func kineticsRotationGesture(
        state: Binding<KineticsRotationState>,
        minimumDistance: CGFloat = 0,
        velocityScale: Double = 1.0,
        projectionFallbackTime: Double = 0.40,
        coordinateSpace: CoordinateSpace = .local,
        orientation: KineticsRotationOrientation = .clockwise,
        historyWindow: Int = 5
    ) -> some View {
        modifier(
            KineticsRotationGestureStateModifier(
                state: state,
                minimumDistance: minimumDistance,
                velocityScale: velocityScale,
                projectionFallbackTime: projectionFallbackTime,
                coordinateSpace: coordinateSpace,
                orientation: orientation,
                historyWindow: historyWindow
            )
        )
    }
}

// MARK: - Mathematical Utilities

/// Calculates the angle of a finger position relative to view center.
/// Returns angle in radians in the range [-π, π].
@inline(__always)
private func fingerAngle(at p: CGPoint, in size: CGSize) -> Double {
    let cx = size.width * 0.5
    let cy = size.height * 0.5
    return atan2(Double(p.y - cy), Double(p.x - cx))  // [-π, π]
}

/// Calculates the shortest signed angle delta between two angles.
/// Handles angle wrapping safely and returns result in range [-π, π].
@inline(__always)
private func shortestAngleDelta(from a0: Double, to a1: Double) -> Double {
    let d = a1 - a0
    return atan2(sin(d), cos(d))
}

/// Returns the sign of a number: 1 for positive, -1 for negative, 0 for zero.
@inline(__always)
private func sign(of x: Double) -> Double {
    if x > 0 { return 1 }
    if x < 0 { return -1 }
    return 0
}
