//
//  ShimmerOverlay.swift
//  SommLens
//
//  Created by Logan Rausch on 5/5/25.
//

import SwiftUI

struct HorizontalShimmer: View {
    /// seconds for one left→right pass
    var speed: Double = 0.8
    /// fraction of the screen the beam occupies (e.g. 0.25 = 25% width)
    var beamWidthFraction: CGFloat = 0.25

    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let beamW = w * beamWidthFraction

            // a vertical gradient band, narrow & tall
            Rectangle()
                .fill(
                    LinearGradient(
                      gradient: Gradient(stops: [
                        .init(color: Color("Burgundy").opacity(0.0), location: 0.0),
                            .init(color: Color("Burgundy").opacity(0.3), location: 0.5),
                            .init(color: Color("Burgundy").opacity(0.0), location: 1.0),
                      ]),
                      startPoint: .bottomLeading,
                      endPoint:   .topTrailing
                    )
                )
                .frame(width: beamW, height: h)
                // offset from completely off-left (phase = -1) to off-right (phase = +1)
                .offset(x: phase * (w + beamW))
                .onAppear {
                    phase = -1
                    withAnimation(
                        Animation.linear(duration: speed)
                                 .repeatForever(autoreverses: false)
                    ) {
                        phase = 1
                    }
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
