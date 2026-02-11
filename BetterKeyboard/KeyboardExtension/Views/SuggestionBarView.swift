import UIKit

/// Horizontal bar displayed above the keyboard rows showing the top 3 swipe/autocorrect
/// candidates and an AI sparkle button on the trailing edge.
final class SuggestionBarView: UIView {

    // MARK: - Properties

    weak var actionDelegate: KeyboardActionDelegate?

    private let stackView = UIStackView()
    private var suggestionButtons: [UIButton] = []
    private let aiButton = UIButton(type: .system)
    private let separatorLeft = UIView()
    private let separatorRight = UIView()

    static let barHeight: CGFloat = 44

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.barHeight).isActive = true

        // Main horizontal stack: [suggestions ...] [AI button]
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 0
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Create 3 suggestion buttons with separators between them
        for i in 0..<3 {
            let btn = makeSuggestionButton()
            btn.tag = i
            suggestionButtons.append(btn)
            stackView.addArrangedSubview(btn)

            if i < 2 {
                let sep = makeSeparator()
                stackView.addArrangedSubview(sep)
            }
        }

        // Trailing separator before AI button
        let trailingSep = makeSeparator()
        stackView.addArrangedSubview(trailingSep)

        // AI button
        setupAIButton()
        stackView.addArrangedSubview(aiButton)

        // Make suggestion buttons share equal width; AI button fixed
        for btn in suggestionButtons {
            btn.widthAnchor.constraint(equalTo: suggestionButtons[0].widthAnchor).isActive = true
        }
        aiButton.widthAnchor.constraint(equalToConstant: 48).isActive = true

        // Bottom separator line
        let bottomLine = UIView()
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = UIColor.separator
        addSubview(bottomLine)
        NSLayoutConstraint.activate([
            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func makeSuggestionButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.setTitleColor(.label, for: .normal)
        btn.setTitle("", for: .normal)
        btn.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.separator
        v.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    private func setupAIButton() {
        aiButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        aiButton.setImage(UIImage(systemName: "sparkles", withConfiguration: config), for: .normal)
        aiButton.tintColor = .systemBlue
        aiButton.addTarget(self, action: #selector(aiTapped), for: .touchUpInside)
    }

    // MARK: - Public API

    func updateSuggestions(_ candidates: [String]) {
        for (i, btn) in suggestionButtons.enumerated() {
            if i < candidates.count {
                btn.setTitle(candidates[i], for: .normal)
                btn.isHidden = false
            } else {
                btn.setTitle("", for: .normal)
            }
        }
    }

    func clearSuggestions() {
        for btn in suggestionButtons {
            btn.setTitle("", for: .normal)
        }
    }

    func applyTheme(dark: Bool) {
        backgroundColor = dark
            ? UIColor(white: 0.18, alpha: 1)
            : UIColor(white: 0.96, alpha: 1)
    }

    // MARK: - Actions

    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let word = sender.title(for: .normal), !word.isEmpty else { return }
        actionDelegate?.didSelectSuggestion(word)
    }

    @objc private func aiTapped() {
        actionDelegate?.didTapAI()
    }
}
