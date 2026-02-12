import Foundation

/// AI prompt templates — the actual prompts sent to Foundation Models.
///
/// Copy this file to `PromptTemplates.swift` and customize your prompts.
/// PromptTemplates.swift is gitignored so your prompt engineering stays private.
enum PromptTemplates {

    /// Build a reply generation prompt from conversation text and style.
    static func replyPrompt(
        conversation: String,
        style: ReplyStyle,
        hostApp: HostAppCategory
    ) -> String {
        let toneDirective = ProductConfig.promptPrefix(for: hostApp)

        return """
        \(toneDirective)

        Conversation:
        \(conversation)

        Generate 3 short reply options. One per line.
        """
    }

    /// Build a text completion prompt for the suggestion bar.
    static func completionPrompt(context: String, partial: String) -> String {
        """
        Complete this text naturally: \(partial)
        """
    }
}
