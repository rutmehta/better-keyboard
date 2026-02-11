import UIKit

/// Checks whether the custom keyboard is enabled and has Full Access.
struct KeyboardStatusChecker {

    /// Returns `true` if BetterKeyboard appears in the list of active keyboards.
    ///
    /// `UITextInputMode.activeInputModes` contains entries for each keyboard the user has enabled
    /// in Settings > General > Keyboard > Keyboards. We look for our extension's bundle identifier
    /// in the mode identifiers.
    func isKeyboardEnabled() -> Bool {
        let modes = UITextInputMode.activeInputModes
        return modes.contains { mode in
            guard let identifier = mode.value(forKey: "identifier") as? String else { return false }
            return identifier.contains(AppConstants.keyboardBundleIdentifier)
        }
    }

    /// Returns `true` if Full Access has been granted to the keyboard extension.
    ///
    /// There is no direct API to check another extension's Full Access from the containing app.
    /// The keyboard extension writes a flag into the shared App Groups container on launch when
    /// it detects `hasFullAccess == true`. We read that flag here.
    func isFullAccessEnabled() -> Bool {
        guard let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) else {
            return false
        }
        return defaults.bool(forKey: AppConstants.UserDefaultsKey.fullAccessEnabled)
    }
}
