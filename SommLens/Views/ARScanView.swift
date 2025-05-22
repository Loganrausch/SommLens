
//  ARScanView.swift
//  VinoBytes
//

import SwiftUI
import UIKit               // for UIImage
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreData

// ─────────────────────────────────────────────────────────────
// 1) Your ScanResult model
// ─────────────────────────────────────────────────────────────
struct ScanResult: Identifiable, Hashable {
    let id       = UUID()
    let image: UIImage
    let wineData: WineData

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func ==(a: ScanResult, b: ScanResult) -> Bool { a.id == b.id }
}

// ─────────────────────────────────────────────────────────────
// 2) Live camera preview with pinch-to-zoom
// ─────────────────────────────────────────────────────────────
struct CameraPreview: UIViewRepresentable {

    // AVCapture device we created in configureSession()
    let session: AVCaptureSession
    let device: AVCaptureDevice               // ← new

    // ---------- UIView subclass whose CA-layer *is* a preview layer ----------
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    // ---------- Coordinator handles gestures ----------
    final class Coordinator: NSObject {
        private let device: AVCaptureDevice
        init(device: AVCaptureDevice) { self.device = device }

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

    func makeCoordinator() -> Coordinator { Coordinator(device: device) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = view.videoLayer
        layer.session      = session
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait

        // pinch gesture
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

// ─────────────────────────────────────────────────────────────
// 3) PhotoDelegate for high-res stills
// ─────────────────────────────────────────────────────────────
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


// ─────────────────────────────────────────────────────────────
// 5) FreezeOverlay (show frozen frame + shimmer + AI call)
// ─────────────────────────────────────────────────────────────
struct FreezeOverlay: View {
    let overlayImage: UIImage
    @Binding var isProcessing: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: overlayImage)
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width,
                       height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()

            if isProcessing {
                HorizontalShimmer(speed: 0.8, beamWidthFraction: 0.2)
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                    .ignoresSafeArea()
            }
        }
        .zIndex(1)
    }
}
       
                    
                
            
        
    


// ─────────────────────────────────────────────────────────────
// 6) Main ARScanView: tap shutter → freeze → improved OCR → AI → result
// ─────────────────────────────────────────────────────────────
struct ARScanView: View {
    @Environment(\.managedObjectContext) private var ctx
    @StateObject private var ai = OpenAIManager()
    
    // camera + photo capture
    @State private var session     = AVCaptureSession()
    @State private var photoOutput = AVCapturePhotoOutput()
    @State private var photoDel: PhotoDelegate?
    
    // freeze + AI(image) + navigation
    @State private var frozenImage  : UIImage?
    @State private var isProcessing = false
    @State private var scanResult   : ScanResult?
    @State private var captureDevice: AVCaptureDevice?
    @State private var showOverlay = false
    @State private var hasExtracted = false
    @State private var bufferDelegate = BufferDelegate()
    @State private var highResImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1) Live camera preview
                if let dev = captureDevice {
                    CameraPreview(session: session, device: dev)
                        .ignoresSafeArea()
                }
                
                // 2) FreezeOverlay: UI only
                if let img = frozenImage, showOverlay {
                  FreezeOverlay(
                    overlayImage: img,
                    isProcessing: $isProcessing
                  )
                  .transition(.identity)          // no transition
                  .animation(nil, value: showOverlay)
                }
                
                // 3) Shutter button
                if frozenImage == nil && !isProcessing {
                    VStack {
                        Spacer()
                        Button {
                            takePhoto()
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.largeTitle)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(30)
                    }
                }
            }
            .onAppear(perform: configureSession)
            .navigationDestination(item: $scanResult) { res in
                ARScanResultView(
                    capturedImage: res.image,
                    wineData: res.wineData,
                    onDismiss: {
                        // 1️⃣ Reset state BEFORE dismissing
                        frozenImage   = nil
                        highResImage  = nil
                        isProcessing  = false
                        scanResult    = nil
                        showOverlay   = false
                        hasExtracted  = false
                    }
                )
            }
        }
    }
    
    
    
    private func configureSession() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // 1️⃣ Add camera input
        if let cam = AVCaptureDevice.default(.builtInWideAngleCamera,
                                             for: .video,
                                             position: .back),
           let input = try? AVCaptureDeviceInput(device: cam),
           session.canAddInput(input) {
            session.addInput(input)
            captureDevice = cam
        }
        
        // 2️⃣ Add photo output (for high-res image)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        
        // 3️⃣ Add video buffer output (for instant overlay)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(bufferDelegate, queue: DispatchQueue(label: "bufferQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        
        // 🔧 4️⃣ Force orientation to portrait (AFTER commitConfiguration)
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        // 4️⃣ Start running
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func takePhoto() {
        // 1️⃣ Re-install the one-shot handler on each tap…
        bufferDelegate.onFrame = { image in
            DispatchQueue.main.async {
                // only freeze once
                guard frozenImage == nil && !isProcessing else { return }

                // Freeze immediately
                frozenImage  = image
                showOverlay  = true
                hasExtracted = false

                // Disable further freezes until the next tap
                bufferDelegate.onFrame = nil
            }
        }

        
        // 1️⃣ Kick off the high-res capture immediately
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
        
        let del = PhotoDelegate { img in
            Task { @MainActor in
                guard let hiRes = img else { return }
                
                // show the shimmer
                highResImage = hiRes
                isProcessing = true
                
                // 2️⃣ Only _now_ call AI on the high-res image:
                ai.extractWineInfo(from: hiRes) { result in
                    DispatchQueue.main.async {
                        isProcessing = false
                        switch result {
                        case .success(let wine):
                            // ─── SAVE YOUR SCAN HERE ───
                            let rawJSON = (try? JSONEncoder().encode(wine))
                                .flatMap { String(data: $0, encoding: .utf8) }
                            ?? "{}"
                            saveScan(in: ctx,
                                     wineData: wine,
                                     rawJSON: rawJSON,
                                     screenshot: hiRes)
                            
                            // ─── NAVIGATE ───
                            scanResult = ScanResult(image: hiRes, wineData: wine)
                            
                        case .failure(let error):
                            print("❌ Extraction failed:", error)
                        }
                    }
                }
            }
        }
        
        photoDel = del
        photoOutput.capturePhoto(with: settings, delegate: del)
    }
}

class BufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: ((UIImage) -> Void)?  // callback to pass frozen buffer image

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()

        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.onFrame?(uiImage)
            }
        }
    }
}

private func saveScan(in ctx: NSManagedObjectContext,
                      wineData: WineData,
                      rawJSON: String,
                      screenshot: UIImage?) {
    let scan = BottleScan(context: ctx)
    scan.id              = UUID()
    scan.timestamp       = Date()
    scan.producer        = wineData.producer
    scan.region          = wineData.region
    scan.country         = wineData.country
    scan.grapes          = wineData.grapes?.joined(separator: ", ")
    scan.vintage         = wineData.vintage
    scan.classification  = wineData.classification
    scan.tastingNotes    = wineData.tastingNotes
    scan.pairings        = wineData.pairings?.joined(separator: ", ")
    scan.vibeTag         = wineData.vibeTag
    scan.vineyard        = wineData.vineyard
    scan.soilType        = wineData.soilType
    scan.climate         = wineData.climate
    scan.drinkingWindow  = wineData.drinkingWindow
    scan.abv             = wineData.abv
    scan.winemakingStyle = wineData.winemakingStyle
    scan.category        = wineData.category.rawValue
    scan.rawJSON         = rawJSON
    scan.screenshot      = screenshot?.jpegData(compressionQuality: 0.8)
    try? ctx.save()
}
