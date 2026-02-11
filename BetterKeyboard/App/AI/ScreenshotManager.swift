import UIKit
import Photos

enum ScreenshotError: Error, LocalizedError {
    case permissionDenied
    case noScreenshotsFound
    case imageFetchFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Photo library access denied. Please allow access in Settings."
        case .noScreenshotsFound: return "No recent screenshots found. Take a screenshot first, then try again."
        case .imageFetchFailed: return "Failed to load screenshot image"
        case .cancelled: return "Screenshot fetch was cancelled"
        }
    }
}

/// Fetches recent screenshots from the user's photo library.
/// Runs in the containing app only (not the keyboard extension).
final class ScreenshotManager {

    /// Fetch recent screenshots taken within a time window.
    /// - Parameters:
    ///   - limit: Maximum number of screenshots to return (default 5).
    ///   - withinSeconds: How far back to look (default 120 seconds).
    /// - Returns: Array of UIImages sorted by recency (newest first).
    func fetchRecentScreenshots(
        limit: Int = 5,
        withinSeconds: TimeInterval = 120
    ) async throws -> [UIImage] {
        // Check for task cancellation before starting expensive work
        try Task.checkCancellation()

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw ScreenshotError.permissionDenied
        }

        let cutoffDate = Date().addingTimeInterval(-withinSeconds)
        let options = PHFetchOptions()
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "mediaSubtype == %d",
                        PHAssetMediaSubtype.photoScreenshot.rawValue),
            NSPredicate(format: "creationDate > %@", cutoffDate as NSDate)
        ])
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.fetchLimit = limit

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        guard assets.count > 0 else {
            throw ScreenshotError.noScreenshotsFound
        }

        return try await loadImages(from: assets)
    }

    /// Load UIImages from PHAssets using async/await per-asset loading.
    private func loadImages(from assets: PHFetchResult<PHAsset>) async throws -> [UIImage] {
        let manager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = false

        // Screen-native size for OCR quality (iPhone 14 Pro dimensions)
        let targetSize = CGSize(width: 1170, height: 2532)

        var images: [UIImage] = []

        for index in 0..<assets.count {
            try Task.checkCancellation()

            let asset = assets.object(at: index)
            let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: requestOptions
                ) { image, info in
                    // PHImageManager can call the handler with a degraded image first,
                    // then the full-quality one. We only want the final delivery.
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if isDegraded { return }

                    if let image = image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: ScreenshotError.imageFetchFailed)
                    }
                }
            }
            images.append(image)
        }

        return images
    }
}
