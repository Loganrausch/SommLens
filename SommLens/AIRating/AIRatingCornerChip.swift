//
//  AIRatingCornerChip.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//

import SwiftUI

enum AIRatingChipState {
    case empty
    case loading
    case impression(String)   // e.g. "Classic Expression"
}

struct AIRatingCornerChip: View {
    let state: AIRatingChipState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {

                Image(systemName: iconName)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Color.burgundy)
                    .imageScale(.medium)

                switch state {

                case .empty:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vini's Impression")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Get Take")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.burgundy)
                        .scaleEffect(0.95)

                case .impression(let text):
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Vini's Take")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(text)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
                if case .loading = state {
                    EmptyView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.burgundy)
                        .opacity(0.7)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.latte).opacity(0.95))   // light latte chip
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.burgundy.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch state {
        case .empty, .loading: return "sparkles"
        case .impression:      return "checkmark.seal.fill"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .empty:
            return "AI Impression. Get take."
        case .loading:
            return "AI Impression. Loading."
        case .impression(let text):
            return "AI impression: \(text). Tap for details."
        }
    }
}
