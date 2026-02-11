import UIKit

/// Manages all haptic feedback for the keyboard extension.
///
/// Lifecycle:
/// - Call `prepare()` in `viewWillAppear` to arm generators.
/// - Call `suspend()` in `viewDidDisappear` to deallocate motor resources.
/// - Automatically suspends after 5 seconds of inactivity and re-prepares on next trigger.
///
/// Requires Full Access to be enabled (`hasFullAccess == true`).
final class HapticEngine {

    // MARK: - Singleton

    static let shared = HapticEngine()

    // MARK: - Generators

    private var impactGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?

    // MARK: - State

    private var isPrepared = false
    private var inactivityTimer: Timer?

    /// Seconds of idle time before generators are automatically suspended.
    private let inactivityTimeout: TimeInterval = 5.0

    // MARK: - Base Intensities

    /// Base intensities per feedback type (used at the "light" setting level).
    private func baseIntensity(for type: HapticFeedbackType) -> CGFloat {
        switch type {
        case .keyTap:          return 0.5
        case .space:           return 0.7
        case .delete:          return 0.6
        case .shiftToggle:     return 0.4
        case .modeSwitch:      return 0.3
        case .suggestionSelect: return 0.8
        // Selection and notification generators don't use a CGFloat intensity.
        case .swipeComplete, .error:
            return 0
        }
    }

    /// Multiplier derived from the user's haptic intensity setting.
    private var intensityMultiplier: CGFloat {
        switch SharedSettings.shared.hapticIntensity {
        case .off:    return 0
        case .light:  return 1.0
        case .medium: return 1.3
        case .strong: return 1.6
        }
    }

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Allocate and pre-arm all feedback generators.
    /// Call from `KeyboardViewController.viewWillAppear`.
    func prepare() {
        guard SharedSettings.shared.hapticIntensity != .off else { return }

        if isPrepared { return }

        impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator?.prepare()

        selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator?.prepare()

        notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator?.prepare()

        isPrepared = true
    }

    /// Deallocate all generators to free the Taptic Engine.
    /// Call from `KeyboardViewController.viewDidDisappear`.
    func suspend() {
        cancelInactivityTimer()
        impactGenerator = nil
        selectionGenerator = nil
        notificationGenerator = nil
        isPrepared = false
    }

    /// Trigger haptic feedback for a given event type.
    /// - Parameter type: The keyboard event that occurred.
    /// - Parameter hasFullAccess: Pass `self.hasFullAccess` from UIInputViewController.
    func trigger(_ type: HapticFeedbackType, hasFullAccess: Bool) {
        guard hasFullAccess else { return }
        guard SharedSettings.shared.hapticIntensity != .off else { return }

        // Lazily re-prepare if we were auto-suspended due to inactivity.
        if !isPrepared {
            prepare()
        }

        resetInactivityTimer()

        switch type {
        case .swipeComplete:
            selectionGenerator?.selectionChanged()
            selectionGenerator?.prepare()

        case .error:
            notificationGenerator?.notificationOccurred(.error)
            notificationGenerator?.prepare()

        default:
            let scaled = min(baseIntensity(for: type) * intensityMultiplier, 1.0)
            impactGenerator?.impactOccurred(intensity: scaled)
            impactGenerator?.prepare()
        }
    }

    // MARK: - Inactivity Timer

    private func resetInactivityTimer() {
        cancelInactivityTimer()
        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: inactivityTimeout,
            repeats: false
        ) { [weak self] _ in
            self?.suspend()
        }
    }

    private func cancelInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
}
