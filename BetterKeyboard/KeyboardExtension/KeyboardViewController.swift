import UIKit

/// Main keyboard view controller. Subclasses UIInputViewController to provide
/// a fully custom QWERTY keyboard with swipe support, haptics, and AI integration.
final class KeyboardViewController: UIInputViewController {

    // MARK: - UI Components

    private let suggestionBar = SuggestionBarView()
    private let layoutView = KeyboardLayoutView()

    // MARK: - State

    private var shiftState: ShiftState = .lower
    private var lastShiftTapTime: Date?

    /// Tracks whether the current touch sequence is a swipe (moved significantly)
    /// vs a simple tap. The input engine will use this to decide between character
    /// insertion and swipe decoding.
    private var isSwipeActive = false
    private var swipeStartPoint: CGPoint?
    private let swipeThreshold: CGFloat = 20 // points moved before treated as swipe

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let inputView = self.inputView else { return }
        inputView.allowsSelfSizing = true

        setupSuggestionBar(in: inputView)
        setupLayoutView(in: inputView)
        applyThemeFromSettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        HapticEngine.shared.prepare()
        applyThemeFromSettings()
        checkForPendingAIReplies()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        HapticEngine.shared.suspend()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.view.layoutIfNeeded()
        })
    }

    // MARK: - Globe / Input Mode Switch

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyThemeFromSettings()
    }

    // MARK: - Setup

    private func setupSuggestionBar(in container: UIView) {
        suggestionBar.actionDelegate = self
        container.addSubview(suggestionBar)

        NSLayoutConstraint.activate([
            suggestionBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            suggestionBar.topAnchor.constraint(equalTo: container.topAnchor),
        ])
    }

    private func setupLayoutView(in container: UIView) {
        layoutView.actionDelegate = self
        container.addSubview(layoutView)

        // Keyboard height varies by device; 216pt is the standard iPhone portrait height.
        // The suggestion bar sits above, so total = 44 + 216 = 260pt.
        let keyboardHeight: CGFloat = 216

        NSLayoutConstraint.activate([
            layoutView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            layoutView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            layoutView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            layoutView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            layoutView.heightAnchor.constraint(equalToConstant: keyboardHeight),
        ])
    }

    // MARK: - Theme

    private func applyThemeFromSettings() {
        let theme = SharedSettings.shared.keyboardTheme
        let isDark: Bool

        switch theme {
        case .dark:
            isDark = true
        case .light:
            isDark = false
        case .system:
            isDark = traitCollection.userInterfaceStyle == .dark
        }

        layoutView.applyTheme(dark: isDark)
        suggestionBar.applyTheme(dark: isDark)
        inputView?.backgroundColor = isDark
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyThemeFromSettings()
        }
    }

    // MARK: - AI Reply Check

    private func checkForPendingAIReplies() {
        if let result = SharedSettings.shared.consumeAIReplies() {
            let candidates = result.replies.map { $0.text }
            suggestionBar.updateSuggestions(Array(candidates.prefix(3)))
        }
    }

    // MARK: - Shift Logic

    private func cycleShift() {
        let now = Date()

        // Double-tap detection for caps lock
        if let lastTap = lastShiftTapTime,
           now.timeIntervalSince(lastTap) < 0.35 {
            shiftState = (shiftState == .capsLock) ? .lower : .capsLock
            lastShiftTapTime = nil
        } else {
            switch shiftState {
            case .lower:
                shiftState = .upper
            case .upper:
                shiftState = .lower
            case .capsLock:
                shiftState = .lower
            }
            lastShiftTapTime = now
        }

        layoutView.updateShift(shiftState)
    }

    /// Auto-return to lowercase after inserting a character (unless caps lock).
    private func autoLowercaseIfNeeded() {
        if shiftState == .upper {
            shiftState = .lower
            layoutView.updateShift(shiftState)
        }
    }

    // MARK: - Haptic Helper

    private func haptic(_ type: HapticFeedbackType) {
        HapticEngine.shared.trigger(type, hasFullAccess: hasFullAccess)
    }

    // MARK: - Deep Link to Containing App

    private func openContainingApp(intent: String) {
        guard let url = URL(string: "\(AppConstants.deepLinkScheme)://\(intent)?source=keyboard") else { return }

        SharedSettings.shared.setAnalyzeRequestTimestamp()

        // UIInputViewController can open URLs via the shared application
        // through the openURL selector on the parent app.
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }
}

// MARK: - KeyboardActionDelegate

extension KeyboardViewController: KeyboardActionDelegate {

    func didTapCharacter(_ char: String) {
        guard !isSwipeActive else { return }
        textDocumentProxy.insertText(char)
        haptic(.keyTap)
        autoLowercaseIfNeeded()
    }

    func didTapSpace() {
        textDocumentProxy.insertText(" ")
        haptic(.space)
        suggestionBar.clearSuggestions()
    }

    func didTapDelete() {
        textDocumentProxy.deleteBackward()
        haptic(.delete)
    }

    func didTapReturn() {
        textDocumentProxy.insertText("\n")
        haptic(.keyTap)
        suggestionBar.clearSuggestions()
    }

    func didTapShift() {
        cycleShift()
        haptic(.shiftToggle)
    }

    func didTapGlobe() {
        advanceToNextInputMode()
    }

    func didTapAI() {
        openContainingApp(intent: AppConstants.DeepLink.analyze)
    }

    func didSelectSuggestion(_ word: String) {
        deleteCurrentPartialWord()
        textDocumentProxy.insertText(word + " ")
        suggestionBar.clearSuggestions()
        haptic(.suggestionSelect)
    }

    // MARK: Swipe Events

    func didBeginSwipe(at point: CGPoint) {
        swipeStartPoint = point
        isSwipeActive = false
    }

    func didContinueSwipe(at point: CGPoint) {
        guard let start = swipeStartPoint else { return }
        let dx = point.x - start.x
        let dy = point.y - start.y
        if sqrt(dx * dx + dy * dy) > swipeThreshold {
            isSwipeActive = true
        }
        if isSwipeActive {
            NotificationCenter.default.post(
                name: .swipeContinued,
                object: nil,
                userInfo: ["point": NSValue(cgPoint: point)]
            )
        }
    }

    func didEndSwipe(at point: CGPoint) {
        if isSwipeActive {
            NotificationCenter.default.post(
                name: .swipeEnded,
                object: nil,
                userInfo: ["point": NSValue(cgPoint: point)]
            )
            haptic(.swipeComplete)
        }
        isSwipeActive = false
        swipeStartPoint = nil
    }

    // MARK: Helpers

    private func deleteCurrentPartialWord() {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return }
        var count = 0
        for char in context.reversed() {
            if char == " " || char == "\n" { break }
            count += 1
        }
        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
    }
}

// MARK: - SuggestionDelegate

extension KeyboardViewController: SuggestionDelegate {
    func updateSuggestions(_ candidates: [String]) {
        suggestionBar.updateSuggestions(candidates)
    }

    func clearSuggestions() {
        suggestionBar.clearSuggestions()
    }
}

// MARK: - Notification Names (for swipe events consumed by InputEngine)

extension Notification.Name {
    static let swipeContinued = Notification.Name("BK_swipeContinued")
    static let swipeEnded = Notification.Name("BK_swipeEnded")
}
