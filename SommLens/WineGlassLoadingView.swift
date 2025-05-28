//
//  WineGlassLoadingView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/25/25.
//

import Combine
import SwiftUI

// MARK: – Pulsing wine-glass trio + rotating “sommelier quips”
struct WineGlassLoadingView: View {
    @State private var isActive     = false        // drives the pulse
    @State private var msgIndex     = 0            // which message to show
    @State private var cancellables = Set<AnyCancellable>()
    
    // Feel free to add / edit these phrases
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
            /* ───── 1) Animated icon row ───── */
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color("Burgundy")) // use your brand color
                        .scaleEffect(isActive ? 1.0 : 0.5)
                        .animation(
                            .linear(duration: 0.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(idx) * 0.2),
                            value: isActive
                        )
                }
            }
            
            /* ───── 2) Rotating message ───── */
            Text(messages[msgIndex])
                .font(.subheadline)
                .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .padding(20)
        .background(
            // Ultra-thin material keeps photo context visible, still legible
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .onAppear {
            isActive = true   // kick off the pulse
            
            // Timer that bumps the message every 1.8 s
            Timer.publish(every: 1.8, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        msgIndex = (msgIndex + 1) % messages.count
                    }
                }
                .store(in: &cancellables)
        }
        .onDisappear { cancellables.removeAll() }  // clean up
    }
}
