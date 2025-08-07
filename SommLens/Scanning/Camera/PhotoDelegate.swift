//
//  PhotoDelegate.swift
//  SommLens
//
//  Created by Logan Rausch on 8/6/25.
//

import UIKit
import AVFoundation

// PhotoDelegate for high-res stills

class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let callback: (UIImage?) -> Void
    init(_ cb: @escaping (UIImage?) -> Void) { callback = cb }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let img  = UIImage(data: data)
        else {
            callback(nil)
            return
        }
        callback(img)
    }
}
