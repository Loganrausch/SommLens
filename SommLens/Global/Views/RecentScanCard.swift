//
//  Untitled.swift
//  SommLens
//
//  Created by Logan Rausch on 1/6/26.
//

import SwiftUI
import UIKit

// MARK: – RecentScanCard
struct RecentScanCard: View {
    let wine: WineData?
    let image: UIImage?
    let isTasted: Bool   // ✅ NEW
    
    var body: some View {
        VStack(spacing: 6) {
            
            ZStack(alignment: .topTrailing) {   // ✅ alignment added
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(radius: 4)
                    .frame(height: 140)

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Color.secondary.opacity(0.1)
                        .frame(height: 140)
                        .cornerRadius(12)
                        .overlay(
                            Text("No Image")
                                .foregroundColor(.secondary)
                        )
                }

                if isTasted {
                    Text("Tasted")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.burgundy.opacity(0.95))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            
            
            
            if let wine = wine {
                Text("\(wine.vintage ?? "-") • \(wine.producer ?? "Unknown")")
                    .font(.caption.bold())
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(wine.region ?? "-")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No Data")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 140)
    }
}
