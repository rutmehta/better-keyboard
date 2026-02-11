import UIKit

final class OnboardingViewController: UIViewController {

    // MARK: - Properties

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    private var pages: [UIView] = []

    private var currentPage: Int = 0 {
        didSet { updateForCurrentPage() }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildPages()
        layoutUI()
    }

    // MARK: - Pages

    private func buildPages() {
        pages = [
            makeWelcomePage(),
            makeEnableKeyboardPage(),
            makeFullAccessPage(),
            makePhotosPermissionPage(),
        ]
    }

    private func makeWelcomePage() -> UIView {
        makePage(
            icon: "keyboard",
            title: "Welcome to BetterKeyboard",
            body: "A smarter keyboard with swipe typing, haptic feedback, and on-device AI — all private, all on your device."
        )
    }

    private func makeEnableKeyboardPage() -> UIView {
        makePage(
            icon: "gear.badge",
            title: "Enable the Keyboard",
            body: "Open Settings > General > Keyboard > Keyboards > Add New Keyboard, then select BetterKeyboard."
        )
    }

    private func makeFullAccessPage() -> UIView {
        makePage(
            icon: "hand.tap",
            title: "Allow Full Access",
            body: "Full Access enables haptic feedback and AI features. Your data never leaves the device — everything runs locally."
        )
    }

    private func makePhotosPermissionPage() -> UIView {
        makePage(
            icon: "photo.on.rectangle.angled",
            title: "Screenshot Analysis",
            body: "Grant Photos access so the AI can read your recent screenshots and generate smart replies — perfect for dating apps, emails, and more."
        )
    }

    // MARK: - Page Factory

    private func makePage(icon: String, title: String, body: String) -> UIView {
        let container = UIView()

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .thin)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = body
        bodyLabel.font = .systemFont(ofSize: 17, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 80),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])

        return container
    }

    // MARK: - Layout

    private func layoutUI() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        view.addSubview(scrollView)

        // Page control
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.addTarget(self, action: #selector(pageControlTapped), for: .valueChanged)
        view.addSubview(pageControl)

        // Next / Get Started button
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        nextButton.backgroundColor = .systemBlue
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 14
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -16),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -20),

            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            nextButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        // Add page views inside the scroll view
        for (index, page) in pages.enumerated() {
            page.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(page)

            NSLayoutConstraint.activate([
                page.topAnchor.constraint(equalTo: scrollView.topAnchor),
                page.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                page.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
                page.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            ])

            if index == 0 {
                page.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor).isActive = true
            } else {
                page.leadingAnchor.constraint(equalTo: pages[index - 1].trailingAnchor).isActive = true
            }

            if index == pages.count - 1 {
                page.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor).isActive = true
            }
        }
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        if currentPage < pages.count - 1 {
            currentPage += 1
            let offset = CGFloat(currentPage) * scrollView.bounds.width
            scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: true)
        } else {
            completeOnboarding()
        }
    }

    @objc private func pageControlTapped() {
        currentPage = pageControl.currentPage
        let offset = CGFloat(currentPage) * scrollView.bounds.width
        scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: true)
    }

    private func completeOnboarding() {
        SharedSettings.shared.hasCompletedOnboarding = true

        guard let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate else { return }
        sceneDelegate.transitionToMainApp()
    }

    // MARK: - Page Update

    private func updateForCurrentPage() {
        pageControl.currentPage = currentPage
        let isLastPage = currentPage == pages.count - 1
        nextButton.setTitle(isLastPage ? "Get Started" : "Next", for: .normal)
    }
}

// MARK: - UIScrollViewDelegate

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.bounds.width)
        currentPage = page
    }
}
