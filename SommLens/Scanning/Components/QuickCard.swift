//
//  QuickCard.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI

struct QuickCard: View {
    let title: String
    let text:  String?
    
    private let cardWidth:  CGFloat = 170
    private let cardHeight: CGFloat = 85
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption).foregroundColor(.burgundy).bold()
            Text(text ?? "-")
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
