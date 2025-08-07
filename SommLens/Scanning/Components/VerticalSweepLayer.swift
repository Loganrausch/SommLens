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
    func updateUIView(_ uiView: UIView, context: Context) {
        let beam = context.coordinator.beam
        let fullWidth = uiView.bounds.width
        guard fullWidth > 1 else { return }           // wait for a real size

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        beam.frame = CGRect(x: 0, y: -heightPx,
                            width: fullWidth, height: heightPx)
        CATransaction.commit()
        
        if !context.coordinator.started {
            context.coordinator.started = true
            startSweep(in: uiView, beam: beam)
        }
    }

    /// pulled-out helper so it can be called inside DispatchQueue.main.async
    private func startSweep(in host: UIView, beam: CAGradientLayer) {
        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue = -heightPx
        anim.toValue   = host.bounds.height + heightPx
        anim.duration  = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)

        CATransaction.begin()
        CATransaction.setCompletionBlock(onDone)      // your callback
        beam.add(anim, forKey: "sweep")
        CATransaction.commit()
    }
}
