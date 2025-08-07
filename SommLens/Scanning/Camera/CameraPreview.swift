//
//  CameraPreview.swift
//  SommLens
//
//  Created by Logan Rausch on 8/6/25.
//

import SwiftUI
import UIKit
import AVFoundation


// MARK: Live camera preview with pinch-to-zoom and tap-to-focus

struct CameraPreview: UIViewRepresentable {

    // AVCapture device created in configureSession()
    let session: AVCaptureSession
    let device: AVCaptureDevice

    // UIView subclass with focus ring animation
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        
        private let focusRing = UIView()
        
        // Code based creation init - using this one

           override init(frame: CGRect) {
               super.init(frame: frame)
               setupFocusRing()
           }
        
        // Storyboard or Interface Builder init - required for protocol conformance even if not using

           required init?(coder: NSCoder) {
               super.init(coder: coder)
               setupFocusRing()
           }

           func setupFocusRing() {
               focusRing.layer.borderColor = UIColor(named: "Latte")?.cgColor
               focusRing.layer.borderWidth = 2
               focusRing.layer.cornerRadius = 40
               focusRing.alpha = 0
               focusRing.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
               addSubview(focusRing)
           }

           func showFocusRing(at point: CGPoint) {
               focusRing.center = point
               focusRing.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
               focusRing.alpha = 1

               UIView.animate(withDuration: 0.3, animations: {
                   self.focusRing.transform = .identity
               }) { _ in
                   UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
                       self.focusRing.alpha = 0
                   }, completion: nil)
               }
           }
    }

    // MARK: Coordinator (Gesture handler and camera config via UIKit)
    
    final class Coordinator: NSObject {
        private let device: AVCaptureDevice
        init(device: AVCaptureDevice) { self.device = device }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let view = gesture.view as! PreviewView
            let location = gesture.location(in: view)
            let screenSize = view.bounds.size
            
            // Show animated ring
              view.showFocusRing(at: location)


            let focusPoint = CGPoint(x: location.y / screenSize.height,
                                     y: 1.0 - (location.x / screenSize.width))

            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus error:", error)
            }
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard g.state == .changed || g.state == .ended else { return }

            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
            let minZoom: CGFloat = 1.0
            var newZoom = device.videoZoomFactor * g.scale
            newZoom = max(min(newZoom, maxZoom), minZoom)

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoom
                device.unlockForConfiguration()
            } catch { print("Zoom error:", error) }

            g.scale = 1          // reset incremental scale
        }
    }
   
    
    
    // MARK: SwiftUI–UIKit Bridge
    
    func makeCoordinator() -> Coordinator {
        Coordinator(device: device)
    }

    
    
    // MARK: View Lifecycle (makeUIView / updateUIView)
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = view.videoLayer
        layer.session      = session
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoRotationAngle = 90
        
        // tap gesture
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        // pinch gesture
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
