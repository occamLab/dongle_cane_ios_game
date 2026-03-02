import UIKit
import CoreHaptics

@MainActor
final class HapticsManager {
    static let shared = HapticsManager()

    // UIKit fallback
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    // Core Haptics
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {
        impactGenerator.prepare()
        startHapticsEngineIfNeeded()
    }

    // MARK: - Public API

    func shortPulse() {
        playPattern(pulses: 1, interval: 0.25)
    }

    func doublePulse() {
        playPattern(pulses: 2, interval: 0.25)
    }

    func triplePulse() {
        playPattern(pulses: 3, interval: 0.25)
    }

    /// Optional: call this when entering a screen where haptics are used a lot
    func warmUp() {
        impactGenerator.prepare()
        startHapticsEngineIfNeeded()
    }

    // MARK: - Core Haptics

    private func startHapticsEngineIfNeeded() {
        guard supportsHaptics else { return }
        guard engine == nil else { return }

        do {
            let newEngine = try CHHapticEngine()
            newEngine.isAutoShutdownEnabled = true

            newEngine.stoppedHandler = { [weak self] reason in
                // Engine can stop for many reasons (app backgrounding, system interruption, etc.)
                // We'll lazily restart next time we try to play.
                Task { @MainActor in
                    self?.engine = nil
                }
            }

            newEngine.resetHandler = { [weak self] in
                // Called after an interruption; restart to be ready.
                Task { @MainActor in
                    self?.engine = nil
                    self?.startHapticsEngineIfNeeded()
                }
            }

            try newEngine.start()
            engine = newEngine
        } catch {
            // If Core Haptics fails for any reason, we’ll just fall back to UIKit.
            engine = nil
        }
    }

    private func playPattern(pulses: Int, interval: TimeInterval) {
        guard pulses > 0 else { return }

        if supportsHaptics {
            startHapticsEngineIfNeeded()
            if let engine {
                do {
                    let pattern = try makeImpactLikePattern(pulses: pulses, interval: interval)
                    let player = try engine.makePlayer(with: pattern)
                    try player.start(atTime: 0) // very consistent timing relative to engine clock
                    return
                } catch {
                    // fall through to UIKit fallback
                }
            }
        }

        // UIKit fallback (less precise)
        playUIKitPulses(pulses: pulses, interval: interval)
    }

    /// Builds a "tap" style pattern: sharp transient haptic repeated at fixed intervals.
    private func makeImpactLikePattern(pulses: Int, interval: TimeInterval) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        events.reserveCapacity(pulses)

        // Tweak these to taste; this is a crisp, impact-like tap.
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)

        for i in 0..<pulses {
            let time = TimeInterval(i) * interval
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            )
            events.append(event)
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - UIKit fallback with a more stable timer

    private func playUIKitPulses(pulses: Int, interval: TimeInterval) {
        // Immediate first pulse
        fireUIKitImpact()

        guard pulses > 1 else { return }

        // Use a DispatchSourceTimer instead of asyncAfter for better stability.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        var remaining = pulses - 1

        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.fireUIKitImpact()
            remaining -= 1
            if remaining <= 0 {
                timer.cancel()
            }
        }
        timer.resume()
    }

    private func fireUIKitImpact() {
        impactGenerator.impactOccurred(intensity: 1.0)
        impactGenerator.prepare()
    }
}
