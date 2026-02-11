import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        if SharedSettings.shared.hasCompletedOnboarding {
            window.rootViewController = MainTabViewController()
        } else {
            window.rootViewController = OnboardingViewController()
        }

        self.window = window
        window.makeKeyAndVisible()

        // Handle deep link that launched the scene
        if let url = connectionOptions.urlContexts.first?.url {
            DeepLinkHandler.shared.handle(url: url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        DeepLinkHandler.shared.handle(url: url)
    }

    /// Transition from onboarding to the main tab bar after the user finishes setup.
    func transitionToMainApp() {
        guard let window else { return }
        let tabVC = MainTabViewController()
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = tabVC
        }
    }
}
