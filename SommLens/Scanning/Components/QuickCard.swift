//
//  QuickCard.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI

struct QuickCard: View {
    let title: String
    let text: String?

    private let cardWidth: CGFloat = 170
    private let cardHeight: CGFloat = 85
    private let copper = Color(hex: "#C8816A")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.burgundy)

            Text(displayText)
                .font(.headline.weight(.semibold))
                .foregroundColor(.black)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(copper.opacity(0.35), lineWidth: 1.0)
        )
    }

    private var displayText: String {
        guard let text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "—"
        }
        return text
    }
}
