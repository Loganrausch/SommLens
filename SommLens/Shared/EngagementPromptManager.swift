//
//  ReviewRequestHelper.swift
//  SommLens
//
//  Created by Logan Rausch on 5/29/25.
//

import StoreKit
import UIKit
import SwiftUI

enum EngagementPromptType { case review, share }


struct EngagementPromptManager {
    
    private static var keyWindowRoot: UIViewController? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    private static let lastPromptKey = "lastEngagementPrompt"
    private static let cooldown: TimeInterval = 8 * 60 * 60   // 8-hour gap

    static func request(_ type: EngagementPromptType) {
        // 1️⃣ Cool-down
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: lastPromptKey) as? Date,
           now.timeIntervalSince(last) < cooldown { return }

        // 2️⃣ Dispatch on main
        DispatchQueue.main.async {
            switch type {
            case .review:
                askForReview()

            case .share:
                confirmThenShare()
            }
            // 3️⃣ Timestamp
            UserDefaults.standard.set(Date(), forKey: lastPromptKey)
        }
    }

    // MARK: - Private helpers

    private static func askForReview() {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    /// Shows a polite alert *first*, then presents UIActivityViewController if the user agrees
    private static func confirmThenShare() {
        guard let root = keyWindowRoot else { return }

        let alert = UIAlertController(
            title: "Love SommLens?",
            message: "Let your friends know about this wine-scanning app!",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            let text = "I’m using SommLens to scan and learn about wine. Check it out!"
            let ac   = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            root.present(ac, animated: true)
        })

        root.present(alert, animated: true)
    }
}





struct EngagementMilestones {
    static func increment(_ key: String, type: EngagementPromptType) {
        let defaults  = UserDefaults.standard
        let newCount  = defaults.integer(forKey: key) + 1
        defaults.set(newCount, forKey: key)

        switch type {

        case .review:
            // 3, 15, 27, 39, 51, …  (every 12)
            if newCount % 12 == 3 {
                EngagementPromptManager.request(.review)
            }

        case .share:
            // 8, 20, 32, 44, 56, …  (every 12, offset by 5)
            if newCount % 12 == 8 {
                EngagementPromptManager.request(.share)
            }
        }
    }
}
