import Foundation

/// Product strategy configuration — bundle ID mappings and default tones.
///
/// Copy this file to `ProductConfig.swift` and fill in your own mappings.
/// ProductConfig.swift is gitignored so your strategy stays private.
enum ProductConfig {

    /// Map a host app bundle ID to a HostAppCategory.
    /// Add bundle IDs for the apps you want to target.
    static func category(for bundleId: String) -> HostAppCategory {
        // Example:
        // case "com.example.dating-app":
        //     return .dating(bundleId)
        return .unknown(bundleId)
    }

    /// Default reply tone for each app category.
    static func defaultTone(for category: HostAppCategory) -> ReplyStyle {
        switch category {
        case .dating: return .flirty
        case .email: return .professional
        case .messaging, .social, .unknown: return .casual
        }
    }

    /// System prompt prefix tailored to each app category.
    static func promptPrefix(for category: HostAppCategory) -> String {
        switch category {
        case .dating: return "You're helping write a message."
        case .email: return "You're helping write a message."
        case .messaging: return "You're helping write a message."
        case .social: return "You're helping write a message."
        case .unknown: return "You're helping write a message."
        }
    }
}
