//
//  AIRatingCornerChip.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//

import SwiftUI

enum AIRatingChipState {
    case empty            // "Get rating"
    case loading          // spinner
    case score(Double)       // e.g. 93
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
                        Text("Rating")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Get rating")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.burgundy)
                        .scaleEffect(0.95)

                case .score(let val):
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Vini's Rating")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", val))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .minimumScaleFactor(0.85)
                            Text("/10")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.96))   // light chip
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
        case .score:           return "star.fill"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .empty:
            return "AI Rating. Get rating."
        case .loading:
            return "AI Rating. Loading."
        case .score(let val):
            return "AI Rating \(String(format: "%.1f", val)) out of 10. Tap for details."
        }
    }
}
