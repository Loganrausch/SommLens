//
//  Untitled.swift
//  SommLens
//
//  Created by Logan Rausch on 1/7/26.
//

import SwiftUI
import UIKit

struct ZoomableScrollImage: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        // Make the imageView track the scroll view’s size so it starts centered & fit
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        // Optional: double-tap to zoom in/out
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Nothing to update for now
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            
            if scrollView.zoomScale > 1.01 {
                // Reset zoom
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                // Zoom into where user double-tapped
                let pointInView = gesture.location(in: imageView)
                zoom(to: pointInView, in: scrollView)
            }
        }
        
        private func zoom(to point: CGPoint, in scrollView: UIScrollView) {
            // Just make sure we *have* an imageView; no need to bind it
            guard imageView != nil else { return }

            let newScale: CGFloat = min(scrollView.maximumZoomScale, scrollView.zoomScale * 2.0)
            let scrollViewSize = scrollView.bounds.size

            let width  = scrollViewSize.width  / newScale
            let height = scrollViewSize.height / newScale
            let x      = point.x - (width / 2.0)
            let y      = point.y - (height / 2.0)

            let zoomRect = CGRect(x: x, y: y, width: width, height: height)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}
