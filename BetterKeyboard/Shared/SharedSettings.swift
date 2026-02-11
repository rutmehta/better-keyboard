import Foundation

/// Thread-safe read/write access to App Groups shared settings.
/// Used by both the containing app and the keyboard extension.
final class SharedSettings {
    static let shared = SharedSettings()

    private let defaults: UserDefaults

    private init() {
        guard let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) else {
            fatalError("Failed to initialize App Groups UserDefaults with suite: \(AppConstants.appGroupIdentifier)")
        }
        self.defaults = defaults
    }

    // MARK: - Settings

    var hapticIntensity: HapticIntensity {
        get {
            guard let raw = defaults.string(forKey: AppConstants.UserDefaultsKey.hapticIntensity),
                  let value = HapticIntensity(rawValue: raw) else { return .light }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: AppConstants.UserDefaultsKey.hapticIntensity) }
    }

    var swipeSensitivity: SwipeSensitivity {
        get {
            guard let raw = defaults.string(forKey: AppConstants.UserDefaultsKey.swipeSensitivity),
                  let value = SwipeSensitivity(rawValue: raw) else { return .medium }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: AppConstants.UserDefaultsKey.swipeSensitivity) }
    }

    var aiStyle: ReplyStyle {
        get {
            guard let raw = defaults.string(forKey: AppConstants.UserDefaultsKey.aiStyle),
                  let value = ReplyStyle(rawValue: raw) else { return .auto }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: AppConstants.UserDefaultsKey.aiStyle) }
    }

    var keyboardTheme: KeyboardTheme {
        get {
            guard let raw = defaults.string(forKey: AppConstants.UserDefaultsKey.keyboardTheme),
                  let value = KeyboardTheme(rawValue: raw) else { return .system }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: AppConstants.UserDefaultsKey.keyboardTheme) }
    }

    var quickSuggestionsEnabled: Bool {
        get { defaults.object(forKey: AppConstants.UserDefaultsKey.quickSuggestions) as? Bool ?? true }
        set { defaults.set(newValue, forKey: AppConstants.UserDefaultsKey.quickSuggestions) }
    }

    var screenshotHistoryLimit: Int {
        get {
            let val = defaults.integer(forKey: AppConstants.UserDefaultsKey.screenshotHistoryLimit)
            return val > 0 ? val : 10
        }
        set { defaults.set(newValue, forKey: AppConstants.UserDefaultsKey.screenshotHistoryLimit) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: AppConstants.UserDefaultsKey.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: AppConstants.UserDefaultsKey.hasCompletedOnboarding) }
    }

    // MARK: - Keyboard <-> App Communication

    /// Save AI analysis results for the keyboard extension to pick up.
    func saveAIReplies(_ result: AIAnalysisResult) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        defaults.set(data, forKey: AppConstants.UserDefaultsKey.pendingAIReplies)
    }

    /// Read and consume pending AI replies (called by keyboard extension).
    func consumeAIReplies() -> AIAnalysisResult? {
        guard let data = defaults.data(forKey: AppConstants.UserDefaultsKey.pendingAIReplies),
              let result = try? JSONDecoder().decode(AIAnalysisResult.self, from: data) else {
            return nil
        }
        defaults.removeObject(forKey: AppConstants.UserDefaultsKey.pendingAIReplies)
        return result
    }

    func setAnalyzeRequestTimestamp() {
        defaults.set(Date().timeIntervalSince1970, forKey: AppConstants.UserDefaultsKey.analyzeRequestTimestamp)
    }
}
