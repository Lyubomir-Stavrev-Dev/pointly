import Foundation
import StoreKit

/// Requests an App Store rating at a natural positive moment — after the user
/// has completed a handful of overlay sessions — throttled to once per app
/// version. The system additionally caps how often the prompt actually appears
/// (max 3 per 365 days) and suppresses it in TestFlight, so this is best-effort.
enum ReviewManager {
    private static let sessionCountKey = "reviewPromptSessionCount"
    private static let lastPromptedVersionKey = "reviewPromptLastVersion"

    /// Number of completed overlay sessions before we ask.
    private static let sessionThreshold = 4

    /// Call when the user finishes an overlay session (overlay hidden).
    /// Counts the session and, once the threshold is reached, asks for a review
    /// at most once per app version.
    static func recordCompletedSession() {
        let defaults = UserDefaults.standard

        // Never prompt more than once for the same app version.
        if defaults.string(forKey: lastPromptedVersionKey) == appVersion { return }

        let count = defaults.integer(forKey: sessionCountKey) + 1
        defaults.set(count, forKey: sessionCountKey)

        guard count >= sessionThreshold else { return }

        defaults.set(appVersion, forKey: lastPromptedVersionKey)
        // Restart the count so the next app version waits a full threshold of
        // sessions again instead of prompting on its very first session.
        defaults.set(0, forKey: sessionCountKey)
        requestReview()
    }

    private static func requestReview() {
        DispatchQueue.main.async {
            SKStoreReviewController.requestReview()
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
