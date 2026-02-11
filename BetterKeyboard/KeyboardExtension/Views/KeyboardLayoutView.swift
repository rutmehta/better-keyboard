import UIKit

/// Programmatic UIKit keyboard layout supporting letters (QWERTY), numbers, and symbols.
/// Uses UIStackView rows with flexible Auto Layout sizing.
final class KeyboardLayoutView: UIView {

    // MARK: - Properties

    weak var actionDelegate: KeyboardActionDelegate?

    private let outerStack = UIStackView()
    private var keyRows: [[KeyView]] = []
    private var allKeyViews: [KeyView] = []

    private(set) var currentMode: KeyboardMode = .letters
    private(set) var shiftState: ShiftState = .lower

    private var isDark: Bool = false
    private var activePopup: AlternateCharsPopup?

    private let rowSpacing: CGFloat = 8
    private let keySpacing: CGFloat = 4
    private let rowHeight: CGFloat = 42
    private let edgeInset: CGFloat = 3

    // MARK: - Layout Definitions

    private static let lettersRows: [[KeyType]] = [
        "QWERTYUIOP".map { .character(String($0)) },
        "ASDFGHJKL".map { .character(String($0)) },
        [.shift] + "ZXCVBNM".map { .character(String($0)) } + [.delete],
    ]

    private static let numbersRows: [[KeyType]] = [
        "1234567890".map { .character(String($0)) },
        [.character("-"), .character("/"), .character(":"), .character(";"),
         .character("("), .character(")"), .character("$"), .character("&"),
         .character("@"), .character("\"")],
        [.symbols,
         .character("."), .character(","), .character("?"), .character("!"),
         .character("'"),
         .delete],
    ]

    private static let symbolsRows: [[KeyType]] = [
        [.character("["), .character("]"), .character("{"), .character("}"),
         .character("#"), .character("%"), .character("^"), .character("*"),
         .character("+"), .character("=")],
        [.character("_"), .character("\\"), .character("|"), .character("~"),
         .character("<"), .character(">"), .character("\u{20AC}"), .character("\u{00A3}"),
         .character("\u{00A5}"), .character("\u{2022}")],
        [.numbers,
         .character("."), .character(","), .character("?"), .character("!"),
         .character("'"),
         .delete],
    ]

    // Long-press alternates per base character
    private static let alternates: [String: [String]] = [
        "E": ["\u{00E8}", "\u{00E9}", "\u{00EA}", "\u{00EB}", "\u{0113}"],
        "A": ["\u{00E0}", "\u{00E1}", "\u{00E2}", "\u{00E4}", "\u{00E3}", "\u{00E5}"],
        "I": ["\u{00EC}", "\u{00ED}", "\u{00EE}", "\u{00EF}"],
        "O": ["\u{00F2}", "\u{00F3}", "\u{00F4}", "\u{00F6}", "\u{00F5}"],
        "U": ["\u{00F9}", "\u{00FA}", "\u{00FB}", "\u{00FC}"],
        "S": ["\u{00DF}", "\u{015B}", "\u{0161}"],
        "N": ["\u{00F1}"],
        "C": ["\u{00E7}", "\u{0107}", "\u{010D}"],
        "Y": ["\u{00FD}", "\u{00FF}"],
        "L": ["\u{0142}"],
        "Z": ["\u{017E}", "\u{017A}", "\u{017C}"],
    ]

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        buildLayout(for: .letters)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.axis = .vertical
        outerStack.spacing = rowSpacing
        outerStack.alignment = .fill
        outerStack.distribution = .fillEqually
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edgeInset),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -edgeInset),
            outerStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Build Layout

    func switchMode(_ mode: KeyboardMode) {
        guard mode != currentMode else { return }
        currentMode = mode
        buildLayout(for: mode)
    }

    func updateShift(_ state: ShiftState) {
        shiftState = state
        for key in allKeyViews {
            key.updateShiftState(state)
        }
        // Update shift icon appearance
        if let shiftKey = allKeyViews.first(where: { $0.keyType == .shift }) {
            switch state {
            case .lower:
                shiftKey.alpha = 1.0
            case .upper:
                shiftKey.alpha = 1.0
                shiftKey.tintColor = .systemBlue
            case .capsLock:
                shiftKey.backgroundColor = isDark ? .white.withAlphaComponent(0.3) : .systemBlue.withAlphaComponent(0.15)
            }
        }
    }

    private func buildLayout(for mode: KeyboardMode) {
        // Remove old rows
        for view in outerStack.arrangedSubviews {
            outerStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        allKeyViews.removeAll()
        keyRows.removeAll()

        let rows: [[KeyType]]
        switch mode {
        case .letters:
            rows = Self.lettersRows
        case .numbers:
            rows = Self.numbersRows
        case .symbols:
            rows = Self.symbolsRows
        }

        // Build character rows
        for rowDef in rows {
            let (rowStack, keys) = makeRow(rowDef)
            outerStack.addArrangedSubview(rowStack)
            keyRows.append(keys)
            allKeyViews.append(contentsOf: keys)
        }

        // Bottom row: globe | numbers/letters | space | return
        let bottomKeys: [KeyType]
        switch mode {
        case .letters:
            bottomKeys = [.globe, .numbers, .space, .return("return")]
        case .numbers, .symbols:
            bottomKeys = [.globe, .character("ABC"), .space, .return("return")]
        }

        let (bottomStack, bottomKeyViews) = makeRow(bottomKeys)
        outerStack.addArrangedSubview(bottomStack)
        keyRows.append(bottomKeyViews)
        allKeyViews.append(contentsOf: bottomKeyViews)

        applyTheme(dark: isDark)
        updateShift(shiftState)
    }

    private func makeRow(_ keyTypes: [KeyType]) -> (UIStackView, [KeyView]) {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.spacing = keySpacing
        rowStack.alignment = .fill
        rowStack.distribution = .fill

        var keys: [KeyView] = []

        for keyType in keyTypes {
            let keyView = KeyView(keyType: keyType)
            configureKeyEvents(keyView)

            // Set alternate characters for long-press
            if case .character(let c) = keyType {
                keyView.alternateCharacters = Self.alternates[c.uppercased()] ?? []
            }

            rowStack.addArrangedSubview(keyView)
            keys.append(keyView)

            // Width relative to a standard key (~1.0 multiplier)
            if keyType.widthMultiplier != 1.0 {
                // Use a priority that allows flexible sizing but respects the multiplier ratio
                let widthConstraint = keyView.widthAnchor.constraint(equalToConstant: 0)
                widthConstraint.priority = .defaultLow
                widthConstraint.isActive = true
            }
        }

        // Make all 1.0-multiplier keys equal width
        let standardKeys = keys.filter { $0.keyType.widthMultiplier == 1.0 }
        for i in 1..<standardKeys.count {
            standardKeys[i].widthAnchor.constraint(equalTo: standardKeys[0].widthAnchor).isActive = true
        }

        // Set wider keys relative to standard keys
        if let baseKey = standardKeys.first {
            for key in keys where key.keyType.widthMultiplier != 1.0 {
                key.widthAnchor.constraint(
                    equalTo: baseKey.widthAnchor,
                    multiplier: key.keyType.widthMultiplier
                ).isActive = true
            }
        }

        return (rowStack, keys)
    }

    // MARK: - Key Events

    private func configureKeyEvents(_ keyView: KeyView) {
        keyView.eventHandler.onTap = { [weak self] keyType in
            self?.handleKeyTap(keyType)
        }
        keyView.eventHandler.onLongPress = { [weak self] keyType, sourceView in
            self?.handleLongPress(keyType, source: sourceView)
        }
        keyView.eventHandler.onSwipeBegin = { [weak self] point in
            self?.actionDelegate?.didBeginSwipe(at: point)
        }
        keyView.eventHandler.onSwipeMoved = { [weak self] point in
            self?.actionDelegate?.didContinueSwipe(at: point)
        }
        keyView.eventHandler.onSwipeEnd = { [weak self] point in
            self?.actionDelegate?.didEndSwipe(at: point)
        }
    }

    private func handleKeyTap(_ keyType: KeyType) {
        switch keyType {
        case .character(let c):
            if c == "ABC" {
                switchMode(.letters)
                return
            }
            let output: String
            switch shiftState {
            case .upper:
                output = c.uppercased()
                // Auto-return to lowercase after one character (unless caps lock)
            case .capsLock:
                output = c.uppercased()
            case .lower:
                output = c.lowercased()
            }
            actionDelegate?.didTapCharacter(output)
        case .space:
            actionDelegate?.didTapSpace()
        case .delete:
            actionDelegate?.didTapDelete()
        case .return:
            actionDelegate?.didTapReturn()
        case .shift:
            actionDelegate?.didTapShift()
        case .globe:
            actionDelegate?.didTapGlobe()
        case .numbers:
            switchMode(.numbers)
        case .symbols:
            switchMode(.symbols)
        case .ai:
            actionDelegate?.didTapAI()
        }
    }

    private func handleLongPress(_ keyType: KeyType, source: UIView) {
        guard case .character(let c) = keyType,
              let alts = Self.alternates[c.uppercased()], !alts.isEmpty else { return }

        activePopup?.dismiss()

        let popup = AlternateCharsPopup(characters: alts) { [weak self] selected in
            self?.actionDelegate?.didTapCharacter(selected)
            self?.activePopup?.dismiss()
            self?.activePopup = nil
        }
        activePopup = popup
        popup.show(above: source, in: self)
    }

    // MARK: - Theme

    func applyTheme(dark: Bool) {
        isDark = dark
        backgroundColor = dark
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)

        for key in allKeyViews {
            key.configure(darkTheme: dark)
        }
    }

    // MARK: - Utility

    /// Returns the center point of the key for the given character, in this view's coordinate space.
    /// Used by the swipe decoder to build ideal gesture templates.
    func keyCenterForCharacter(_ char: String) -> CGPoint? {
        let upper = char.uppercased()
        for key in allKeyViews {
            if case .character(let c) = key.keyType, c.uppercased() == upper {
                return key.convert(CGPoint(x: key.bounds.midX, y: key.bounds.midY), to: self)
            }
        }
        return nil
    }
}
