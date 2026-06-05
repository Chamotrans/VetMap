import StoreKit
import SwiftUI

enum RatingPrompt {
    private static let launchCountKey = "appLaunchCount"
    private static let lastPromptDateKey = "lastRatingPromptDate"

    static func incrementLaunchCount() {
        let count = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(count, forKey: launchCountKey)
    }

    static func shouldRequestReview() -> Bool {
        let count = UserDefaults.standard.integer(forKey: launchCountKey)
        guard count >= 5 else { return false }

        let lastPrompt = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date
        guard lastPrompt == nil || Date().timeIntervalSince(lastPrompt!) > 30 * 24 * 3600 else { return false }

        return true
    }

    static func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
