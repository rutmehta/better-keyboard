import Foundation
import CoreGraphics

// MARK: - Key Layout

/// Maps each character to its center position on the keyboard in normalized
/// (0...1) coordinates. A standard QWERTY layout is provided as default.
struct KeyLayout {
    /// Character -> normalized center point.
    private let centers: [Character: CGPoint]

    init(centers: [Character: CGPoint]) {
        self.centers = centers
    }

    func center(for character: Character) -> CGPoint? {
        return centers[character.lowercased().first ?? character]
    }

    /// Standard 3-row QWERTY layout.
    /// Row 0: q w e r t y u i o p     (10 keys)
    /// Row 1:  a s d f g h j k l      (9 keys, offset ~0.5 key)
    /// Row 2:   z x c v b n m         (7 keys, offset ~1.5 keys)
    ///
    /// Horizontal: each key occupies ~1/10 of width.
    /// Vertical: 3 rows in roughly the top 75% of keyboard area.
    static let qwerty: KeyLayout = {
        var map: [Character: CGPoint] = [:]

        let row0 = Array("qwertyuiop")
        let row1 = Array("asdfghjkl")
        let row2 = Array("zxcvbnm")

        let keyWidth: CGFloat = 1.0 / 10.0
        let rowYPositions: [CGFloat] = [0.17, 0.50, 0.83]

        // Row 0: 10 keys, no offset
        for (i, ch) in row0.enumerated() {
            let x = (CGFloat(i) + 0.5) * keyWidth
            map[ch] = CGPoint(x: x, y: rowYPositions[0])
        }

        // Row 1: 9 keys, half-key offset
        let row1Width: CGFloat = 1.0 / 10.0
        let row1Offset: CGFloat = 0.5 * row1Width
        for (i, ch) in row1.enumerated() {
            let x = row1Offset + (CGFloat(i) + 0.5) * row1Width
            map[ch] = CGPoint(x: x, y: rowYPositions[1])
        }

        // Row 2: 7 keys, 1.5-key offset
        let row2Width: CGFloat = 1.0 / 10.0
        let row2Offset: CGFloat = 1.5 * row2Width
        for (i, ch) in row2.enumerated() {
            let x = row2Offset + (CGFloat(i) + 0.5) * row2Width
            map[ch] = CGPoint(x: x, y: rowYPositions[2])
        }

        return KeyLayout(centers: map)
    }()
}

// MARK: - Gesture Template

/// Pre-computed ideal swipe path for a single word. The path connects
/// the center positions of each letter in the word on the keyboard layout.
/// Templates are resampled to a fixed number of points for consistent
/// DTW comparison.
struct GestureTemplate {
    let wordId: Int
    let path: [CGPoint]      // Normalized ideal key-center path
    let totalLength: Float    // Arc length of the path

    /// The first and last characters of the word (for pre-filtering).
    let firstChar: Character
    let lastChar: Character

    /// Number of points to resample every template to. Using a fixed count
    /// makes DTW matrix dimensions predictable and comparisons fair.
    static let resampleCount = 64

    /// Generate a template for a word given a keyboard layout.
    /// Returns nil if the word contains characters not on the layout.
    static func generate(word: String, wordId: Int, layout: KeyLayout) -> GestureTemplate? {
        let chars = Array(word.lowercased())
        guard chars.count >= 2 else { return nil }

        // Build raw path from key centers (skip duplicate consecutive keys)
        var rawPath: [CGPoint] = []
        for ch in chars {
            guard let center = layout.center(for: ch) else { return nil }
            if let last = rawPath.last, last == center { continue }
            rawPath.append(center)
        }
        guard rawPath.count >= 2 else { return nil }

        // Compute total arc length
        var length: Float = 0
        for i in 1..<rawPath.count {
            length += dist(rawPath[i - 1], rawPath[i])
        }

        // Resample to fixed point count
        let resampled = resample(rawPath, count: GestureTemplate.resampleCount)

        return GestureTemplate(
            wordId: wordId,
            path: resampled,
            totalLength: length,
            firstChar: chars.first!,
            lastChar: chars.last!
        )
    }

    /// Generate templates for a batch of words from the DAWG.
    /// Only generates for words of length >= 2.
    static func batchGenerate(
        words: [String],
        layout: KeyLayout = .qwerty,
        startWordId: Int = 0
    ) -> [GestureTemplate] {
        var templates: [GestureTemplate] = []
        templates.reserveCapacity(words.count)
        for (i, word) in words.enumerated() {
            if let t = generate(word: word, wordId: startWordId + i, layout: layout) {
                templates.append(t)
            }
        }
        return templates
    }

    // MARK: - Resampling

    /// Resample a polyline to `count` equidistant points.
    private static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= 2, count >= 2 else { return points }

        // Total length
        var totalLen: Float = 0
        for i in 1..<points.count {
            totalLen += dist(points[i - 1], points[i])
        }
        guard totalLen > 1e-8 else {
            return Array(repeating: points[0], count: count)
        }

        let interval = totalLen / Float(count - 1)
        var resampled: [CGPoint] = [points[0]]
        var accumulated: Float = 0
        var srcIdx = 1

        while resampled.count < count && srcIdx < points.count {
            let segLen = dist(points[srcIdx - 1], points[srcIdx])
            if accumulated + segLen >= interval {
                let overshoot = interval - accumulated
                let t = CGFloat(overshoot / max(segLen, 1e-8))
                let x = points[srcIdx - 1].x + t * (points[srcIdx].x - points[srcIdx - 1].x)
                let y = points[srcIdx - 1].y + t * (points[srcIdx].y - points[srcIdx - 1].y)
                resampled.append(CGPoint(x: x, y: y))
                accumulated = 0
                // Don't advance srcIdx — the next segment starts from this interpolated point
                // We fake-split by updating the "previous" point concept via a new iteration
            } else {
                accumulated += segLen
                srcIdx += 1
            }
        }

        // Pad or trim to exact count
        while resampled.count < count {
            resampled.append(points.last!)
        }
        if resampled.count > count {
            resampled = Array(resampled.prefix(count))
        }

        return resampled
    }

    private static func dist(_ a: CGPoint, _ b: CGPoint) -> Float {
        let dx = Float(b.x - a.x)
        let dy = Float(b.y - a.y)
        return sqrtf(dx * dx + dy * dy)
    }
}
