import UIKit
import Vision

enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(Error)
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process image for OCR"
        case .recognitionFailed(let err): return "OCR failed: \(err.localizedDescription)"
        case .noTextFound: return "No text detected in screenshots"
        }
    }
}

/// Extracts text from images using the Vision framework's text recognition.
/// Runs in the containing app only (not the keyboard extension).
final class OCREngine {

    /// Extract text from a single image using Vision's accurate recognition.
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    /// Extract and merge conversation text from multiple screenshots,
    /// deduplicating overlapping content between consecutive images.
    ///
    /// Images are assumed to arrive newest-first (from ScreenshotManager) and
    /// are reversed here so the conversation reads chronologically.
    func extractConversation(from images: [UIImage]) async throws -> String {
        guard !images.isEmpty else {
            throw OCRError.noTextFound
        }

        // Process oldest screenshot first (images are newest-first from ScreenshotManager)
        var chunks: [String] = []
        for image in images.reversed() {
            try Task.checkCancellation()
            do {
                let text = try await extractText(from: image)
                chunks.append(text)
            } catch OCRError.noTextFound {
                continue // Skip blank screenshots
            }
        }

        guard !chunks.isEmpty else {
            throw OCRError.noTextFound
        }

        return deduplicateConversation(chunks)
    }

    // MARK: - Deduplication

    /// Merge text chunks by removing overlapping content between consecutive screenshots.
    /// When a user scrolls through a conversation and takes multiple screenshots, there is
    /// typically overlapping text between the bottom of one screenshot and the top of the next.
    private func deduplicateConversation(_ chunks: [String]) -> String {
        guard var result = chunks.first else { return "" }

        for i in 1..<chunks.count {
            let current = chunks[i]
            let overlapLength = findOverlap(result, current)
            if overlapLength > 20 {
                // Significant overlap found -- merge without duplication
                result += String(current.dropFirst(overlapLength))
            } else {
                // No meaningful overlap -- concatenate with separator
                result += "\n---\n" + current
            }
        }

        return result
    }

    /// Find the length of the longest suffix of `a` that is a prefix of `b`.
    /// Checks in 10-character steps from the maximum possible overlap down to 20 characters.
    private func findOverlap(_ a: String, _ b: String) -> Int {
        let maxOverlap = min(a.count, b.count, 200)
        for length in stride(from: maxOverlap, through: 20, by: -10) {
            let aSuffix = String(a.suffix(length))
            if b.hasPrefix(aSuffix) {
                return length
            }
        }
        return 0
    }
}
