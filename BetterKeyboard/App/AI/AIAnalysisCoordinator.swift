import UIKit

enum AnalysisError: Error, LocalizedError {
    case timeout
    case pipelineFailed(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Analysis timed out after 10 seconds"
        case .pipelineFailed(let msg): return "Analysis failed: \(msg)"
        }
    }
}

/// Coordinates the full screenshot -> OCR -> AI pipeline.
///
/// This is the main entry point for AI analysis, called by DeepLinkHandler
/// when the keyboard extension triggers an app-jump via deep link.
///
/// Pipeline steps:
///   1. Fetch recent screenshots (ScreenshotManager)
///   2. Extract conversation text via OCR (OCREngine)
///   3. Determine reply style from user settings
///   4. Generate replies via AI (AIEngine)
///   5. Package into AIAnalysisResult
///   6. Save to SharedSettings for the keyboard extension to consume
final class AIAnalysisCoordinator: AIAnalysisService {

    private let screenshotManager: ScreenshotManager
    private let ocrEngine: OCREngine
    private let aiEngine: AIEngine
    private let settings: SharedSettings

    init(
        screenshotManager: ScreenshotManager = ScreenshotManager(),
        ocrEngine: OCREngine = OCREngine(),
        aiEngine: AIEngine = AIEngine(),
        settings: SharedSettings = .shared
    ) {
        self.screenshotManager = screenshotManager
        self.ocrEngine = ocrEngine
        self.aiEngine = aiEngine
        self.settings = settings
    }

    /// Run the full analysis pipeline with a 10-second timeout.
    ///
    /// Uses a task group to race the pipeline against a timeout timer.
    /// Whichever finishes first wins -- if the timeout fires, the pipeline
    /// task is cancelled automatically.
    func analyzeRecentScreenshots() async throws -> AIAnalysisResult {
        try await withThrowingTaskGroup(of: AIAnalysisResult.self) { group in
            group.addTask {
                try await self.runPipeline()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                throw AnalysisError.timeout
            }

            // Return whichever finishes first (pipeline result or timeout error)
            guard let result = try await group.next() else {
                throw AnalysisError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Pipeline Steps

    private func runPipeline() async throws -> AIAnalysisResult {
        // Step 1: Fetch screenshots
        let limit = min(settings.screenshotHistoryLimit, 5)
        let screenshots: [UIImage]
        do {
            screenshots = try await screenshotManager.fetchRecentScreenshots(
                limit: limit,
                withinSeconds: 120
            )
        } catch {
            throw AnalysisError.pipelineFailed("Screenshot fetch: \(error.localizedDescription)")
        }

        try Task.checkCancellation()

        // Step 2: OCR -- extract conversation text
        let conversationText: String
        do {
            conversationText = try await ocrEngine.extractConversation(from: screenshots)
        } catch {
            throw AnalysisError.pipelineFailed("OCR: \(error.localizedDescription)")
        }

        try Task.checkCancellation()

        // Step 3: Determine reply style
        let style = resolveStyle()

        // Step 4: Generate AI replies
        let replyTexts: [String]
        do {
            replyTexts = try await aiEngine.generateReplies(
                conversationText: conversationText,
                style: style
            )
        } catch {
            throw AnalysisError.pipelineFailed("AI generation: \(error.localizedDescription)")
        }

        let replies = replyTexts.map { text in
            AIReply(text: text, style: style, timestamp: Date())
        }

        // Step 5: Package result
        let result = AIAnalysisResult(
            extractedText: conversationText,
            replies: replies,
            timestamp: Date(),
            sourceApp: nil
        )

        // Step 6: Save for keyboard extension to consume via App Groups
        settings.saveAIReplies(result)

        return result
    }

    /// Resolve the reply style from user settings.
    /// When set to .auto, falls back to .casual (the containing app does not
    /// have direct access to the host app bundle ID -- that info lives in
    /// the keyboard extension).
    private func resolveStyle() -> ReplyStyle {
        let userStyle = settings.aiStyle
        if userStyle == .auto {
            return .casual
        }
        return userStyle
    }
}
