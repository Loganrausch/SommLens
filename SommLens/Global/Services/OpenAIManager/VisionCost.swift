//
//  VisionCost.swift
//  SommLens
//
//  Created by Logan Rausch on 6/30/25.
//

import Foundation
import UIKit

private func visionTokens(detail: String = "low",
                          size: CGSize) -> Int {
    if detail == "low" { return 85 }

    // detail:"high"
    let tiles = ceil(size.width / 512) * ceil(size.height / 512)
    return 85 + Int(tiles) * 170
}

func estimateVisionCost(for image: UIImage,
                        detail: String = "low") -> Double {
    let tokens = visionTokens(detail: detail, size: image.size)
    return Double(tokens) / 1000 * 0.005      // GPT-4o input rate
}

func computeVisionCost(using usage: OpenAIResponse.Usage, fallbackImage: UIImage?) -> Double {
    if let imgTokens = usage.image_tokens {
        print("📦 Using actual image token count from OpenAI: \(imgTokens)")
        return Double(imgTokens) / 1000 * 0.005
    } else if let image = fallbackImage {
        print("📐 Estimating image token usage based on image size")
        return estimateVisionCost(for: image)
    } else {
        print("⚠️ No image or image_tokens available. Cannot compute image cost.")
        return 0.0
    }
}
