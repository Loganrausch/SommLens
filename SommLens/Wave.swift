//
//  Wave.swift
//  SommLens
//
//  Created by Logan Rausch on 4/25/25.
//

import SwiftUI

/// A horizontal sine-wave shape that closes at the bottom edge.
struct Wave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.minY + amplitude
        let width = rect.width
        let step: CGFloat = 1

        // Start at left, at mid-amplitude
        p.move(to: CGPoint(x: 0, y: midY))

        // Draw sine wave across the width
        for x in stride(from: 0, through: width, by: step) {
            let pct = x / width
            let theta = pct * .pi * 2 + phase
            let y = sin(theta) * amplitude + midY
            p.addLine(to: CGPoint(x: x, y: y))
        }

        // Close the shape by drawing down & back to start
        p.addLine(to: CGPoint(x: width, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0,     y: rect.maxY))
        p.closeSubpath()

        return p
    }
}
