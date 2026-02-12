import Foundation

// MARK: - Settings Models

enum HapticIntensity: String, Codable, CaseIterable {
    case off = "off"
    case light = "light"
    case medium = "medium"
    case strong = "strong"
}

enum SwipeSensitivity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

enum ReplyStyle: String, Codable, CaseIterable {
    case flirty = "flirty and witty"
    case professional = "professional and polished"
    case casual = "casual and friendly"
    case funny = "humorous"
    case auto = "auto"
}

enum KeyboardTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

// MARK: - Keyboard Models

enum KeyboardMode {
    case letters
    case numbers
    case symbols
}

enum ShiftState {
    case lower
    case upper
    case capsLock
}

// MARK: - Swipe Models

struct SwipeCandidate: Codable {
    let word: String
    let geometricScore: Float
    let languageScore: Float
    var combinedScore: Float { geometricScore * 0.6 + languageScore * 0.4 }
}

// MARK: - AI Models

struct AIReply: Codable {
    let text: String
    let style: ReplyStyle
    let timestamp: Date
}

struct AIAnalysisResult: Codable {
    let extractedText: String
    let replies: [AIReply]
    let timestamp: Date
    let sourceApp: String?
}

// MARK: - Host App Detection

enum HostAppCategory {
    case dating(String)
    case email(String)
    case messaging(String)
    case social(String)
    case unknown(String)

    init(bundleId: String) {
        self = ProductConfig.category(for: bundleId)
    }

    var defaultTone: ReplyStyle {
        ProductConfig.defaultTone(for: self)
    }

    var promptPrefix: String {
        ProductConfig.promptPrefix(for: self)
    }
}
