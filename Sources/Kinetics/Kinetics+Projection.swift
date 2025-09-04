import SwiftUI
import Foundation

/// Configuration for motion prediction and projection algorithms.
/// Controls how far ahead to predict motion and how to handle edge cases.
public struct ProjectionConfig: Equatable {
    /// Maximum distance to project (prevents extreme predictions)
    public var maxDistance: Double?
    /// Fallback time for velocity-based projection when prediction is unavailable
    public var fallbackTime: Double
    /// Scale factor for converting horizontal motion to angular rotation
    public var angleScale: Double
    /// Maximum number of full rotations to allow in angle projection
    public var maxWraps: ClosedRange<Int>?

    public init(
        maxDistance: Double? = nil,
        fallbackTime: Double = 0.35,
        angleScale: Double = 0.015,
        maxWraps: ClosedRange<Int>? = nil
    ) {
        self.maxDistance = maxDistance
        self.fallbackTime = max(0.0, fallbackTime)
        self.angleScale = angleScale
        self.maxWraps = maxWraps
    }
}

/// Motion prediction and projection utilities for gesture-based interactions.
/// Helps create responsive UIs by predicting where motion will end.
public enum Projection {
    
    /// Projects a scalar value by adding a predicted delta with distance constraints.
    /// Useful for predicting final positions of drag gestures.
    public static func projectScalar(current: Double, predictedDelta: Double, cfg: ProjectionConfig = .init()) -> Double {
        var t = current + predictedDelta
        if let cap = cfg.maxDistance {
            let delta = t - current
            if abs(delta) > cap { t = current + (delta.sign == .minus ? -cap : cap) }
        }
        return t
    }

    /// Projects a scalar value using velocity and fallback time.
    /// Fallback when gesture prediction is unavailable.
    public static func projectScalar(current: Double, velocity: Double, cfg: ProjectionConfig = .init()) -> Double {
        projectScalar(current: current, predictedDelta: velocity * cfg.fallbackTime, cfg: cfg)
    }

    /// Projects a multi-component value by adding predicted deltas with distance constraints.
    /// Applies constraints component-wise for vector-like types.
    public static func projectValue<T: KineticsComponents>(current: T, predictedDelta: T, cfg: ProjectionConfig = .init()) -> T where T.FloatType == Double {
        let raw = kineticsAdd(current, predictedDelta)
        guard let cap = cfg.maxDistance else { return raw }
        
        let c0 = current.components, c1 = raw.components
        var out = [Double](); out.reserveCapacity(max(c0.count, c1.count))
        
        for i in 0..<max(c0.count, c1.count) {
            let a = i < c0.count ? c0[i] : 0
            let b = i < c1.count ? c1[i] : 0
            let d = b - a
            let clamped = abs(d) > cap ? (a + (d.sign == .minus ? -cap : cap)) : b
            out.append(clamped)
        }
        return .init(components: out)
    }

    /// Projects a multi-component value using velocity and fallback time.
    /// Fallback when gesture prediction is unavailable.
    public static func projectValue<T: KineticsComponents>(current: T, velocity: T, cfg: ProjectionConfig = .init()) -> T where T.FloatType == Double {
        projectValue(current: current, predictedDelta: kineticsScale(velocity, cfg.fallbackTime), cfg: cfg)
    }

    /// Projects angular rotation based on horizontal motion prediction.
    /// Converts linear gesture motion to rotational motion for dial-like interactions.
    public static func projectAngle(currentRadians: Double, predictedHorizontalDelta: Double, cfg: ProjectionConfig = .init()) -> Double {
        var deltaAngle = predictedHorizontalDelta * cfg.angleScale
        let twoPi = Double.pi * 2
        
        // Apply rotation wrapping limits if configured
        if let limit = cfg.maxWraps {
            let wraps = Int((abs(deltaAngle) / twoPi).rounded(.towardZero))
            if wraps > limit.upperBound {
                deltaAngle = twoPi * Double(limit.upperBound) * (deltaAngle < 0 ? -1 : 1)
            }
        }
        return currentRadians + deltaAngle
    }
}
