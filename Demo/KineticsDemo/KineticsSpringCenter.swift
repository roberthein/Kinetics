import SwiftUI
import Kinetics

@MainActor
public final class KineticsSpringCenter: ObservableObject {

    /// Global shared instance. Inject it with `.environmentObject(KineticsSpringCenter.shared)`.
    public static let shared = KineticsSpringCenter(spring: KineticsSpring.playful)

    /// The current spring configuration.
    @Published public private(set) var spring: KineticsSpring

    public init(spring: KineticsSpring) { self.spring = spring }

    // MARK: Mutations

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
            .onAppear { animator.updateSpring(center.spring) }  // initial sync
            .onReceive(center.$spring) { animator.updateSpring($0) } // live updates
    }
}

public extension View {
    /// Keep a `SpringAnimator`'s spring in sync with the `KineticsSpringCenter` environment object.
    func bindSpring<Value: KineticsValue>(to animator: SpringAnimator<Value>) -> some View where Value.FloatType == Double {
        modifier(KineticsSpringBinder(animator: animator))
    }
}
