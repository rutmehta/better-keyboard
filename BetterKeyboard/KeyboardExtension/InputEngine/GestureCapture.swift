import Foundation
import CoreGraphics

// MARK: - Gesture Point

/// A single sampled point in a swipe gesture, with computed motion features.
struct GesturePoint {
    let position: CGPoint       // Normalized (0...1, 0...1) relative to keyboard
    let timestamp: TimeInterval
    var curvature: Float = 0    // Instantaneous curvature (radians/unit)
    var velocity: Float = 0     // Speed in normalized units/second
    var direction: Float = 0    // Angle of travel in radians (-pi...pi)
}

// MARK: - Gesture Capture

/// Captures and processes touch points during a swipe gesture at 60Hz.
/// All coordinates are normalized to the keyboard's bounding rectangle
/// so that gesture shapes are resolution-independent.
final class GestureCapture {

    /// Minimum distance (normalized) between consecutive samples to avoid
    /// recording stationary points when the finger pauses.
    private static let minSampleDistance: CGFloat = 0.005

    /// The 60Hz sampling interval (16.67ms).
    private static let samplingInterval: TimeInterval = 1.0 / 60.0

    private(set) var points: [GesturePoint] = []
    private var keyboardBounds: CGRect = .zero
    private var lastSampleTime: TimeInterval = 0
    private var isCapturing = false

    /// Configure the keyboard bounding rect for normalization.
    func setKeyboardBounds(_ bounds: CGRect) {
        keyboardBounds = bounds
    }

    // MARK: - Gesture lifecycle

    func beginGesture(at point: CGPoint, timestamp: TimeInterval) {
        points.removeAll(keepingCapacity: true)
        isCapturing = true
        lastSampleTime = timestamp

        let normalized = normalize(point)
        let gp = GesturePoint(position: normalized, timestamp: timestamp)
        points.append(gp)
    }

    func continueGesture(at point: CGPoint, timestamp: TimeInterval) {
        guard isCapturing else { return }

        // Enforce minimum time gap (~60Hz)
        guard timestamp - lastSampleTime >= GestureCapture.samplingInterval * 0.8 else { return }

        let normalized = normalize(point)

        // Skip near-duplicate positions
        if let last = points.last {
            let dx = normalized.x - last.position.x
            let dy = normalized.y - last.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < GestureCapture.minSampleDistance { return }
        }

        let gp = GesturePoint(position: normalized, timestamp: timestamp)
        points.append(gp)
        lastSampleTime = timestamp
    }

    func endGesture(at point: CGPoint, timestamp: TimeInterval) {
        guard isCapturing else { return }
        isCapturing = false

        let normalized = normalize(point)
        let gp = GesturePoint(position: normalized, timestamp: timestamp)
        points.append(gp)

        computeFeatures()
    }

    /// Returns the completed gesture points. Only valid after endGesture.
    func completedGesture() -> [GesturePoint] {
        return points
    }

    // MARK: - Coordinate normalization

    private func normalize(_ point: CGPoint) -> CGPoint {
        guard keyboardBounds.width > 0, keyboardBounds.height > 0 else {
            return point
        }
        let x = (point.x - keyboardBounds.origin.x) / keyboardBounds.width
        let y = (point.y - keyboardBounds.origin.y) / keyboardBounds.height
        return CGPoint(x: max(0, min(1, x)), y: max(0, min(1, y)))
    }

    // MARK: - Feature computation

    /// Computes velocity, direction, and curvature for each point.
    /// Called once after the gesture is complete for cache-friendly batch processing.
    private func computeFeatures() {
        guard points.count >= 2 else { return }

        for i in 0..<points.count {
            // Velocity and direction: use forward difference (backward at last point)
            let (prevIdx, nextIdx) = neighborIndices(i)
            let prev = points[prevIdx]
            let next = points[nextIdx]

            let dx = Float(next.position.x - prev.position.x)
            let dy = Float(next.position.y - prev.position.y)
            let dt = Float(next.timestamp - prev.timestamp)

            if dt > 0 {
                let dist = sqrtf(dx * dx + dy * dy)
                points[i].velocity = dist / dt
            }

            points[i].direction = atan2f(dy, dx)

            // Curvature: rate of change of direction
            if i > 0 && i < points.count - 1 {
                let dirBefore = atan2f(
                    Float(points[i].position.y - points[i - 1].position.y),
                    Float(points[i].position.x - points[i - 1].position.x)
                )
                let dirAfter = atan2f(
                    Float(points[i + 1].position.y - points[i].position.y),
                    Float(points[i + 1].position.x - points[i].position.x)
                )
                var angleDiff = dirAfter - dirBefore
                // Normalize to [-pi, pi]
                while angleDiff > .pi { angleDiff -= 2 * .pi }
                while angleDiff < -.pi { angleDiff += 2 * .pi }

                let segLen = Float(distance(points[i - 1].position, points[i + 1].position))
                points[i].curvature = segLen > 1e-6 ? angleDiff / segLen : 0
            }
        }
    }

    private func neighborIndices(_ i: Int) -> (Int, Int) {
        let prev = max(0, i - 1)
        let next = min(points.count - 1, i + 1)
        return (prev, next)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }
}
