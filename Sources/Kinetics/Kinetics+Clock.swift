import Foundation
import SwiftUI

/// Protocol for objects that need to receive frame-based updates
/// Used by the shared frame clock to coordinate animation timing
@MainActor
internal protocol _KineticsTickSubscriber: AnyObject { 
    func _kineticsTick(dt: Double) 
}

/// Centralized frame clock that manages timing for all spring animations.
/// Provides consistent frame rate and delta time calculations across the app.
@MainActor
internal final class KineticsFrameClock {
    /// Shared instance used by all animators
    static let shared = KineticsFrameClock()

    /// Weak references to subscribers to avoid retain cycles
    private struct WeakBox { weak var obj: (any _KineticsTickSubscriber)? }
    private var subs: [ObjectIdentifier: WeakBox] = [:]
    
    /// Background task that runs the animation loop
    private var loop: Task<Void, Never>?
    
    /// Last frame timestamp for delta time calculation
    private var lastInstant: ContinuousClock.Instant?

    /// Maximum allowed delta time to prevent large jumps after app suspension
    private let maxDelta: Double = 1.0 / 30.0 // clamp dt to ~33ms
    
    /// Target frame rate - set high to allow OS to optimize
    private let targetHz: Double = 120.0 // aim high; OS may coalesce

    /// Adds a subscriber to receive frame updates
    func add(_ s: any _KineticsTickSubscriber) {
        subs[ObjectIdentifier(s)] = WeakBox(obj: s)
        startIfNeeded()
    }

    /// Removes a subscriber from frame updates
    func remove(_ s: any _KineticsTickSubscriber) {
        subs.removeValue(forKey: ObjectIdentifier(s))
        stopIfIdle()
    }

    /// Starts the animation loop if there are active subscribers
    private func startIfNeeded() {
        guard loop == nil, subs.contains(where: { $0.value.obj != nil }) else { return }
        let clock = ContinuousClock()
        lastInstant = clock.now
        loop = Task { @MainActor [weak self] in
            guard let self else { return }
            let sleepNanos = UInt64(1_000_000_000.0 / targetHz)
            
            // Main animation loop
            while !Task.isCancelled, subs.contains(where: { $0.value.obj != nil }) {
                try? await Task.sleep(nanoseconds: sleepNanos)
                let now = clock.now
                guard let last = lastInstant else { lastInstant = now; continue }
                
                // Calculate delta time with safety bounds
                let dt = min(max(now.durationSince(last).seconds, 0), maxDelta)
                lastInstant = now

                // Update all active subscribers
                // Use snapshot iteration to allow removal during enumeration
                for (key, box) in subs {
                    if let obj = box.obj {
                        obj._kineticsTick(dt: dt)
                    } else {
                        // Clean up weak references
                        subs.removeValue(forKey: key)
                    }
                }
                stopIfIdle()
            }
            stop()
        }
    }

    /// Stops the loop if no active subscribers remain
    private func stopIfIdle() {
        if subs.values.allSatisfy({ $0.obj == nil }) { subs.removeAll() }
        if subs.isEmpty { stop() }
    }

    /// Stops the animation loop and cleans up resources
    private func stop() {
        loop?.cancel()
        loop = nil
        lastInstant = nil
    }
}

// MARK: - Time Extensions

/// Extension to calculate duration between two instants
private extension ContinuousClock.Instant {
    func durationSince(_ earlier: ContinuousClock.Instant) -> Duration { 
        self - earlier 
    }
}

/// Extension to convert Duration to seconds as Double
private extension Duration {
    var seconds: Double {
        let c = components
        return Double(c.seconds) + Double(c.attoseconds) / 1_000_000_000_000_000_000.0
    }
}
