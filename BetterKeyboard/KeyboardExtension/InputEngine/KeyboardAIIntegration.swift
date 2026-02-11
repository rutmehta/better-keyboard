import UIKit

/// State of the AI analysis flow from the keyboard extension's perspective.
enum AIIntegrationState {
    case idle
    case waitingForResults
    case repliesAvailable(AIAnalysisResult)
    case error(String)
}

/// Lightweight AI integration for the keyboard extension side.
/// Handles the app-jump flow, polling for results, and formatting replies for display.
final class KeyboardAIIntegration {

    private let settings = SharedSettings.shared

    /// Current state of the AI integration flow.
    private(set) var state: AIIntegrationState = .idle

    // MARK: - Deep Link

    /// Construct the deep link URL to trigger analysis in the containing app.
    var analyzeDeepLinkURL: URL {
        var components = URLComponents()
        components.scheme = AppConstants.deepLinkScheme
        components.host = AppConstants.DeepLink.analyze
        components.queryItems = [
            URLQueryItem(name: "source", value: "keyboard"),
            URLQueryItem(name: "timestamp", value: "\(Date().timeIntervalSince1970)")
        ]
        return components.url!
    }

    // MARK: - Trigger Analysis

    /// Trigger the app-jump to the containing app for screenshot analysis.
    /// Call this when the user taps the AI button in the keyboard.
    func triggerAnalysis(from viewController: UIInputViewController) {
        settings.setAnalyzeRequestTimestamp()
        state = .waitingForResults

        // Walk the responder chain to find the app-level URL opener.
        // Keyboard extensions cannot call UIApplication.shared.open() directly,
        // so we use the private openURL: selector via the responder chain.
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = viewController
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: analyzeDeepLinkURL)
                return
            }
            responder = r.next
        }

        state = .error("Could not open containing app")
    }

    // MARK: - Read Results

    /// Check whether AI replies are available without consuming them.
    var hasPendingReplies: Bool {
        // Peek at the shared container without removing data.
        // consumeAIReplies() deletes the entry, so we check the raw key instead.
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        return defaults?.data(forKey: AppConstants.UserDefaultsKey.pendingAIReplies) != nil
    }

    /// Read and consume pending AI replies from the shared container.
    /// Returns nil if no results are available yet.
    func fetchReplies() -> AIAnalysisResult? {
        guard let result = settings.consumeAIReplies() else { return nil }
        state = .repliesAvailable(result)
        return result
    }

    /// Format AI replies for display in the suggestion bar.
    /// Returns an array of reply text strings, limited to 3.
    func formattedRepliesForSuggestionBar(_ result: AIAnalysisResult) -> [String] {
        result.replies.prefix(3).map(\.text)
    }

    // MARK: - Polling

    /// Poll for AI results after returning from the containing app.
    /// Checks every 0.5 seconds up to the timeout.
    func pollForReplies(timeout: TimeInterval = 5.0) async -> AIAnalysisResult? {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if let result = fetchReplies() {
                return result
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        state = .error("Timed out waiting for AI results")
        return nil
    }

    // MARK: - Reset

    /// Reset state to idle (e.g., when the user dismisses the AI panel).
    func reset() {
        state = .idle
    }
}
