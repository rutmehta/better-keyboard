import Foundation

/// All discrete haptic events the keyboard can trigger.
/// Each case maps to a specific generator type and base intensity
/// defined in HapticEngine.
enum HapticFeedbackType {
    case keyTap
    case space
    case delete
    case shiftToggle
    case modeSwitch
    case swipeComplete
    case suggestionSelect
    case error
}
