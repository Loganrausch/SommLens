//
//  SimulatedScanView.swift
//  SommLens
//
//  Created by Logan Rausch on 6/2/25.
//

import SwiftUI

struct SimulatedScanView: View {
    let image: UIImage

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 📸 Centered background bottle
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height + 120) // taller to allow upward shift
                    .clipped()
                    .offset(y: -50) // shift up if needed
                    .ignoresSafeArea()

                // 🍷 WineGlass shimmer view
                               WineGlassLoadingView()
                           }
                       }
                   }
               }
