//
//  CardBlock.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI

struct CardBlock<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.burgundy)
            
            content
        }
        .padding(20)
        .background(.latte) // ← Matches the frosted image card look
        .cornerRadius(24)
        .shadow(color: .primary.opacity(0.2), radius: 12, x: 0, y: 6) // ← More pronounced shadow
        .padding(.horizontal)
    }
}

