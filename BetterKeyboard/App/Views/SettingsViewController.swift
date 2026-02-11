import UIKit

final class SettingsViewController: UITableViewController {

    // MARK: - Data Model

    private enum Section: Int, CaseIterable {
        case typing
        case aiFeatures
        case appearance
        case about
    }

    private enum Row {
        case hapticIntensity
        case swipeSensitivity
        case defaultAIStyle
        case quickSuggestions
        case screenshotHistoryLimit
        case keyboardTheme
        case version
        case privacyPolicy
        case rateApp
    }

    private let sections: [(section: Section, title: String, rows: [Row])] = [
        (.typing, "Typing", [.hapticIntensity, .swipeSensitivity]),
        (.aiFeatures, "AI Features", [.defaultAIStyle, .quickSuggestions, .screenshotHistoryLimit]),
        (.appearance, "Appearance", [.keyboardTheme]),
        (.about, "About", [.version, .privacyPolicy, .rateApp]),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .none

        var content = cell.defaultContentConfiguration()

        switch row {
        case .hapticIntensity:
            content.text = "Haptic Intensity"
            content.secondaryText = SharedSettings.shared.hapticIntensity.rawValue.capitalized
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .swipeSensitivity:
            content.text = "Swipe Sensitivity"
            content.secondaryText = SharedSettings.shared.swipeSensitivity.rawValue.capitalized
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .defaultAIStyle:
            content.text = "Default AI Style"
            content.secondaryText = displayName(for: SharedSettings.shared.aiStyle)
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .quickSuggestions:
            content.text = "Quick Suggestions"
            let toggle = UISwitch()
            toggle.isOn = SharedSettings.shared.quickSuggestionsEnabled
            toggle.addTarget(self, action: #selector(quickSuggestionsToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle

        case .screenshotHistoryLimit:
            content.text = "Screenshot History Limit"
            content.secondaryText = "\(SharedSettings.shared.screenshotHistoryLimit)"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .keyboardTheme:
            content.text = "Keyboard Theme"
            content.secondaryText = SharedSettings.shared.keyboardTheme.rawValue.capitalized
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .version:
            content.text = "Version"
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            content.secondaryText = "\(version) (\(build))"

        case .privacyPolicy:
            content.text = "Privacy Policy"
            content.image = UIImage(systemName: "hand.raised")
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .rateApp:
            content.text = "Rate BetterKeyboard"
            content.image = UIImage(systemName: "star")
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }

        cell.contentConfiguration = content
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row {
        case .hapticIntensity:
            showPicker(
                title: "Haptic Intensity",
                options: HapticIntensity.allCases.map { ($0.rawValue.capitalized, $0.rawValue) },
                current: SharedSettings.shared.hapticIntensity.rawValue
            ) { selected in
                if let val = HapticIntensity(rawValue: selected) {
                    SharedSettings.shared.hapticIntensity = val
                }
            }

        case .swipeSensitivity:
            showPicker(
                title: "Swipe Sensitivity",
                options: SwipeSensitivity.allCases.map { ($0.rawValue.capitalized, $0.rawValue) },
                current: SharedSettings.shared.swipeSensitivity.rawValue
            ) { selected in
                if let val = SwipeSensitivity(rawValue: selected) {
                    SharedSettings.shared.swipeSensitivity = val
                }
            }

        case .defaultAIStyle:
            showPicker(
                title: "Default AI Style",
                options: ReplyStyle.allCases.map { (displayName(for: $0), $0.rawValue) },
                current: SharedSettings.shared.aiStyle.rawValue
            ) { selected in
                if let val = ReplyStyle(rawValue: selected) {
                    SharedSettings.shared.aiStyle = val
                }
            }

        case .screenshotHistoryLimit:
            showPicker(
                title: "Screenshot History Limit",
                options: [("5", "5"), ("10", "10"), ("20", "20"), ("Don't keep", "0")],
                current: "\(SharedSettings.shared.screenshotHistoryLimit)"
            ) { selected in
                if let val = Int(selected) {
                    SharedSettings.shared.screenshotHistoryLimit = val
                }
            }

        case .keyboardTheme:
            showPicker(
                title: "Keyboard Theme",
                options: KeyboardTheme.allCases.map { ($0.rawValue.capitalized, $0.rawValue) },
                current: SharedSettings.shared.keyboardTheme.rawValue
            ) { selected in
                if let val = KeyboardTheme(rawValue: selected) {
                    SharedSettings.shared.keyboardTheme = val
                }
            }

        case .privacyPolicy:
            // Placeholder: open a privacy policy URL
            if let url = URL(string: "https://betterkeyboard.app/privacy") {
                UIApplication.shared.open(url)
            }

        case .rateApp:
            // Placeholder: open App Store review URL
            if let url = URL(string: "https://apps.apple.com/app/id0000000000?action=write-review") {
                UIApplication.shared.open(url)
            }

        default:
            break
        }
    }

    // MARK: - Toggle Actions

    @objc private func quickSuggestionsToggled(_ sender: UISwitch) {
        SharedSettings.shared.quickSuggestionsEnabled = sender.isOn
    }

    // MARK: - Picker Sheet

    private func showPicker(
        title: String,
        options: [(display: String, value: String)],
        current: String,
        onSelect: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        for option in options {
            let action = UIAlertAction(title: option.display, style: .default) { [weak self] _ in
                onSelect(option.value)
                self?.tableView.reloadData()
            }
            if option.value == current {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad popover support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func displayName(for style: ReplyStyle) -> String {
        switch style {
        case .flirty: return "Flirty"
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .funny: return "Funny"
        case .auto: return "Auto (by app)"
        }
    }
}
