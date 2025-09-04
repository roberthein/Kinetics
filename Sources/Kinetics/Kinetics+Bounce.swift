import Foundation
import SwiftUI

/// Configuration for bounce boundary physics simulation.
/// Provides realistic collision response when animated values hit boundaries.
public struct BounceBoundary: Equatable, Sendable {
    /// X-axis boundary range
    public var xr: ClosedRange<Double>
    /// Y-axis boundary range
    public var yr: ClosedRange<Double>

    /// Coefficient of restitution: Controls bounce energy
    /// - 0.0: No bounce (sticks to boundary)
    /// - 1.0: Perfectly elastic bounce (conserves energy)
    /// - Typical values: 0.3-0.7 for realistic feel
    public var restitution: Double
    
    /// Friction coefficient: Controls tangential motion damping
    /// - 0.0: No friction (smooth sliding along boundary)
    /// - 1.0: Full stop (no tangential motion)
    /// - Typical values: 0.05-0.2 for natural feel
    public var friction: Double

    public init(xr: ClosedRange<Double>, yr: ClosedRange<Double>, restitution: Double = 0.35, friction: Double = 0.05) {
        self.xr = xr
        self.yr = yr
        self.restitution = max(0, min(1, restitution))
        self.friction = max(0, min(1, friction))
    }

    /// Creates a collision resolver function for use with SpringAnimator.
    /// Handles boundary collisions with realistic physics response.
    public func resolver<Value: KineticsValue>() -> (Value, Value) -> (Value, Value) where Value.FloatType == Double {
        { pos, vel in
            var p = pos.components
            var v = vel.components
            
            // Handle X-axis boundary collisions
            if p.indices.contains(0) {
                if p[0] < xr.lowerBound { 
                    p[0] = xr.lowerBound
                    v[0] = -v[0] * restitution  // Reverse and scale velocity
                    v[0] *= (1 - friction)       // Apply friction
                }
                else if p[0] > xr.upperBound { 
                    p[0] = xr.upperBound
                    v[0] = -v[0] * restitution  // Reverse and scale velocity
                    v[0] *= (1 - friction)       // Apply friction
                }
            }
            
            // Handle Y-axis boundary collisions
            if p.indices.contains(1) {
                if p[1] < yr.lowerBound { 
                    p[1] = yr.lowerBound
                    v[1] = -v[1] * restitution  // Reverse and scale velocity
                    v[1] *= (1 - friction)       // Apply friction
                }
                else if p[1] > yr.upperBound { 
                    p[1] = yr.upperBound
                    v[1] = -v[1] * restitution  // Reverse and scale velocity
                    v[1] *= (1 - friction)       // Apply friction
                }
            }
            
            return (Value(components: p), Value(components: v))
        }
    }
}

// MARK: - Unified Boundary System

/// Unified boundary system that handles different types of constraints.
/// Provides a single interface for bounce, rubber band, and no-boundary scenarios.
public enum KineticsBoundary<Value: KineticsValue>: Sendable {
    /// No boundary constraints - free movement
    case none
    
    /// Bounce boundary with collision physics
    case bounce(BounceBoundary)
    
    /// Rubber band boundaries per component (0=x, 1=y, etc.)
    /// Used to compute constrained animation targets.
    /// Display mapping is optional via `.rubberBanded(...)`.
    case rubber(perComponent: [Int: RubberBandConfig])

    /// Calculates the target value considering boundary constraints.
    /// Rubber boundaries may adjust targets, bounce boundaries pass through unchanged.
    public func releaseTarget(for raw: Value) -> Value {
        switch self {
        case .none, .bounce: return raw
        case let .rubber(cfgs): return RubberBandCommit.releaseTarget(raw: raw, perComponent: cfgs)
        }
    }

    /// Returns a collision resolver function for physics simulation.
    /// Bounce boundaries provide collision response, others return nil.
    public func collisionResolver() -> ((Value, Value) -> (Value, Value))? {
        switch self {
        case .none: return nil
        case let .bounce(b): return b.resolver()
        case .rubber: return nil
        }
    }
}
