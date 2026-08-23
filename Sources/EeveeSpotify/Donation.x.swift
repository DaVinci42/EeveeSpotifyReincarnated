import Foundation
import UIKit

/// Easter egg: on the 5th app launch, show a tappable toast
/// "Hysan's Elsa Recovery Fund: $0 raised. Be the first to contribute ☕"
/// Tapping the action button opens the donation page.
enum Donation {

    private static let launchCountKey = "hysanRecoveryFundLaunchCount"
    private static let hasShownKey = "hysanRecoveryFundShown"
    private static let donationURL = URL(string: "https://ko-fi.com/jaydenjcpy")!

    /// Call once at tweak init. Increments the launch counter and
    /// shows the toast on the 5th launch (once per install).
    static func activate() {
        guard !UserDefaults.standard.bool(forKey: hasShownKey) else { return }

        let count = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(count, forKey: launchCountKey)

        guard count >= 5 else { return }

        // Mark as shown so it never fires again
        UserDefaults.standard.set(true, forKey: hasShownKey)

        // Delay slightly so the UI has time to settle after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showToast()
        }
    }

    private static func showToast() {
        SponsorBlockToast.shared.show(
            message: "☕ Hysan's Elsa Recovery Fund: $0 raised. Be the first to contribute",
            actions: [
                SponsorBlockToastAction(
                    title: "Donate",
                    style: .primary,
                    tintOverride: UIColor(red: 1.0, green: 0.6, blue: 0.8, alpha: 1.0),
                    handler: {
                        UIApplication.shared.open(donationURL, options: [:], completionHandler: nil)
                    }
                )
            ],
            duration: 5.0
        )
    }
}
