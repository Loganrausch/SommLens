//
//  UIImage+Resize.swift
//  SommLens
//
//  Created by Logan Rausch on 6/30/25.
//

import UIKit

// Re-scales an image so its longest edge ≤ maxEdge (keeps aspect ratio).
extension UIImage {
    func resized(maxEdge: CGFloat) -> UIImage {
        let maxLength = max(size.width, size.height)
        guard maxLength > maxEdge else { return self }  // already small enough
        let scale = maxEdge / maxLength
        let newSize = CGSize(width: size.width * scale,
                             height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
