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
    case impression(String)
}

struct AIRatingCornerChip: View {
    let state: AIRatingChipState
    let action: () -> Void

    private let copper = Color(hex: "#C8816A")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.burgundy.opacity(0.28))
                        .frame(width: 30, height: 30)

                    if case .loading = state {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(copper)
                            .scaleEffect(0.72)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(copper)
                    }
                }

                switch state {
                case .empty:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vini's Impression")
                            .font(.system(size: 10, weight: .medium))
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.82))

                        Text("Get Take")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                case .loading:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vini's Impression")
                            .font(.system(size: 10, weight: .medium))
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.82))

                        Text("Getting impression...")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                case .impression(let text):
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vini's Take")
                            .font(.system(size: 10, weight: .medium))
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.82))

                        Text(text)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }

                if case .loading = state {
                    EmptyView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(copper)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.80))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(copper.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch state {
        case .empty, .loading:
            return "sparkles"
        case .impression:
            return "checkmark.seal.fill"
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
