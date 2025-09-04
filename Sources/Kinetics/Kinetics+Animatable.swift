import Foundation
import SwiftUI

// MARK: - Core Types

/// Extends Double to conform to KineticsValue for scalar animations.
/// Maps the single value to/from a one-element components array.
extension Double: KineticsValue {
    public typealias FloatType = Double
    public var components: [Double] {
        get { [self] }
        set { self = newValue.first ?? 0 }
    }
    public init(components: [Double]) { self = components.first ?? 0 }
}

/// Extends CGPoint to conform to KineticsValue for 2D point animations.
/// Maps x,y coordinates to/from a two-element components array.
extension CGPoint: KineticsValue, @unchecked Sendable {
    public typealias FloatType = Double
    public var components: [Double] {
        get { [x, y] }
        set {
            x = newValue.count > 0 ? newValue[0] : 0
            y = newValue.count > 1 ? newValue[1] : 0
        }
    }
    public init(components: [Double]) {
        self.init(
            x: components.count > 0 ? components[0] : 0,
            y: components.count > 1 ? components[1] : 0
        )
    }
}

/// Extends CGSize to conform to KineticsValue for 2D size animations.
/// Maps width,height dimensions to/from a two-element components array.
extension CGSize: KineticsValue, @unchecked Sendable {
    public typealias FloatType = Double
    public var components: [Double] {
        get { [width, height] }
        set {
            width = newValue.count > 0 ? newValue[0] : 0
            height = newValue.count > 1 ? newValue[1] : 0
        }
    }
    public init(components: [Double]) {
        self.init(
            width: components.count > 0 ? components[0] : 0,
            height: components.count > 1 ? components[1] : 0
        )
    }
}

/// Extends CGRect to conform to KineticsValue for 2D rectangle animations.
/// Maps origin.x, origin.y, size.width, size.height to/from a four-element components array.
extension CGRect: KineticsValue, @unchecked Sendable {
    public typealias FloatType = Double
    public var components: [Double] {
        get { [origin.x, origin.y, size.width, size.height] }
        set {
            origin.x = newValue.count > 0 ? newValue[0] : 0
            origin.y = newValue.count > 1 ? newValue[1] : 0
            size.width = newValue.count > 2 ? newValue[2] : 0
            size.height = newValue.count > 3 ? newValue[3] : 0
        }
    }
    public init(components: [Double]) {
        self.init(
            x: components.count > 0 ? components[0] : 0,
            y: components.count > 1 ? components[1] : 0,
            width: components.count > 2 ? components[2] : 0,
            height: components.count > 3 ? components[3] : 0
        )
    }
}




