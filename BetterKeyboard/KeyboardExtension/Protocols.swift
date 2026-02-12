import UIKit

// MARK: - Keyboard Action Delegate

/// Implemented by KeyboardViewController to handle all key and swipe events.
@MainActor protocol KeyboardActionDelegate: AnyObject {
    func didTapCharacter(_ char: String)
    func didTapSpace()
    func didTapDelete()
    func didTapReturn()
    func didTapShift()
    func didTapGlobe()
    func didTapAI()
    func didSelectSuggestion(_ word: String)
    func didBeginSwipe(at point: CGPoint)
    func didContinueSwipe(at point: CGPoint)
    func didEndSwipe(at point: CGPoint)
}

// MARK: - Suggestion Delegate

/// Allows the input engine / swipe decoder to push suggestion updates to the UI.
@MainActor protocol SuggestionDelegate: AnyObject {
    func updateSuggestions(_ candidates: [String])
    func clearSuggestions()
}
