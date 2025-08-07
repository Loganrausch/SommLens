//
//  FreezeOverlay.swift
//  SommLens
//
//  Created by Logan Rausch on 8/6/25.
//

import SwiftUI
import UIKit

private enum OverlayPhase {
    case sweep, processing
}

struct FreezeOverlay: View {
    let overlayImage: UIImage
    @Binding var isProcessing: Bool
    
    @State private var phase: OverlayPhase = .sweep

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: overlayImage)
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width,
                       height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()

            switch phase {
            case .sweep:
                VerticalSweepLayer {
                    // called when sweep finishes
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .processing
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            case .processing:
                         
                          WineGlassLoadingView()
                      }
                  }
                  .zIndex(1)
              }
          }
