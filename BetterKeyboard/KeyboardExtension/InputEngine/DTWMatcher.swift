import Foundation
import CoreGraphics

// MARK: - DTW Matcher

/// Dynamic Time Warping algorithm for comparing an input gesture path
/// against a pre-computed template path.
///
/// Optimizations for meeting the <17ms per comparison target:
/// 1. Sakoe-Chiba band constraint: limits warp to `bandWidth` cells
///    around the diagonal, reducing O(n*m) to O(n*bandWidth).
/// 2. Early abandonment: if partial DTW cost already exceeds `pruneThreshold`,
///    the comparison is aborted and returns Float.infinity.
/// 3. Single-row rolling array: only stores one row of the DTW matrix at a
///    time instead of the full n*m matrix.
struct DTWMatcher {

    /// Sakoe-Chiba band radius. A band of +/-10 around the diagonal
    /// is sufficient for gesture paths resampled to 64 points.
    static let defaultBandWidth: Int = 10

    /// Compare an input gesture (resampled [CGPoint]) against a template.
    /// Returns normalized DTW distance (lower = better).
    /// Returns Float.infinity if pruned.
    static func distance(
        input: [CGPoint],
        template: [CGPoint],
        bandWidth: Int = defaultBandWidth,
        pruneThreshold: Float = .infinity
    ) -> Float {
        let n = input.count
        let m = template.count
        guard n > 0, m > 0 else { return .infinity }

        // Use two rows for O(m) memory instead of O(n*m)
        var previousRow = [Float](repeating: .infinity, count: m)
        var currentRow = [Float](repeating: .infinity, count: m)

        // Initialize first cell
        previousRow[0] = pointDistance(input[0], template[0])

        // Initialize first row within band
        for j in 1..<min(bandWidth + 1, m) {
            previousRow[j] = previousRow[j - 1] + pointDistance(input[0], template[j])
        }

        // Fill matrix row by row
        for i in 1..<n {
            // Determine band bounds for this row
            let jMin = max(0, i - bandWidth)
            let jMax = min(m - 1, i + bandWidth)

            // Reset current row
            for j in 0..<m { currentRow[j] = .infinity }

            var rowMin: Float = .infinity

            for j in jMin...jMax {
                let cost = pointDistance(input[i], template[j])

                var best: Float = .infinity
                // (i-1, j)
                if previousRow[j] < best { best = previousRow[j] }
                // (i, j-1)
                if j > 0 && currentRow[j - 1] < best { best = currentRow[j - 1] }
                // (i-1, j-1)
                if j > 0 && previousRow[j - 1] < best { best = previousRow[j - 1] }

                currentRow[j] = cost + best
                if currentRow[j] < rowMin { rowMin = currentRow[j] }
            }

            // Early abandonment: if the best value in this entire row
            // already exceeds the prune threshold, no path through this
            // row can produce a result below threshold.
            if rowMin > pruneThreshold {
                return .infinity
            }

            // Swap rows
            let temp = previousRow
            previousRow = currentRow
            currentRow = temp
        }

        let rawDistance = previousRow[m - 1]

        // Normalize by path length so longer words aren't penalized
        let normalizedDistance = rawDistance / Float(n + m)
        return normalizedDistance
    }

    /// Euclidean distance between two CGPoints (as Float for speed).
    @inline(__always)
    private static func pointDistance(_ a: CGPoint, _ b: CGPoint) -> Float {
        let dx = Float(a.x - b.x)
        let dy = Float(a.y - b.y)
        return sqrtf(dx * dx + dy * dy)
    }
}
