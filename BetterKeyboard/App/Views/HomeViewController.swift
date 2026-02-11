import UIKit

final class HomeViewController: UIViewController {

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let statusCard = UIView()
    private let keyboardStatusLabel = UILabel()
    private let fullAccessStatusLabel = UILabel()

    private let quickActionsCard = UIView()
    private let historyCard = UIView()
    private let historyStack = UIStackView()

    private let checker = KeyboardStatusChecker()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BetterKeyboard"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemGroupedBackground
        layoutUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStatus()
        refreshHistory()
    }

    // MARK: - Layout

    private func layoutUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        contentStack.addArrangedSubview(buildStatusCard())
        contentStack.addArrangedSubview(buildQuickActionsCard())
        contentStack.addArrangedSubview(buildHistoryCard())
    }

    // MARK: - Status Card

    private func buildStatusCard() -> UIView {
        let card = makeCard()

        let headerLabel = UILabel()
        headerLabel.text = "Keyboard Status"
        headerLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let keyboardRow = makeStatusRow(label: keyboardStatusLabel, icon: "keyboard")
        let fullAccessRow = makeStatusRow(label: fullAccessStatusLabel, icon: "lock.shield")

        let stack = UIStackView(arrangedSubviews: [headerLabel, keyboardRow, fullAccessRow])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeStatusRow(label: UILabel, icon: String) -> UIView {
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = .secondaryLabel
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true

        label.font = .systemFont(ofSize: 15)
        label.textColor = .label

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.spacing = 10
        row.alignment = .center
        return row
    }

    // MARK: - Quick Actions Card

    private func buildQuickActionsCard() -> UIView {
        let card = makeCard()

        let headerLabel = UILabel()
        headerLabel.text = "Quick Actions"
        headerLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let aiButton = makeActionButton(title: "Try AI Reply", icon: "sparkles", action: #selector(tryAIReplyTapped))
        let settingsButton = makeActionButton(title: "Customize Settings", icon: "slider.horizontal.3", action: #selector(customizeSettingsTapped))

        let buttonRow = UIStackView(arrangedSubviews: [aiButton, settingsButton])
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 12

        let stack = UIStackView(arrangedSubviews: [headerLabel, buttonRow])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeActionButton(title: String, icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }

    // MARK: - History Card

    private func buildHistoryCard() -> UIView {
        let card = makeCard()

        let headerLabel = UILabel()
        headerLabel.text = "Recent AI Analyses"
        headerLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        historyStack.axis = .vertical
        historyStack.spacing = 8

        let emptyLabel = UILabel()
        emptyLabel.text = "No analyses yet. Try the AI Reply feature!"
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .tertiaryLabel
        emptyLabel.tag = 100

        historyStack.addArrangedSubview(emptyLabel)

        let stack = UIStackView(arrangedSubviews: [headerLabel, historyStack])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    // MARK: - Card Factory

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        return card
    }

    // MARK: - Actions

    @objc private func tryAIReplyTapped() {
        // Trigger the screenshot analysis pipeline via the deep link handler
        DeepLinkHandler.shared.triggerAnalysis(from: self)
    }

    @objc private func customizeSettingsTapped() {
        guard let tabBar = tabBarController as? MainTabViewController else { return }
        tabBar.showSettings()
    }

    // MARK: - Refresh

    private func refreshStatus() {
        let keyboardEnabled = checker.isKeyboardEnabled()
        let fullAccess = checker.isFullAccessEnabled()

        keyboardStatusLabel.text = keyboardEnabled ? "Keyboard is enabled" : "Keyboard not yet enabled"
        keyboardStatusLabel.textColor = keyboardEnabled ? .systemGreen : .systemOrange

        fullAccessStatusLabel.text = fullAccess ? "Full Access granted" : "Full Access not enabled"
        fullAccessStatusLabel.textColor = fullAccess ? .systemGreen : .systemOrange
    }

    private func refreshHistory() {
        // Read the most recent result from shared settings
        guard let result = SharedSettings.shared.consumeAIReplies() else { return }

        // Remove the empty-state label
        if let emptyLabel = historyStack.viewWithTag(100) {
            emptyLabel.removeFromSuperview()
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let replyText = result.replies.map(\.text).joined(separator: "\n")

        let entryLabel = UILabel()
        entryLabel.numberOfLines = 0
        entryLabel.font = .systemFont(ofSize: 14)
        entryLabel.textColor = .secondaryLabel
        entryLabel.text = "\(dateFormatter.string(from: result.timestamp))\n\(replyText)"

        historyStack.insertArrangedSubview(entryLabel, at: 0)
    }
}
