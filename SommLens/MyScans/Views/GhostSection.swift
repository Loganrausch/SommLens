//
//  GhostSection.swift
//  SommLens
//
//  Created by Logan Rausch on 3/31/26.
//

// GhostSection.swift
// Drop this file into your project alongside WineDetailView.

import SwiftUI

/// Wraps any content in a blurred, non-interactive ghost preview.
/// Used for locked Pro sections so users see the *shape* of what they're missing.
struct GhostSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .blur(radius: 4.5)   // ← keep this strong enough
            .opacity(0.85)
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
