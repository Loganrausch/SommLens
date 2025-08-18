//
//  BufferDelegate.swift
//  SommLens
//
//  Created by Logan Rausch on 8/6/25.
//

import UIKit
import AVFoundation
import CoreImage

final class BufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // One CIContext, one queue, forever.
    private let renderQueue = DispatchQueue(label: "ci.render.serial")
    private let ciContext   = CIContext(options: nil)   // GPU by default

    // Simple re-entrancy guard (optional but nice)
    private var isRendering = false

    var onFrame: ((UIImage) -> Void)?

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // To prevent overload we load one frame at a time
        
        guard !isRendering else { return }
        isRendering = true
        renderQueue.async { [weak self] in
            defer { self?.isRendering = false }

            guard
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }

            let ciImage = CIImage(cvImageBuffer: imageBuffer)

            // Discard zero-sized or bogus frames
            guard !ciImage.extent.isEmpty else { return }

            // Explicit colours (fixes iOS 17 HDR crash paths)
            let rgb = CGColorSpaceCreateDeviceRGB()

            guard
                let cgImage = self?.ciContext
                    .createCGImage(ciImage,
                                   from: ciImage.extent,
                                   format: .RGBA8,
                                   colorSpace: rgb)
            else { return }

            let uiImage = UIImage(cgImage: cgImage)

            DispatchQueue.main.async {
                self?.onFrame?(uiImage)  
            }
        }
    }
}
