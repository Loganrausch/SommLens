//
//  WineGlassLoadingView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/25/25.
//

import Combine
import SwiftUI

struct WineGlassLoadingView: View {
    @State private var isActive = false
    @State private var msgIndex = 0
    @State private var pulseTimer: Cancellable?
    @State private var messageTimer: Cancellable?

    private let messages = [
        "Uncorking the bottle…",
        "Pouring a glass…",
        "Swirling the wine…",
        "Admiring the color…",
        "Taking the first sip…",
        "Letting it breathe…"
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color("Burgundy"))
                        .scaleEffect(isActive ? 1.0 : 0.5)
                        .animation(
                            .linear(duration: 0.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(idx) * 0.2),
                            value: isActive
                        )
                }
            }

            Text(messages[msgIndex])
                .font(.subheadline)
                .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .padding(20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .onAppear {
            isActive = true

            // Haptic pulse timer (bop bop bop... pause)
            var pulseStep = 0
            pulseTimer = Timer.publish(every: 0.2, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    if pulseStep % 5 < 3 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    pulseStep += 1
                }

            // Message change timer (every ~2.5s)
            messageTimer = Timer.publish(every: 2.5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        msgIndex = (msgIndex + 1) % messages.count
                    }
                }
        }
        .onDisappear {
            pulseTimer?.cancel()
            messageTimer?.cancel()
            pulseTimer = nil
            messageTimer = nil
        }
    }
}
