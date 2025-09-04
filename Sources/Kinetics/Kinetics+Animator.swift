import Foundation
import SwiftUI

@MainActor
public protocol SpringAnimatorProtocol {
    func start() async
    func stop() async
}

/// Main spring animation engine that simulates physics-based motion.
/// Uses a frame-based clock to update animation state and provides
/// comprehensive state management and boundary handling.
@MainActor
public final class SpringAnimator<Value: KineticsValue>: ObservableObject, SpringAnimatorProtocol, _KineticsTickSubscriber {

    // MARK: - Published State
    
    /// Current animated value - updated each frame during animation
    @Published public private(set) var currentValue: Value
    /// Current animation state (idle, animating, completed, cancelled)
    @Published public private(set) var state: KineticsAnimationState = .idle
    /// Current velocity vector - used for momentum and settling detection
    @Published public private(set) var velocity: Value = .zero
    /// Spring configuration that controls animation behavior
    @Published public private(set) var spring: KineticsSpring

    /// Target value for the animation - updated immediately when set
    /// The animation loop reads this value on each tick
    public var targetValue: Value { didSet { /* loop reads latest */ } }

    /// Single callback that provides comprehensive animation updates
    /// Called on every state change and frame update
    public var onEvent: ((KineticsUpdate<Value>) -> Void)?

    // MARK: - Physics Parameters
    
    /// Angular frequency: ω = 2π/response (controls spring stiffness)
    private var omega: Double
    /// Damping ratio: ζ = dampingRatio (controls oscillation)
    private var zeta: Double

    // MARK: - Settling Detection
    
    /// Number of consecutive frames below threshold required to settle
    private let settleFramesNeeded: Int = 3
    /// Current count of consecutive settled frames
    private var settleFrames: Int = 0

    // MARK: - Animation Control
    
    /// Continuation for awaiting animation completion
    private var awaiting: CheckedContinuation<Void, Never>?
    /// Whether this animator is registered with the frame clock
    private var isRegistered = false

    /// Accumulated time since animation start
    private var elapsed: TimeInterval = 0

    // MARK: - Boundary Handling
    
    /// Boundary configuration for collision detection and response
    public var boundary: KineticsBoundary<Value> = .none {
        didSet { boundaryResolver = boundary.collisionResolver() }
    }
    /// Resolved boundary collision handler
    private var boundaryResolver: ((Value, Value) -> (Value, Value))?

    public init(
        initialValue: Value,
        spring: KineticsSpring,
        boundary: KineticsBoundary<Value> = .none,
        onEvent: ((KineticsUpdate<Value>) -> Void)? = nil
    ) {
        self.currentValue = initialValue
        self.targetValue = initialValue
        self.spring = spring
        self.boundary = boundary
        self.boundaryResolver = boundary.collisionResolver()
        self.onEvent = onEvent
        self.omega = 2 * .pi / spring.response
        self.zeta = spring.dampingRatio
    }

    // MARK: - Animation Control
    
    /// Starts the spring animation from current state to target
    public func start() async {
        guard state != .animating else { return }
        elapsed = 0

        // Check if already at target to avoid unnecessary animation
        if hasSettled(position: currentValue, target: targetValue, velocity: velocity) {
            state = .completed
            onEvent?(KineticsUpdate(state: state, current: currentValue, target: targetValue, velocity: velocity, spring: spring, elapsed: elapsed))
            state = .idle
            return
        }

        state = .animating
        onEvent?(KineticsUpdate(state: state, current: currentValue, target: targetValue, velocity: velocity, spring: spring, elapsed: elapsed))
        registerIfNeeded()

        // Wait for animation to complete or be cancelled
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            awaiting?.resume()
            awaiting = cont
        }
    }

    /// Stops the current animation and resets to idle state
    public func stop() async {
        guard state != .idle else {
            if let cont = awaiting { awaiting = nil; cont.resume() }
            return
        }
        state = .cancelled
        onEvent?(KineticsUpdate(state: state, current: currentValue, target: targetValue, velocity: velocity, spring: spring, elapsed: elapsed))
        unregisterIfNeeded()
        if let cont = awaiting { awaiting = nil; cont.resume() }
        state = .idle
    }

    /// Updates target value and optionally initial velocity, then starts animation
    public func animate(to target: Value, velocity: Value? = nil) async {
        if let v = velocity { self.velocity = v }
        switch boundary {
        case .rubber:
            // Rubber boundaries may adjust the target based on constraints
            self.targetValue = boundary.relkineticsTarget(for: target)
        default:
            self.targetValue = target
        }
        await start()
    }

    /// Hard-sets the current value and velocity without animation
    /// Useful for immediate state changes or resetting animation
    public func setValue(_ value: Value, velocity: Value = .zero) {
        state = .idle
        unregisterIfNeeded()
        currentValue = value
        targetValue = value
        self.velocity = velocity
        onEvent?(KineticsUpdate(state: .idle, current: currentValue, target: targetValue, velocity: velocity, spring: spring, elapsed: elapsed))
    }

    /// Updates spring parameters and recalculates physics constants
    public func updateSpring(_ newSpring: KineticsSpring) {
        spring = newSpring
        omega = 2 * .pi / newSpring.response
        zeta = newSpring.dampingRatio
    }

    /// SwiftUI Animation equivalent for compatibility
    public var animation: Animation { spring.animation }

    // MARK: - Frame Clock Integration
    
    /// Registers this animator with the shared frame clock
    private func registerIfNeeded() {
        guard !isRegistered else { return }
        KineticsFrameClock.shared.add(self)
        isRegistered = true
    }

    /// Unregisters this animator from the shared frame clock
    private func unregisterIfNeeded() {
        guard isRegistered else { return }
        KineticsFrameClock.shared.remove(self)
        isRegistered = false
    }

    // MARK: - Physics Simulation
    
    /// Called by the frame clock to update animation state
    /// Implements spring-mass-damper physics simulation
    func _kineticsTick(dt: Double) {
        guard state == .animating else { return }
        elapsed += dt

        // Spring force: F = -k(x - x*) = -ω²(x - x*)
        let disp = kineticsSub(currentValue, targetValue) // x - x*
        let aSpring = kineticsScale(disp, -omega * omega) // -ω²(x - x*)
        
        // Damping force: F = -c·v = -2ζω·v
        let aDamp = kineticsScale(velocity, -2 * zeta * omega) // -2ζω v
        
        // Total acceleration: a = F/m = aSpring + aDamp
        let accel = kineticsAdd(aSpring, aDamp)

        // Velocity update: v(t+dt) = v(t) + a·dt
        let vNext = kineticsAdd(velocity, kineticsScale(accel, dt))
        
        // Position update: x(t+dt) = x(t) + v·dt
        var xNext = kineticsAdd(currentValue, kineticsScale(vNext, dt))

        // Apply boundary constraints if configured
        if let resolve = boundaryResolver {
            let (xRes, vRes) = resolve(xNext, vNext)
            xNext = xRes
            velocity = vRes
        } else {
            velocity = vNext
        }

        currentValue = xNext
        onEvent?(KineticsUpdate(state: .animating, current: currentValue, target: targetValue, velocity: velocity, spring: spring, elapsed: elapsed))

        // Check if animation has settled
        if hasSettled(position: currentValue, target: targetValue, velocity: velocity) {
            settleFrames += 1
            if settleFrames >= settleFramesNeeded {
                state = .completed
                onEvent?(KineticsUpdate(state: state, current: currentValue, target: targetValue, velocity: velocity, spring: spring, elapsed: elapsed))
                unregisterIfNeeded()
                if let cont = awaiting { awaiting = nil; cont.resume() }
                state = .idle
            }
        } else {
            settleFrames = 0
        }
    }

    /// Determines if the animation has settled based on position, velocity, and energy
    private func hasSettled(position: Value, target: Value, velocity: Value) -> Bool {
        // Check if position and velocity are below threshold
        let diff = kineticsSub(position, target)
        let dispMax = diff.components.map { abs($0) }.max() ?? 0
        let velMax = velocity.components.map { abs($0) }.max() ?? 0
        if dispMax < spring.threshold && velMax < spring.threshold { return true }

        // Energy-based settling check (more robust than position/velocity alone)
        // Total energy = Potential Energy + Kinetic Energy
        // PE = ½k(x-x*)² = ½ω²(x-x*)², KE = ½mv² = ½v² (assuming m=1)
        let pe = 0.5 * (omega * omega) * diff.components.reduce(0) { $0 + $1 * $1 }
        let ke = 0.5 * velocity.components.reduce(0) { $0 + $1 * $1 }
        return (pe + ke) < (spring.threshold * spring.threshold * 0.5)
    }

    deinit {
        if let cont = awaiting { awaiting = nil; cont.resume() }
        // Note: unregisterIfNeeded() cannot be called from deinit due to MainActor isolation
        // The clock will clean up weak references automatically
    }
}
