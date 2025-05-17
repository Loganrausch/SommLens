//
//  ImagePreprocesser.swift
//  SommLens
//
//  Created by Logan Rausch on 5/15/25.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImagePreprocessor {
    private static let context = CIContext()

    /// Crop, enhance contrast, grayscale, and upsample to 2× resolution
    static func preprocess(_ input: UIImage) -> UIImage? {
        guard let ci = CIImage(image: input) else { return nil }

        // 1) (Optional) Crop to a bounding box if you know where your label sits
        //    ci = ci.cropped(to: cropRect)

        // 2) Increase contrast
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = ci
        contrastFilter.contrast = 1.5 // tweak between 1.2–2.0
        guard let contrasted = contrastFilter.outputImage else { return nil }

        // 3) Grayscale
        let monoFilter = CIFilter.photoEffectNoir()
        monoFilter.inputImage = contrasted
        guard let grayed = monoFilter.outputImage else { return nil }

        // 4) Scale up to double size
        let scaleTransform = CGAffineTransform(scaleX: 2, y: 2)
        let scaled = grayed.transformed(by: scaleTransform)

        // 5) Render back to UIImage
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
