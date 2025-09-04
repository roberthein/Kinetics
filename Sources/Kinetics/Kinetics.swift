import SwiftUI
import Foundation
import CoreGraphics

// MARK: - Core Value Surface

/// Protocol defining types that can be broken down into floating-point components.
/// This enables generic mathematical operations on various geometric types.
public protocol KineticsComponents: Equatable, Sendable {
    associatedtype FloatType: BinaryFloatingPoint
    var components: [FloatType] { get set }
    init(components: [FloatType])
}

/// Protocol for types that have a well-defined zero value.
/// Required for initializing animations and resetting state.
public protocol KineticsZero: Sendable {
    static var zero: Self { get }
}

/// Protocol for double-backed value types used by the animator.
/// All operations are performed on the MainActor for SwiftUI compatibility.
public protocol KineticsValue: KineticsComponents, KineticsZero where FloatType == Double { }

/// Represents the current state of a spring animation.
/// Used to track animation lifecycle and provide status updates.
public enum KineticsAnimationState: Equatable, Sendable {
    case idle, animating, completed, cancelled
    public var isAnimating: Bool { self == .animating }
}

/// Comprehensive update payload containing all animation state information.
/// Provides a single callback interface for monitoring animation progress.
public struct KineticsUpdate<Value: KineticsValue>: Sendable {
    public let state: KineticsAnimationState
    public let current: Value
    public let target: Value
    public let velocity: Value
    public let spring: KineticsSpring
    public let elapsed: TimeInterval
}

// MARK: - Spring Configuration

/// Immutable spring configuration with physics-based parameters.
/// Provides sensible presets for common animation feels.
public struct KineticsSpring: Equatable, Sendable {
    /// Damping ratio (ζ): Controls oscillation behavior
    /// - ζ = 1: Critically damped (no oscillation)
    /// - ζ < 1: Underdamped (bouncy with overshoot)
    /// - ζ > 1: Overdamped (smooth, no overshoot)
    public let dampingRatio: Double
    
    /// Response time in seconds: Controls animation speed
    /// Smaller values create snappier, more responsive animations
    public let response: Double
    
    /// Threshold for determining when animation has settled
    /// Applied to both position and velocity magnitudes
    public let threshold: Double

    // Minimum constraints to prevent invalid configurations
    public static let minimumResponse: Double = 0.001
    public static let minimumThreshold: Double = 0.000_001

    public init(dampingRatio: Double, response: Double, threshold: Double = 0.01) {
        self.dampingRatio = max(0.0, dampingRatio)
        self.response = max(Self.minimumResponse, response)
        self.threshold = max(Self.minimumThreshold, threshold)
    }

    // MARK: - Preset Configurations
    
    // Bouncy springs with clear overshoot for playful interactions
    public static let playful = KineticsSpring(dampingRatio: 0.4, response: 0.6)
    public static let elastic = KineticsSpring(dampingRatio: 0.5, response: 0.5)
    public static let bouncy = KineticsSpring(dampingRatio: 0.6, response: 0.4)

    // Expressive springs with light overshoot for responsive feel
    public static let snappy = KineticsSpring(dampingRatio: 0.9, response: 0.3)
    public static let ultraSnappy = KineticsSpring(dampingRatio: 0.9,  response: 0.15)

    // Smooth springs with no overshoot for precise interactions
    public static let rigid = KineticsSpring(dampingRatio: 1.2,  response: 0.30)
    public static let gentle = KineticsSpring(dampingRatio: 1.0, response: 0.8)

    /// SwiftUI Animation equivalent for compatibility with existing code
    public var animation: Animation { .interactiveSpring(response: response, dampingFraction: dampingRatio) }
}

// MARK: - Mathematical Operations

/// Component-wise addition of two KineticsComponents.
/// Handles different component counts by padding with zeros.
internal func kineticsAdd<T: KineticsComponents>(_ a: T, _ b: T) -> T where T.FloatType == Double {
    let ca = a.components, cb = b.components
    let n = max(ca.count, cb.count)
    var out = [Double](); out.reserveCapacity(n)
    for i in 0..<n { out.append((i < ca.count ? ca[i] : 0) + (i < cb.count ? cb[i] : 0)) }
    return .init(components: out)
}

/// Component-wise subtraction of two KineticsComponents.
/// Handles different component counts by padding with zeros.
internal func kineticsSub<T: KineticsComponents>(_ a: T, _ b: T) -> T where T.FloatType == Double {
    let ca = a.components, cb = b.components
    let n = max(ca.count, cb.count)
    var out = [Double](); out.reserveCapacity(n)
    for i in 0..<n { out.append((i < ca.count ? ca[i] : 0) - (i < cb.count ? cb[i] : 0)) }
    return .init(components: out)
}

/// Component-wise scaling of KineticsComponents by a scalar value.
internal func kineticsScale<T: KineticsComponents>(_ a: T, _ s: Double) -> T where T.FloatType == Double {
    .init(components: a.components.map { $0 * s })
}
