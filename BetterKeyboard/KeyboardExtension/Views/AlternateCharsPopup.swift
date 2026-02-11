import UIKit

/// Popup view displayed above a key when the user performs a long-press.
/// Shows alternate characters in a horizontal strip; the user can slide
/// their finger to highlight and select a character, which is committed on lift.
final class AlternateCharsPopup: UIView {

    // MARK: - Properties

    private let characters: [String]
    private var selectedIndex: Int?
    private var charLabels: [UILabel] = []
    private let onSelect: (String) -> Void

    private let itemWidth: CGFloat = 36
    private let itemHeight: CGFloat = 42
    private let cornerRadius: CGFloat = 8

    // MARK: - Init

    init(characters: [String], onSelect: @escaping (String) -> Void) {
        self.characters = characters
        self.onSelect = onSelect
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.systemGray5
        layer.cornerRadius = cornerRadius
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fillEqually
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for char in characters {
            let lbl = UILabel()
            lbl.text = char
            lbl.textAlignment = .center
            lbl.font = .systemFont(ofSize: 22)
            lbl.textColor = .label
            stack.addArrangedSubview(lbl)
            charLabels.append(lbl)
        }

        // Intrinsic size
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: itemWidth * CGFloat(characters.count)),
            heightAnchor.constraint(equalToConstant: itemHeight),
        ])
    }

    // MARK: - Touch Tracking

    /// Call from the parent view's touchesMoved to update the highlighted character.
    func trackFinger(at point: CGPoint) {
        let localPoint = convert(point, from: superview)
        let index = max(0, min(characters.count - 1, Int(localPoint.x / itemWidth)))

        guard index != selectedIndex else { return }
        selectedIndex = index

        for (i, lbl) in charLabels.enumerated() {
            let isSelected = (i == index)
            lbl.backgroundColor = isSelected ? .systemBlue : .clear
            lbl.textColor = isSelected ? .white : .label
            lbl.layer.cornerRadius = isSelected ? 6 : 0
            lbl.clipsToBounds = true
        }
    }

    /// Call on finger lift to commit the selected character.
    func commitSelection() {
        if let idx = selectedIndex, idx < characters.count {
            onSelect(characters[idx])
        }
    }

    /// Present the popup above the given anchor view in a container.
    func show(above anchorView: UIView, in container: UIView) {
        container.addSubview(self)

        let anchorFrame = anchorView.convert(anchorView.bounds, to: container)
        let popupWidth = itemWidth * CGFloat(characters.count)

        // Center horizontally on the anchor, clamp to container bounds
        var centerX = anchorFrame.midX
        let halfWidth = popupWidth / 2
        centerX = max(halfWidth + 4, min(container.bounds.width - halfWidth - 4, centerX))

        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: container.leadingAnchor, constant: centerX),
            bottomAnchor.constraint(equalTo: container.topAnchor, constant: anchorFrame.minY - 4),
        ])

        // Appear with a light scale animation
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        alpha = 0
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
            self.alpha = 1
        }
    }

    /// Dismiss the popup.
    func dismiss() {
        UIView.animate(withDuration: 0.1, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
