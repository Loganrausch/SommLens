//
//  SquishyButtonStyle.swift
//  SommLens
//
//  Created by Logan Rausch on 5/5/25.
//

import SwiftUI

// 1) Define a “squishy” ButtonStyle
struct SquishyButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // spring animation on press
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}
