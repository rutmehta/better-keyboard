import Foundation

/// Central constants shared between the containing app and keyboard extension.
enum AppConstants {
    static let appGroupIdentifier = "group.com.betterkeyboard.shared"
    static let bundleIdentifier = "com.betterkeyboard.app"
    static let keyboardBundleIdentifier = "com.betterkeyboard.app.keyboard"
    static let deepLinkScheme = "betterkeyboard"

    enum UserDefaultsKey {
        static let hapticIntensity = "haptic_intensity"
        static let swipeSensitivity = "swipe_sensitivity"
        static let aiStyle = "ai_style"
        static let keyboardTheme = "keyboard_theme"
        static let quickSuggestions = "quick_suggestions"
        static let screenshotHistoryLimit = "screenshot_history_limit"
        static let hasCompletedOnboarding = "has_completed_onboarding"
        static let fullAccessEnabled = "full_access_enabled"

        // Keyboard <-> App communication
        static let pendingAIReplies = "pending_ai_replies"
        static let analyzeRequestTimestamp = "analyze_request_timestamp"
        static let lastAnalyzedText = "last_analyzed_text"
    }

    enum DeepLink {
        static let analyze = "analyze"
        static let settings = "settings"
    }
}
