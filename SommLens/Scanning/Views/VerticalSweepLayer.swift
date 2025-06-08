//
//  VerticalLaserScanOneShot.swift
//  SommLens
//
//  Created by Logan Rausch on 5/25/25.
//

import SwiftUI
import UIKit

struct VerticalSweepLayer: UIViewRepresentable {
    var duration : CFTimeInterval = 0.9
    var color    : UIColor        = UIColor(named: "Burgundy") ?? .systemRed
    var heightPx : CGFloat        = 30
    var onDone   : () -> Void

    // ───────── Coordinator keeps the beam and a “started” flag
    final class Coordinator {
        let beam = CAGradientLayer()
        var started = false
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    // ───────── Build the host view and beam layer
    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.isUserInteractionEnabled = false
        host.backgroundColor = .clear

        let beam = context.coordinator.beam
        beam.colors = [
            color.withAlphaComponent(0.0).cgColor,
            color.withAlphaComponent(0.9).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        beam.startPoint = CGPoint(x: 0.5, y: 0.0)
        beam.endPoint   = CGPoint(x: 0.5, y: 1.0)

        /* ─── NEW: soft glow ─── */
               beam.shadowColor   = color.cgColor
               beam.shadowOpacity = 0.9            // 0‒1
               beam.shadowRadius  = 15              // blur amount
               beam.shadowOffset  = .zero          // glow all around
               /* ────────────────────── */
        // ─── Animate the glow ───
           let glowAnim = CABasicAnimation(keyPath: "shadowOpacity")
           glowAnim.fromValue      = 0.6
           glowAnim.toValue        = 0.95
           glowAnim.duration       = 0.5
           glowAnim.autoreverses   = true
           glowAnim.repeatCount    = .infinity
           beam.add(glowAnim, forKey: "glowPulse")

           host.layer.addSublayer(beam)
           return host
       }
    // ───────── Called every time SwiftUI knows the final frame
    func updateUIView(_ uiView: UIView,
                      context: Context)
    {
        let beam      = context.coordinator.beam
        let fullWidth = uiView.bounds.width
        guard fullWidth > 1 else { return }          // no size yet

        // Ensure the beam’s frame matches the host width
        beam.frame = CGRect(x: 0,
                            y: -heightPx,
                            width: fullWidth,
                            height: heightPx)

        // Start the animation only once
        if !context.coordinator.started {
            context.coordinator.started = true

            let anim = CABasicAnimation(keyPath: "position.y")
            anim.fromValue = -heightPx
            anim.toValue   = uiView.bounds.height + heightPx
            anim.duration  = duration
            anim.timingFunction = CAMediaTimingFunction(name: .linear)

            CATransaction.begin()
            CATransaction.setCompletionBlock(onDone)
            beam.add(anim, forKey: "sweep")
            CATransaction.commit()
        }
    }
}
