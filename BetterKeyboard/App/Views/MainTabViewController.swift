import UIKit

final class MainTabViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let homeVC = HomeViewController()
        homeVC.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        let settingsVC = SettingsViewController(style: .insetGrouped)
        settingsVC.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        let homeNav = UINavigationController(rootViewController: homeVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)

        viewControllers = [homeNav, settingsNav]

        tabBar.tintColor = .systemBlue
    }

    /// Navigate to the settings tab programmatically (used by deep links).
    func showSettings() {
        selectedIndex = 1
    }
}
