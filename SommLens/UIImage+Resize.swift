//
//  UIImage+Resize.swift
//  SommLens
//
//  Created by Logan Rausch on 5/21/25.
//

import UIKit

extension UIImage {
    /// Resizes to max 512px on longest edge, then compresses to 60% JPEG.
    /// This ensures OpenAI charges for only 1 image tile.
    func resizedForLabelScan(maxDimension: CGFloat = 512) -> Data? {
        let aspectRatio = size.width / size.height

        // Calculate new size, keeping both sides ≤ maxDimension
        let newSize: CGSize
        if size.width > size.height {
            let height = maxDimension / aspectRatio
            newSize = CGSize(width: maxDimension, height: height)
        } else {
            let width = maxDimension * aspectRatio
            newSize = CGSize(width: width, height: maxDimension)
        }

        // Render resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Compress to JPEG at 60% quality
        let jpeg = resized?.jpegData(compressionQuality: 0.6)

        // Debug logs
        if let img = resized, let jpeg = jpeg {
            print("📏 Resized image dimensions: \(Int(img.size.width))×\(Int(img.size.height))")
            print("📦 Compressed JPEG size: \(jpeg.count / 1024) KB")
        }

        return jpeg
    }
}
