import Foundation
import SwiftUI

/// SwiftUI-native modifier that provides spring animation with automatic lifecycle management.
/// Binds target, current, spring, and boundary values, emitting a single `onEvent` callback.
/// Handles view appearance/disappearance and state changes automatically.
public struct KineticsModifier<Value: KineticsValue>: ViewModifier {
    @Binding private var target: Value
    @Binding private var current: Value
    @Binding private var spring: KineticsSpring
    private var boundary: KineticsBoundary<Value>
    private let onEvent: ((KineticsUpdate<Value>) -> Void)?

    @StateObject private var animator: SpringAnimator<Value>
    @State private var task: Task<Void, Never>?

    public init(
        target: Binding<Value>,
        current: Binding<Value>,
        spring: Binding<KineticsSpring>,
        boundary: KineticsBoundary<Value> = .none,
        onEvent: ((KineticsUpdate<Value>) -> Void)? = nil
    ) {
        self._target = target
        self._current = current
        self._spring = spring
        self.boundary = boundary
        self.onEvent = onEvent

        // Create animator with automatic current value updates
        _animator = StateObject(
            wrappedValue: SpringAnimator<Value>(
                initialValue: current.wrappedValue,
                spring: spring.wrappedValue,
                boundary: boundary,
                onEvent: { update in
                    current.wrappedValue = update.current
                    onEvent?(update)
                }
            )
        )
    }

    public func body(content: Content) -> some View {
        content
            .onAppear { restart(reason: "onAppear") }
            .onChange(of: target) { _, _ in restart(reason: "target changed") }
            .onChange(of: spring) { _, new in
                animator.updateSpring(new)
                restart(reason: "spring changed")
            }
            .onDisappear { cancel() }
    }

    /// Restarts the animation with current configuration.
    /// Called when the view appears or when key parameters change.
    private func restart(reason: String) {
        cancel()
        task = Task { @MainActor in
            guard !Task.isCancelled else { return }
            animator.boundary = boundary
            if animator.state != .idle { await animator.stop() }
            animator.setValue(current) // start from bound current value
            await animator.animate(to: target) // rubber boundary computes constrained target
        }
    }

    /// Cancels any running animation and stops the animator.
    /// Called when the view disappears or when restarting.
    private func cancel() {
        task?.cancel()
        task = nil
        Task { @MainActor in if animator.state != .idle { await animator.stop() } }
    }
}

// MARK: - View Extensions

public extension View {
    /// Adds spring animation with automatic lifecycle management.
    /// Animates `current` → `target` using the specified spring and boundary configuration.
    /// 
    /// - `target`: The destination value to animate toward
    /// - `current`: The current value that will be updated during animation
    /// - `spring`: Spring configuration that controls animation behavior
    /// - `boundary`: Optional boundary constraints (bounce, rubber band, etc.)
    /// - `onEvent`: Optional callback for animation progress updates
    func kinetics<Value: KineticsValue>(
        target: Binding<Value>,
        current: Binding<Value>,
        spring: Binding<KineticsSpring>,
        boundary: KineticsBoundary<Value> = .none,
        onEvent: ((KineticsUpdate<Value>) -> Void)? = nil
    ) -> some View {
        modifier(KineticsModifier(target: target, current: current, spring: spring, boundary: boundary, onEvent: onEvent))
    }
}
