import Foundation
import SwiftUI

/// Configuration for rubber band physics simulation.
/// Provides iOS-like resistance when content is dragged beyond boundaries.
public struct RubberBandConfig: Equatable, Sendable {
    
    /// Defines how rubber band behavior is applied to values.
    public enum Mode: Equatable, Sendable {
        /// Free movement within bounds, rubber resistance outside.
        /// - `bounds`: Range where movement is unrestricted
        /// - `freeOvershoot`: Additional pixels of free movement before rubber effect
        case outside(bounds: ClosedRange<Double>, freeOvershoot: Double = 0)
        
        /// Resistance from an anchor point up to a threshold.
        /// - `anchor`: Center point where resistance begins
        /// - `bandUntil`: Distance from anchor where resistance ends
        /// - `snapBackInside`: Whether to snap back to anchor when released inside band
        case inside(anchor: Double = 0, bandUntil: Double, snapBackInside: Bool = true)
    }

    /// Mathematical curve family for rubber band resistance.
    public enum Curve: Equatable, Sendable {
        /// UIScrollView-like rational function: f(x) = (c*x*d) / (d + c*x)
        /// Provides smooth, natural-feeling resistance (c ≈ 0.55)
        case rational
        
        /// Logarithmic resistance with normalized slope at origin.
        /// f(x) = (d / ln(10)) * ln(1 + (c * ln(10) / d) * x)
        /// Ensures f'(0) = c for consistent initial resistance
        case log10Normalized
    }

    /// "Softness" constant that controls resistance strength.
    /// Lower values create stiffer resistance (≈ 0.55 for classic UIScrollView feel).
    public var constant: Double
    
    /// Dimension along the axis (view size or visible range).
    /// Used to scale the rubber effect appropriately.
    public var dimension: Double
    
    /// How rubber band behavior is applied.
    public var mode: Mode
    
    /// Mathematical curve family for resistance calculation.
    public var curve: Curve

    public init(constant: Double = 0.55, dimension: Double, mode: Mode, curve: Curve = .rational) {
        self.constant = max(0.0001, constant)
        self.dimension = max(1, dimension)
        self.mode = mode
        self.curve = curve
    }
}

// MARK: - Rubber Band Mathematics

/// Calculates rubber band resistance using rational function.
/// Provides UIScrollView-like feel with smooth, natural resistance.
private func rubber_rational(_ x: Double, d: Double, c: Double) -> Double {
    (c * x * d) / (d + c * x)
}

/// Calculates rubber band resistance using normalized logarithmic function.
/// Ensures consistent initial resistance slope for predictable feel.
private func rubber_log10Normalized(_ x: Double, d: Double, c: Double) -> Double {
    let ln10 = 2.302585092994046
    return (d / ln10) * log1p((c * ln10 / d) * x)
}

/// Applies the appropriate rubber band curve based on configuration.
private func rubberMap(_ x: Double, d: Double, c: Double, curve: RubberBandConfig.Curve) -> Double {
    switch curve {
    case .rational: return rubber_rational(x, d: d, c: c)
    case .log10Normalized: return rubber_log10Normalized(x, d: d, c: c)
    }
}

// MARK: - Rubber Band Engine

/// Main rubber band physics simulation engine.
/// Applies resistance when values exceed boundaries according to configuration.
public struct RubberBand {
    
    /// Maps a raw value through rubber band physics based on configuration.
    /// Returns the resistance-adjusted value for display purposes.
    public static func map(_ x: Double, cfg: RubberBandConfig) -> Double {
        switch cfg.mode {
        case let .outside(bounds, free):
            // Calculate pivot points with optional free overshoot
            let leftPivot = bounds.lowerBound - max(0, free)
            let rightPivot = bounds.upperBound + max(0, free)
            
            // Apply rubber resistance outside bounds
            if x < leftPivot {
                let t = (leftPivot - x)
                let r = rubberMap(t, d: cfg.dimension, c: cfg.constant, curve: cfg.curve)
                return leftPivot - r
            }
            if x > rightPivot {
                let t = (x - rightPivot)
                let r = rubberMap(t, d: cfg.dimension, c: cfg.constant, curve: cfg.curve)
                return rightPivot + r
            }
            return x
            
        case let .inside(anchor, bandUntil, _):
            let d = x - anchor
            let ad = abs(d)
            
            if ad <= bandUntil {
                // Apply resistance within the band
                let r = rubberMap(ad, d: cfg.dimension, c: cfg.constant, curve: cfg.curve)
                return anchor + (d < 0 ? -r : r)
            } else {
                // Free movement beyond the band
                let edge = rubberMap(bandUntil, d: cfg.dimension, c: cfg.constant, curve: cfg.curve)
                let beyond = ad - bandUntil
                return anchor + (d < 0 ? -(edge + beyond) : (edge + beyond))
            }
        }
    }

    /// Calculates the target value for rubber band boundaries.
    /// Used by the animation system to determine where to animate to.
    public static func releaseTarget(_ x: Double, cfg: RubberBandConfig) -> Double {
        switch cfg.mode {
        case let .outside(bounds, _):
            // Clamp to bounds for outside mode
            return min(max(x, bounds.lowerBound), bounds.upperBound)
        case let .inside(anchor, bandUntil, snap):
            // Snap to anchor if within band and snapping is enabled
            if snap, abs(x - anchor) <= bandUntil { return anchor }
            return x
        }
    }
}

// MARK: - Component Extensions

public extension KineticsComponents where Self.FloatType == Double {
    /// Applies rubber band mapping component-wise to multi-component values.
    /// Use for display purposes only - keep the underlying state "raw".
    /// - `cfg`: Rubber band configuration
    /// - `indices`: Specific components to apply to (nil for all)
    func rubberBanded(_ cfg: RubberBandConfig, applyTo indices: Set<Int>? = nil) -> Self {
        var comps = components
        let idxs = indices ?? Set(0..<comps.count)
        for i in comps.indices where idxs.contains(i) {
            comps[i] = RubberBand.map(comps[i], cfg: cfg)
        }
        return .init(components: comps)
    }
}

public extension Binding where Value: KineticsComponents, Value.FloatType == Double {
    /// Creates a display-only binding that applies rubber band mapping on read.
    /// Writes pass through to the underlying value without modification.
    /// - `cfg`: Rubber band configuration
    /// - `indices`: Specific components to apply to (nil for all)
    func rubberMapped(_ cfg: RubberBandConfig, applyTo indices: Set<Int>? = nil) -> Binding<Value> {
        Binding(
            get: { wrappedValue.rubberBanded(cfg, applyTo: indices) },
            set: { wrappedValue = $0 }
        )
    }
}

// MARK: - Target Calculation

/// Utilities for calculating animation targets with rubber band boundaries.
public enum RubberBandCommit {
    
    /// Calculates the target value for animation considering rubber band constraints.
    /// - `raw`: The raw, unconstrained target value
    /// - `perComponent`: Rubber band configuration for each component index
    public static func releaseTarget<T: KineticsComponents>(
        raw: T,
        perComponent cfgs: [Int: RubberBandConfig]
    ) -> T where T.FloatType == Double {
        var c = raw.components
        for (i, cfg) in cfgs where i < c.count {
            c[i] = RubberBand.releaseTarget(c[i], cfg: cfg)
        }
        return .init(components: c)
    }
}
