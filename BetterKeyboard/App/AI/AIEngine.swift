import Foundation

// When building with Xcode 26+ / iOS 26 SDK, uncomment:
// import FoundationModels

enum AIError: Error, LocalizedError {
    case notAvailable
    case sessionFailed
    case generationFailed(Error)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "On-device AI is not available on this device"
        case .sessionFailed: return "Failed to create AI session"
        case .generationFailed(let err): return "AI generation failed: \(err.localizedDescription)"
        case .emptyResponse: return "AI returned an empty response"
        }
    }
}

/// AI engine that wraps Apple's Foundation Models framework (iOS 26+).
/// Falls back gracefully on older devices by throwing AIError.notAvailable.
///
/// Foundation Models runs as a system service, so it does NOT count against
/// the keyboard extension's 48MB memory budget. However, it may not be
/// directly accessible from the extension -- hence the app-jump pattern
/// where this engine runs in the containing app.
final class AIEngine {

    // MARK: - Availability

    /// Check whether Foundation Models is available on this device.
    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return _checkFoundationModelsAvailability()
        }
        return false
    }

    // MARK: - Reply Generation

    /// Generate reply suggestions for a conversation.
    /// - Parameters:
    ///   - conversationText: The OCR-extracted conversation text.
    ///   - style: The desired reply tone/style.
    ///   - hostApp: The detected host app category for context-aware prompting.
    /// - Returns: Array of 1-3 reply strings.
    func generateReplies(
        conversationText: String,
        style: ReplyStyle,
        hostApp: HostAppCategory = .unknown("")
    ) async throws -> [String] {
        guard #available(iOS 26, *) else {
            throw AIError.notAvailable
        }
        return try await _generateRepliesWithFM(
            conversationText: conversationText,
            style: style,
            hostApp: hostApp
        )
    }

    // MARK: - Streaming Completion

    /// Stream a text completion given context and partial input.
    /// Used by the suggestion bar for real-time completions.
    func streamCompletion(
        context: String,
        partial: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard #available(iOS 26, *) else {
            throw AIError.notAvailable
        }
        return _streamCompletionWithFM(context: context, partial: partial)
    }

    // MARK: - Foundation Models Implementation (iOS 26+)

    @available(iOS 26, *)
    private func _checkFoundationModelsAvailability() -> Bool {
        // When building with Xcode 26+ / iOS 26 SDK, use the real check:
        // return LanguageModelSession.isAvailable
        return true // Placeholder -- requires iOS 26 SDK at build time
    }

    @available(iOS 26, *)
    private func _generateRepliesWithFM(
        conversationText: String,
        style: ReplyStyle,
        hostApp: HostAppCategory
    ) async throws -> [String] {
        try Task.checkCancellation()

        let prompt = buildReplyPrompt(
            conversation: conversationText,
            style: style,
            hostApp: hostApp
        )

        // When building with Xcode 26+ / iOS 26 SDK, replace the placeholder below with:
        //
        // do {
        //     let session = LanguageModelSession()
        //     let response = try await session.respond(to: prompt)
        //     let replies = parseReplies(response.content)
        //     guard !replies.isEmpty else { throw AIError.emptyResponse }
        //     return replies
        // } catch let error as AIError {
        //     throw error
        // } catch {
        //     throw AIError.generationFailed(error)
        // }

        // Placeholder implementation for pre-iOS 26 SDK compilation:
        _ = prompt
        return [
            "This is a placeholder reply. Build with iOS 26 SDK for real AI.",
            "On-device generation requires Foundation Models framework.",
            "Enable Apple Intelligence in Settings for full functionality."
        ]
    }

    @available(iOS 26, *)
    private func _streamCompletionWithFM(
        context: String,
        partial: String
    ) -> AsyncThrowingStream<String, Error> {
        // When building with Xcode 26+ / iOS 26 SDK, replace with:
        //
        // return AsyncThrowingStream { continuation in
        //     Task {
        //         do {
        //             let session = LanguageModelSession()
        //             let prompt = buildCompletionPrompt(context: context, partial: partial)
        //             for try await chunk in session.streamResponse(to: prompt) {
        //                 try Task.checkCancellation()
        //                 continuation.yield(chunk.content)
        //             }
        //             continuation.finish()
        //         } catch {
        //             continuation.finish(throwing: error)
        //         }
        //     }
        // }

        return AsyncThrowingStream { continuation in
            continuation.yield(partial + " ...")
            continuation.finish()
        }
    }

    // MARK: - Prompt Engineering

    private func buildReplyPrompt(
        conversation: String,
        style: ReplyStyle,
        hostApp: HostAppCategory
    ) -> String {
        let toneDirective: String
        switch style {
        case .auto:
            toneDirective = hostApp.promptPrefix
        case .flirty:
            toneDirective = "You're helping craft a flirty and witty message. Be charming but not creepy."
        case .professional:
            toneDirective = "You're helping draft a professional message. Be clear, concise, and polished."
        case .casual:
            toneDirective = "You're helping with a casual message. Be friendly and natural."
        case .funny:
            toneDirective = "You're helping write a funny message. Be humorous but tasteful."
        }

        return """
        \(toneDirective)

        Below is a conversation extracted from a screenshot. Generate 3 reply options \
        that the user could send as their next message. Each reply should be 1-3 sentences, \
        feel natural, and match the conversation's tone.

        Conversation:
        \(conversation)

        Generate exactly 3 replies. One per line. No numbering, no quotes, no bullet points.
        """
    }

    private func buildCompletionPrompt(context: String, partial: String) -> String {
        """
        Context: \(context)
        Current input: \(partial)
        Complete this naturally in 1-5 words. Output only the completion, no explanation.
        """
    }

    /// Parse the raw LLM response into individual reply strings.
    private func parseReplies(_ content: String) -> [String] {
        content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { String($0) }
    }
}
