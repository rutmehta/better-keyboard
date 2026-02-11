import UIKit

// MARK: - Key Type

enum KeyType: Equatable {
    case character(String)
    case space
    case delete
    case shift
    case `return`(String) // label: "return", "Send", "Search", etc.
    case globe
    case numbers       // switch to 123 layout
    case symbols       // switch to #+=  layout
    case ai

    var displayLabel: String {
        switch self {
        case .character(let c): return c
        case .space: return "space"
        case .delete: return "delete"
        case .shift: return "shift"
        case .return(let label): return label
        case .globe: return "globe"
        case .numbers: return "123"
        case .symbols: return "#+=".self
        case .ai: return "AI"
        }
    }

    /// Relative width multiplier. 1.0 = standard key.
    var widthMultiplier: CGFloat {
        switch self {
        case .shift, .delete: return 1.4
        case .return: return 1.8
        case .space: return 4.0
        case .globe, .numbers, .symbols, .ai: return 1.2
        case .character: return 1.0
        }
    }

    var isSpecial: Bool {
        switch self {
        case .character: return false
        default: return true
        }
    }

    static func == (lhs: KeyType, rhs: KeyType) -> Bool {
        switch (lhs, rhs) {
        case (.character(let a), .character(let b)): return a == b
        case (.space, .space), (.delete, .delete), (.shift, .shift),
             (.globe, .globe), (.numbers, .numbers), (.symbols, .symbols),
             (.ai, .ai): return true
        case (.return(let a), .return(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Key Event Closure

struct KeyEventHandler {
    var onTap: ((KeyType) -> Void)?
    var onLongPress: ((KeyType, UIView) -> Void)?
    var onSwipeBegin: ((CGPoint) -> Void)?
    var onSwipeMoved: ((CGPoint) -> Void)?
    var onSwipeEnd: ((CGPoint) -> Void)?
}

// MARK: - KeyView

final class KeyView: UIView {

    // MARK: - Properties

    let keyType: KeyType
    var eventHandler = KeyEventHandler()

    private let label = UILabel()
    private let iconView = UIImageView()
    private var longPressTimer: Timer?

    /// Alternate characters available on long-press (e.g. e -> e,e,e,e).
    var alternateCharacters: [String] = []

    // MARK: Theme Colors

    private var isDarkTheme: Bool = false {
        didSet { applyTheme() }
    }

    // MARK: - Init

    init(keyType: KeyType) {
        self.keyType = keyType
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        layer.cornerRadius = 5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 0.5

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true

        switch keyType {
        case .delete:
            setupIcon(systemName: "delete.left")
        case .shift:
            setupIcon(systemName: "shift")
        case .globe:
            setupIcon(systemName: "globe")
        case .ai:
            setupIcon(systemName: "sparkles")
        default:
            setupLabel()
        }

        applyTheme()
    }

    private func setupLabel() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.isUserInteractionEnabled = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])

        switch keyType {
        case .character(let c):
            label.text = c
            label.font = .systemFont(ofSize: 22, weight: .regular)
        case .space:
            label.text = "space"
            label.font = .systemFont(ofSize: 16, weight: .regular)
        case .return(let title):
            label.text = title
            label.font = .systemFont(ofSize: 16, weight: .medium)
        case .numbers:
            label.text = "123"
            label.font = .systemFont(ofSize: 16, weight: .medium)
        case .symbols:
            label.text = "#+=".self
            label.font = .systemFont(ofSize: 16, weight: .medium)
        default:
            break
        }
    }

    private func setupIcon(systemName: String) {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: systemName, withConfiguration: config)

        addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -8),
            iconView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -8),
        ])
    }

    // MARK: - Theme

    func configure(darkTheme: Bool) {
        isDarkTheme = darkTheme
    }

    private func applyTheme() {
        if keyType.isSpecial {
            backgroundColor = isDarkTheme
                ? UIColor(white: 0.42, alpha: 1)
                : UIColor(red: 0.67, green: 0.70, blue: 0.73, alpha: 1)
        } else {
            backgroundColor = isDarkTheme
                ? UIColor(white: 0.55, alpha: 1)
                : .white
        }

        let textColor: UIColor = isDarkTheme ? .white : .black
        label.textColor = textColor
        iconView.tintColor = textColor
    }

    // MARK: - Shift State (for character keys)

    func updateShiftState(_ state: ShiftState) {
        guard case .character(let c) = keyType else { return }
        switch state {
        case .lower:
            label.text = c.lowercased()
        case .upper, .capsLock:
            label.text = c.uppercased()
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        animatePress(true)

        // Start long-press timer for character keys that have alternates
        if case .character = keyType, !alternateCharacters.isEmpty {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.eventHandler.onLongPress?(self.keyType, self)
            }
        }

        // Notify swipe begin for character keys (swipe gestures start on key touch)
        if case .character = keyType, let touch = touches.first {
            let point = touch.location(in: superview?.superview)
            eventHandler.onSwipeBegin?(point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if case .character = keyType, let touch = touches.first {
            let point = touch.location(in: superview?.superview)
            eventHandler.onSwipeMoved?(point)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        animatePress(false)
        longPressTimer?.invalidate()
        longPressTimer = nil

        if case .character = keyType, let touch = touches.first {
            let point = touch.location(in: superview?.superview)
            eventHandler.onSwipeEnd?(point)
        }

        eventHandler.onTap?(keyType)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        animatePress(false)
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    // MARK: - Press Animation

    private func animatePress(_ pressed: Bool) {
        UIView.animate(withDuration: 0.05) {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            self.alpha = pressed ? 0.8 : 1.0
        }
    }
}
