import UIKit

/// Protocol for the AI analysis service. The AI pipeline agent provides the concrete implementation.
protocol AIAnalysisService {
    func analyzeRecentScreenshots() async throws -> AIAnalysisResult
}

/// Routes deep link URLs to the appropriate app flow.
final class DeepLinkHandler {

    static let shared = DeepLinkHandler()

    /// Injected AI analysis service. Set this on app launch when the AI pipeline is available.
    var analysisService: AIAnalysisService?

    private init() {}

    // MARK: - URL Handling

    /// Parse and route a deep link URL.
    /// Expected format: betterkeyboard://analyze  or  betterkeyboard://settings
    func handle(url: URL) {
        guard url.scheme == AppConstants.deepLinkScheme else { return }

        let host = url.host ?? ""
        switch host {
        case AppConstants.DeepLink.analyze:
            handleAnalyze()
        case AppConstants.DeepLink.settings:
            handleSettings()
        default:
            break
        }
    }

    // MARK: - Analyze Flow

    /// Trigger the screenshot analysis pipeline. Can be called directly from the Home screen
    /// or from an incoming deep link.
    func triggerAnalysis(from viewController: UIViewController) {
        guard let service = analysisService else {
            showAlert(on: viewController, title: "AI Not Available", message: "The AI analysis engine is not configured yet.")
            return
        }

        let activityIndicator = showActivityOverlay(on: viewController)

        Task {
            do {
                let result = try await service.analyzeRecentScreenshots()
                // Note: The coordinator already saves results to SharedSettings
                // as part of its pipeline, so no extra save needed here.

                await MainActor.run {
                    activityIndicator.removeFromSuperview()
                    showCompletionAlert(on: viewController, result: result)
                }
            } catch {
                await MainActor.run {
                    activityIndicator.removeFromSuperview()
                    showAlert(on: viewController, title: "Analysis Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Private Routing

    private func handleAnalyze() {
        guard let viewController = topViewController() else { return }
        triggerAnalysis(from: viewController)
    }

    private func handleSettings() {
        guard let tabBar = findMainTabController() else { return }
        tabBar.showSettings()
    }

    // MARK: - UI Helpers

    private func showActivityOverlay(on viewController: UIViewController) -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.frame = viewController.view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.center = overlay.center
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Analyzing screenshots..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.sizeToFit()
        label.center = CGPoint(x: overlay.center.x, y: overlay.center.y + 40)
        label.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]

        overlay.addSubview(spinner)
        overlay.addSubview(label)
        viewController.view.addSubview(overlay)

        return overlay
    }

    private func showCompletionAlert(on viewController: UIViewController, result: AIAnalysisResult) {
        let replyPreview = result.replies.prefix(3).map(\.text).joined(separator: "\n\n")

        let alert = UIAlertController(
            title: "AI Replies Ready",
            message: "Generated \(result.replies.count) replies. Switch back to the keyboard to use them.\n\n\(replyPreview)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }

    private func showAlert(on viewController: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }

    // MARK: - View Controller Discovery

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        return findTopPresented(from: rootVC)
    }

    private func findTopPresented(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return findTopPresented(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return findTopPresented(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTopPresented(from: selected)
        }
        return vc
    }

    private func findMainTabController() -> MainTabViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        return rootVC as? MainTabViewController
    }
}
