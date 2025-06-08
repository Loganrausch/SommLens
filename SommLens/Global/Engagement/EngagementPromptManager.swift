//
//  ReviewRequestHelper.swift
//  SommLens
//
//  Created by Logan Rausch on 5/29/25.
//

import SwiftUI
import StoreKit

enum EngagementPromptType { case review, share }

struct EngagementPromptManager {
    static var engagementState: EngagementState?

    private static let lastPromptKey = "lastEngagementPrompt"
    private static let cooldown: TimeInterval = 8 * 60 * 60

    static func request(_ type: EngagementPromptType) {
        let now = Date()
        let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date ?? .distantPast

        guard now.timeIntervalSince(lastPrompt) >= cooldown else {
            return
        }

        switch type {
        case .review:
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                SKStoreReviewController.requestReview(in: scene)
            } else {
                print("⚠️ No active window scene available for review prompt.")
            }
            
        case .share:
            // Show *your* in-app custom share alert
            DispatchQueue.main.async {
                engagementState?.showSharePrompt = true
            }
        }

        UserDefaults.standard.set(now, forKey: lastPromptKey)
    }
}
