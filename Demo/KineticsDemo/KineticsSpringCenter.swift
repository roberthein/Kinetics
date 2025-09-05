import SwiftUI
import Kinetics

@MainActor
public final class KineticsSpringCenter: ObservableObject {

    public static let shared = KineticsSpringCenter(spring: KineticsSpring.playful)

    @Published public private(set) var spring: KineticsSpring

    public init(spring: KineticsSpring) { self.spring = spring }


    public func set(_ new: KineticsSpring) {
        spring = new
    }

    public func update(
        dampingRatio: Double? = nil,
        response: Double? = nil,
        threshold: Double? = nil
    ) {
        spring = KineticsSpring(
            dampingRatio: dampingRatio ?? spring.dampingRatio,
            response: response ?? spring.response,
            threshold: threshold ?? spring.threshold
        )
    }

    public func applyPreset(_ preset: KineticsSpring) {
        spring = preset
    }

    public var animation: Animation { spring.animation }
}

public struct KineticsSpringBinder<Value: KineticsValue>: ViewModifier where Value.FloatType == Double {
    @EnvironmentObject private var center: KineticsSpringCenter
    @ObservedObject private var animator: SpringAnimator<Value>

    public init(animator: SpringAnimator<Value>) {
        self.animator = animator
    }

    public func body(content: Content) -> some View {
        content
            .onAppear { animator.updateSpring(center.spring) }
            .onReceive(center.$spring) { animator.updateSpring($0) }
    }
}

public extension View {
    func bindSpring<Value: KineticsValue>(to animator: SpringAnimator<Value>) -> some View where Value.FloatType == Double {
        modifier(KineticsSpringBinder(animator: animator))
    }
}
