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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.latte.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1.2) // subtle edge
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4) // softer than before
    }
}
