//
//  LaunchAnimationView.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import SwiftUI

struct LaunchAnimationView: View {
    @State private var glowOpacity: Double = 0
    @State private var scanOffset: CGFloat = -60
    @State private var scanOpacity: Double = 0
    @State private var pulse = false

    private let scanDuration: Double = 2.2

    var body: some View {
        ZStack {
            Color(hex: "#F5EDE7")
                .ignoresSafeArea()

            Group {
                Image("GlassOnly")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 165)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .opacity(glowOpacity)

                ZStack {
                    //glow
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#C07A5C").opacity(0),
                                    Color(hex: "#C07A5C").opacity(0.9),
                                    Color(hex: "#C07A5C").opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 145, height: 10)

                    //hard line
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#C07A5C").opacity(0),
                                    Color(hex: "#C07A5C").opacity(0.6),
                                    Color(hex: "#C07A5C").opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 2)
                }
                .offset(y: scanOffset)
                .opacity(scanOpacity)
            }
            .scaleEffect(pulse ? 1.02 : 0.97)
            .animation(
                pulse ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                value: pulse
            )
        }
        .onAppear {
            // Glass fades in
            withAnimation(.easeIn(duration: 0.5)) {
                glowOpacity = 1
            }

            // Scan sweeps once after glass appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                scanOpacity = 1
                withAnimation(.easeInOut(duration: scanDuration)) {
                    scanOffset = 60
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + scanDuration - 0.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scanOpacity = 0
                    }
                }
            }

            // Pulse holds after scan completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + scanDuration + 0.2) {
                pulse = true
            }
        }
    }
}

#Preview {
    LaunchAnimationView()
}

