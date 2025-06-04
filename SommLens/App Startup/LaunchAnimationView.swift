//
//  LaunchAnimationView.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import SwiftUI

struct LaunchAnimationView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.latte.ignoresSafeArea()

            Image("GlassOnly")
                .resizable()
                .scaledToFit()
                .frame(width: 165)
                // Soft ambient shadow (subtle outer glow)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                // Lift shadow to create floating effect
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
                // Tight drop shadow for grounding
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                .scaleEffect(pulse ? 1 : 0.97)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            
            
            ForEach(0..<4) { i in
                scanCorner(at: i)
            }
        }
        .onAppear {
            pulse = true
        }
    }

    private func scanCorner(at index: Int) -> some View {
        let size: CGFloat = 28
        let offset: CGFloat = 75

        return Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: size, y: 0))
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 0, y: size))
        }
        .stroke(Color.burgundy, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        // ✨ Subtle floating shadow that pulses with animation
        .shadow(color: .black.opacity(pulse ? 0.2 : 0.05), radius: pulse ? 6 : 2, x: 0, y: 3)
        .opacity(pulse ? 1 : 0.25)
        .scaleEffect(pulse ? 1.1 : 0.95)
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
        .frame(width: size, height: size, alignment: .topLeading)
        .rotationEffect(.degrees(cornerRotation(index)))
        .offset(x: cornerOffset(index).x * offset,
                y: cornerOffset(index).y * offset)
    }

    private func cornerRotation(_ index: Int) -> Double {
        [0, 90, 180, 270][index]
    }

    private func cornerOffset(_ index: Int) -> CGPoint {
        [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: -1),
         CGPoint(x: 1, y: 1), CGPoint(x: -1, y: 1)][index]
    }
}

// MARK: - Preview
#Preview {
    LaunchAnimationView()
}
