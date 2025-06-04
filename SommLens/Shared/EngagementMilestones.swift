//
//  EngagementMilestones.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import Foundation

struct EngagementMilestones {
    static func increment(_ key: String, type: EngagementPromptType) {
        let defaults = UserDefaults.standard
        let newCount = defaults.integer(forKey: key) + 1
        defaults.set(newCount, forKey: key)

        switch type {
        case .review:
            if newCount % 12 == 3 {
                EngagementPromptManager.request(.review)
            }
        case .share:
            if newCount % 12 == 8 {
                EngagementPromptManager.request(.share)
            }
        }
    }
}
