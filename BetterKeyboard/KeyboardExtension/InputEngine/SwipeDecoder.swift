import Foundation
import CoreGraphics

// MARK: - Swipe Decoder (SHARK2)

/// Main swipe-typing decoder implementing the SHARK2 pipeline:
///
///   1. Normalize gesture path → resample to fixed point count
///   2. Pre-filter templates by first/last letter proximity
///   3. DTW match against filtered templates → top 50 geometric candidates
///   4. Apply language model scores
///   5. Produce final ranked [SwipeCandidate] (top 3 for suggestion bar)
///
/// Scoring formula: combined = geometric * 0.6 + language * 0.4
final class SwipeDecoder {

    // MARK: - Configuration

    /// Maximum number of geometric candidates before LM reranking.
    private let geometricTopN = 50

    /// Maximum number of final candidates returned.
    private let finalTopN = 3

    /// Proximity radius (normalized) for matching gesture endpoints to key centers.
    /// Keys are roughly 0.1 wide, so 0.12 gives some tolerance.
    private let endpointRadius: Float = 0.12

    // MARK: - Dependencies

    private let templates: [GestureTemplate]
    private let dictionary: DAWGDictionary
    private let layout: KeyLayout
    private var languageModel: LanguageModelProtocol

    /// Templates grouped by (firstChar, lastChar) for fast pre-filtering.
    private let templateIndex: [UInt64: [Int]]

    init(
        templates: [GestureTemplate],
        dictionary: DAWGDictionary,
        layout: KeyLayout = .qwerty,
        languageModel: LanguageModelProtocol = PlaceholderLanguageModel()
    ) {
        self.templates = templates
        self.dictionary = dictionary
        self.layout = layout
        self.languageModel = languageModel

        // Build pre-filter index: hash(first, last) -> template indices
        var index: [UInt64: [Int]] = [:]
        for (i, t) in templates.enumerated() {
            let key = Self.charPairKey(t.firstChar, t.lastChar)
            index[key, default: []].append(i)
        }
        self.templateIndex = index
    }

    /// Replace the language model (e.g. when upgrading from placeholder to N-gram).
    func setLanguageModel(_ model: LanguageModelProtocol) {
        self.languageModel = model
    }

    // MARK: - Decode

    /// Decode a completed swipe gesture into ranked word candidates.
    /// This is the main entry point called when the user lifts their finger.
    func decode(gesture: [GesturePoint], context: String = "") -> [SwipeCandidate] {
        guard gesture.count >= 2 else { return [] }

        // Step 1: Extract and resample the position path
        let rawPath = gesture.map { $0.position }
        let inputPath = resample(rawPath, count: GestureTemplate.resampleCount)

        // Step 2: Identify candidate first/last characters from gesture endpoints
        let startCandidates = nearbyCharacters(for: inputPath.first!, radius: endpointRadius)
        let endCandidates = nearbyCharacters(for: inputPath.last!, radius: endpointRadius)

        // Step 3: Pre-filter templates by first/last character match
        var candidateIndices: [Int] = []
        for first in startCandidates {
            for last in endCandidates {
                let key = Self.charPairKey(first, last)
                if let indices = templateIndex[key] {
                    candidateIndices.append(contentsOf: indices)
                }
            }
        }

        // Deduplicate (a template might match multiple start/end combos)
        let uniqueIndices = Array(Set(candidateIndices))

        // Step 4: DTW match with early abandonment
        var scored: [(index: Int, distance: Float)] = []
        scored.reserveCapacity(min(uniqueIndices.count, geometricTopN))
        var currentPruneThreshold: Float = .infinity

        for idx in uniqueIndices {
            let template = templates[idx]
            let dist = DTWMatcher.distance(
                input: inputPath,
                template: template.path,
                pruneThreshold: currentPruneThreshold
            )
            if dist < .infinity {
                scored.append((idx, dist))
                // Keep top N by maintaining threshold
                if scored.count > geometricTopN {
                    scored.sort(by: { $0.distance < $1.distance })
                    scored = Array(scored.prefix(geometricTopN))
                    currentPruneThreshold = scored.last!.distance
                }
            }
        }

        // Sort final geometric candidates
        scored.sort(by: { $0.distance < $1.distance })
        let topGeometric = scored.prefix(geometricTopN)

        // Step 5: Compute geometric scores (normalized to 0...1, higher = better)
        guard let worstDistance = topGeometric.last?.distance, worstDistance > 0 else {
            return []
        }
        // Use the worst distance in the top set as the normalizer.
        // Score = 1 - (distance / worstDistance), clamped so best = 1.0
        let normalizer = worstDistance * 1.2 // slight padding so the worst isn't exactly 0

        // Step 6: Apply language model and produce SwipeCandidates
        var candidates: [SwipeCandidate] = []
        candidates.reserveCapacity(topGeometric.count)

        for item in topGeometric {
            let template = templates[item.index]
            let word: String
            if template.wordId < dictionary.words.count {
                word = dictionary.words[template.wordId]
            } else {
                continue
            }

            let geoScore = max(0, 1.0 - (item.distance / normalizer))
            let lmScore = languageModel.score(word: word, context: context)

            candidates.append(SwipeCandidate(
                word: word,
                geometricScore: geoScore,
                languageScore: lmScore
            ))
        }

        // Step 7: Sort by combined score, return top 3
        candidates.sort(by: { $0.combinedScore > $1.combinedScore })
        return Array(candidates.prefix(finalTopN))
    }

    // MARK: - Helpers

    /// Find characters whose key center is within `radius` of the given point.
    private func nearbyCharacters(for point: CGPoint, radius: Float) -> [Character] {
        let allChars: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
        var result: [Character] = []
        for ch in allChars {
            guard let center = layout.center(for: ch) else { continue }
            let dx = Float(point.x - center.x)
            let dy = Float(point.y - center.y)
            let dist = sqrtf(dx * dx + dy * dy)
            if dist <= radius {
                result.append(ch)
            }
        }
        return result
    }

    /// Resample a polyline to `count` equidistant points.
    private func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }

        var totalLen: Float = 0
        for i in 1..<points.count {
            totalLen += pdist(points[i - 1], points[i])
        }
        guard totalLen > 1e-8 else {
            return Array(repeating: points[0], count: count)
        }

        let interval = totalLen / Float(count - 1)
        var resampled: [CGPoint] = [points[0]]
        var accumulated: Float = 0
        var srcIdx = 1

        while resampled.count < count && srcIdx < points.count {
            let segLen = pdist(points[srcIdx - 1], points[srcIdx])
            if accumulated + segLen >= interval {
                let overshoot = interval - accumulated
                let t = CGFloat(overshoot / max(segLen, 1e-8))
                let x = points[srcIdx - 1].x + t * (points[srcIdx].x - points[srcIdx - 1].x)
                let y = points[srcIdx - 1].y + t * (points[srcIdx].y - points[srcIdx - 1].y)
                resampled.append(CGPoint(x: x, y: y))
                accumulated = 0
            } else {
                accumulated += segLen
                srcIdx += 1
            }
        }

        while resampled.count < count {
            resampled.append(points.last!)
        }
        return Array(resampled.prefix(count))
    }

    @inline(__always)
    private func pdist(_ a: CGPoint, _ b: CGPoint) -> Float {
        let dx = Float(b.x - a.x)
        let dy = Float(b.y - a.y)
        return sqrtf(dx * dx + dy * dy)
    }

    /// Create a hash key from two characters for the pre-filter index.
    private static func charPairKey(_ a: Character, _ b: Character) -> UInt64 {
        let aVal = UInt64(a.asciiValue ?? 0)
        let bVal = UInt64(b.asciiValue ?? 0)
        return (aVal << 32) | bVal
    }
}
