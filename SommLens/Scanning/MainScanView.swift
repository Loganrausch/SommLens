
//  ARScanView.swift
//  VinoBytes
//

import SwiftUI
import UIKit               // for UIImage
import AVFoundation
import CoreImage
import CoreData
import RevenueCatUI
// ─────────────────────────────────────────────────────────────
// 1) Your ScanResult model
// ─────────────────────────────────────────────────────────────
struct ScanResult: Identifiable, Hashable {
    let id       = UUID()
    let bottle:     BottleScan   // ← store the Core-Data row
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
        
        private let focusRing = UIView()

           override init(frame: CGRect) {
               super.init(frame: frame)
               setupFocusRing()
           }

           required init?(coder: NSCoder) {
               super.init(coder: coder)
               setupFocusRing()
           }

           private func setupFocusRing() {
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

    // ---------- Coordinator handles gestures ----------
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

    func makeCoordinator() -> Coordinator { Coordinator(device: device) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = view.videoLayer
        layer.session      = session
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        
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

private enum OverlayPhase { case sweep, processing }

struct FreezeOverlay: View {
    let overlayImage: UIImage
    @Binding var isProcessing: Bool
    
    @State private var phase: OverlayPhase = .sweep

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

            switch phase {
            case .sweep:
                VerticalSweepLayer {
                    // called when sweep finishes
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .processing
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // ← important
                .ignoresSafeArea()
                      case .processing:
                          // the same wine-glass loader you already have
                          WineGlassLoadingView()
                      }
                  }
                  .zIndex(1)
              }
          }
       
                    
                
            
        
    


// ─────────────────────────────────────────────────────────────
// 6) Main ARScanView: tap shutter → freeze → improved OCR → AI → result
// ─────────────────────────────────────────────────────────────
struct MainScanView: View {
    @EnvironmentObject var auth: AuthViewModel               // ← add
    @Environment(\.managedObjectContext) private var ctx
    @StateObject private var ai = OpenAIManager()
    
    // camera + photo capture
    @State private var session     = AVCaptureSession()
    @State private var photoOutput = AVCapturePhotoOutput()
    @State private var photoDel: PhotoDelegate?
    
    // freeze + AI(image) + navigation
   
   
   
    @State private var captureDevice: AVCaptureDevice?
    @State private var bufferDelegate = BufferDelegate()
    @State private var highResImage: UIImage? = nil
    @State private var reachedProLimit = false                // ← alert for Pro users
    @State private var didShowPaywall = false
    @State private var showScanError = false
    
    @Binding var selectedTab: MainTab
    @Binding var frozenImage: UIImage?
    @Binding var scanResult: ScanResult?
    @Binding var isProcessing: Bool
    @Binding var showOverlay: Bool
    @Binding var hasExtracted: Bool
    
    
    private var canScan: Bool {
        auth.canScan(currentCount: auth.getScanCount())
    }
    
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
                ScanResultView(
                    bottle:       res.bottle,   // ← pass it
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
                        
                        // After saving a scan result
                        EngagementMilestones.increment("scanShareCount",  type: .share)
                        EngagementMilestones.increment("scanReviewCount", type: .review)

                    },
                    selectedTab: $selectedTab
                )
            }
        }
        .alert("Scan failed", isPresented: $showScanError) {
            Button("Try Again", role: .cancel) { }
        } message: {
            Text("Something went wrong analyzing the label. Please try again.")
        }
       
        
        .alert("Scan Limit Reached",
               isPresented: $reachedProLimit) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Wow, you scanned 200 wines this month! Your scan limit resets on the first of each month. Thank you for being a SommLens Pro user.")
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
        
        // ⚠️ quota check
        guard canScan else {
            if auth.hasActiveSubscription {
                reachedProLimit = true            // 200 reached
            } else {
                auth.isPaywallPresented = true   // free user upsell
            }
            return
        }
        
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
                            let bottle = saveScan(        // ← returns BottleScan
                                in:         ctx,
                                wineData:   wine,
                                rawJSON:    rawJSON,
                                screenshot: hiRes
                            )
                            
                            auth.incrementScanCount()
                            
                            // 4️⃣  Push navigation with that row
                            scanResult = ScanResult(
                                bottle:    bottle,
                                image:     hiRes,
                                wineData:  wine
                                // NEW argument
                            )
                            
                        case .failure(let error):
                            print("❌ Extraction failed:", error.localizedDescription)

                            frozenImage   = nil
                            highResImage  = nil
                            isProcessing  = false
                            showOverlay   = false
                            hasExtracted  = false
                            showScanError = true

                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                }
            }
        }
        
        photoDel = del
        photoOutput.capturePhoto(with: settings, delegate: del)
    }
}

final class BufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // 1️⃣  One CIContext, one queue, forever.
    private let renderQueue = DispatchQueue(label: "ci.render.serial")
    private let ciContext   = CIContext(options: nil)   // GPU by default

    // 2️⃣  Simple re-entrancy guard (optional but nice)
    private var isRendering = false

    var onFrame: ((UIImage) -> Void)?

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard !isRendering else { return }
        isRendering = true
        renderQueue.async { [weak self] in
            defer { self?.isRendering = false }

            guard
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }

            var ciImage = CIImage(cvImageBuffer: imageBuffer)

            // 3️⃣  Discard zero-sized or bogus frames
            guard !ciImage.extent.isEmpty else { return }

            // 4️⃣  Explicit colours (fixes iOS 17 HDR crash paths)
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
                self?.onFrame?(uiImage)   // downstream resize / OpenAI
            }
        }
    }
}

private func saveScan(in ctx: NSManagedObjectContext,
                      wineData: WineData,
                      rawJSON: String,
                      screenshot: UIImage?
) -> BottleScan {
    let scan = BottleScan(context: ctx)
    scan.id              = UUID()
    scan.fingerprint     = wineData.id          // ← add this line
    scan.timestamp       = Date()
    scan.producer        = wineData.producer
    scan.region          = wineData.region
    scan.subregion       = wineData.subregion
    scan.appellation     = wineData.appellation
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
    
    return scan                       // ← NEW
}
