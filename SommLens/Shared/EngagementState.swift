//
//  EngagementState.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import SwiftUI

final class EngagementState: ObservableObject {
    @Published var showReviewPrompt = false
    @Published var showSharePrompt = false
}
