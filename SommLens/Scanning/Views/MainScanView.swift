
//
//  MainScanView.swift
//  SommLens
//
//  This view manages a tightly-timed camera capture flow for wine label scanning.
//  While a pure MVVM approach was prototyped, it introduced lifecycle bugs due to SwiftUI view reuse,
//  especially inside a TabView context (e.g., session duplication, premature delegate release).
//
//  To ensure clarity and lifecycle correctness, camera state, timing, and navigation logic are kept
//  scoped to this view. Stateless components like overlays and delegates are extracted to dedicated files.
//  For single-responsibility, real-time features like this, reliability and user experience take priority
//  over architectural purity.
//
//  Summary:
//  - View-scoped state: AVCaptureSession, device, delegates, navigation
//  - Stateless components: CameraPreview, BufferDelegate, PhotoDelegate, overlays
//  - One-shot flow: tap shutter → freeze → capture hi-res → AI → save → navigate
//

import SwiftUI
import UIKit
import AVFoundation
import CoreData
import CoreMedia


// MainScanView: tap shutter - freeze - AI - result

struct MainScanView: View {
    
    // MARK: - Dependencies
    
    @EnvironmentObject var openAIManager: OpenAIManager
    @EnvironmentObject var engagementState: EngagementState
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.managedObjectContext) private var ctx
    
    // MARK: - Bindings from Parent
    
    @Binding var selectedTab: MainTab
    @Binding var frozenImage: UIImage?
    @Binding var scanResult: ScanResult?
    @Binding var isProcessing: Bool
    @Binding var showOverlay: Bool
    @Binding var hasExtracted: Bool
    
    // MARK: - Camera State
    
    @State private var session     = AVCaptureSession()
    @State private var photoOutput = AVCapturePhotoOutput()
    @State private var photoDel: PhotoDelegate?
    @State private var captureDevice: AVCaptureDevice?
    @State private var bufferDelegate = BufferDelegate()
    
    // MARK: - Scan State
    @State private var highResImage: UIImage? = nil
    @State private var showScanError = false
    @State private var showShareSheet = false
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Live camera preview
                if let dev = captureDevice {
                    CameraPreview(session: session, device: dev)
                        .ignoresSafeArea()
                }
                
                // FreezeOverlay: UI only
                if let img = frozenImage, showOverlay {
                    FreezeOverlay(
                        overlayImage: img,
                        isProcessing: $isProcessing
                    )
                    .transition(.identity)          // no transition
                    .animation(nil, value: showOverlay)
                }
                
                // Shutter button
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
            .navigationDestination(item: $scanResult) { result in
                ScanResultView(
                                   bottle:       result.bottle,  // passing it
                                   capturedImage: result.image,
                                   wineData: result.wineData,
                                   onDismiss: {
                                       // Reset state BEFORE dismissing
                                       frozenImage   = nil
                                       highResImage  = nil
                                       isProcessing  = false
                                       scanResult    = nil
                                       showOverlay   = false
                                       hasExtracted  = false
                                       
                                       // Defering the increments so that the view is fully out of the hierarchy first:
                                                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                      EngagementMilestones.increment("scanShareCount",  type: .share)
                                                      EngagementMilestones.increment("scanReviewCount", type: .review)
                                                      
                                                  }
                                              },
                                              selectedTab: $selectedTab,
                                              ctx: ctx,
                                              openAIManager: openAIManager
                                          )
                                      }
                       }
        .alert("Scan failed", isPresented: $showScanError) {
            Button("Try Again", role: .cancel) { }
        } message: {
            Text("Something went wrong analyzing the label. Please try again.")
        }
       
      
        .alert("Love SommLens?", isPresented: $engagementState.showSharePrompt) {
            Button("Not Now", role: .cancel) {}
            Button("Share") {
                // Defering toggling of the system share sheet so the alert has time to dismiss:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showShareSheet = true
                       }
                   }
               } message: {
                   Text("Tell your friends about SommLens!")
               }
               // System share sheet:
               .sheet(isPresented: $showShareSheet) {
                   ShareSheet(activityItems: ["I’m using SommLens to learn about wine — check it out!"])
               }
       
    }
    
// MARK: Configure the session
    
    private func configureSession() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add camera input
        if let cam = AVCaptureDevice.default(.builtInWideAngleCamera,
                                             for: .video,
                                             position: .back),
           let input = try? AVCaptureDeviceInput(device: cam),
           session.canAddInput(input) {
            session.addInput(input)
            captureDevice = cam
        }
        
        // Adds photo output (for high-res image)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024) // 12MP (4:3)
        }
        
        // Adds video buffer output (for instant overlay freeze)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(bufferDelegate, queue: DispatchQueue(label: "bufferQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        
        // 🔧 Force orientation to portrait (AFTER commitConfiguration)
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        
        // Start running
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
   
    
    // MARK: Take Photo - Overlay - AI Call
    
    
    private func takePhoto() {
     
        // Re-install the one-shot handler on each tap
        bufferDelegate.onFrame = { image in
            DispatchQueue.main.async {
                // only freeze once
                guard frozenImage == nil && !isProcessing else { return }
                
                // Freeze immediately
                frozenImage  = image
                showOverlay  = true
                hasExtracted = false // prevents further freezing until the next tap
                
                // Disable further freezes until the next tap
                bufferDelegate.onFrame = nil
            }
        }
        
        
        // Kick off the high-res capture immediately
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
        
        let del = PhotoDelegate { img in
            Task { @MainActor in
                guard let hiRes = img else {
                    frozenImage   = nil
                    highResImage  = nil
                    isProcessing  = false
                    showOverlay   = false
                    hasExtracted  = false
                    showScanError = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    return
                }
                
                // show the shimmer
                highResImage = hiRes
                isProcessing = true
                
                // Only _now_ call AI on the high-res image:
                openAIManager.extractWineInfo(from: hiRes) { result in
                    DispatchQueue.main.async {
                        isProcessing = false
                        switch result {
                        case .success(let wine):
                            // ─── SAVE YOUR SCAN HERE ───
                            let rawJSON = (try? JSONEncoder().encode(wine))
                                .flatMap { String(data: $0, encoding: .utf8) }
                            ?? "{}"
                            let bottle = saveScan(
                                in: ctx,
                                wineData: wine,
                                rawJSON: rawJSON,
                                screenshot: hiRes,
                                isPro: auth.hasActiveSubscription
                            )
                            
                           
                            
                            // Push navigation with that row
                            scanResult = ScanResult(
                                bottle:    bottle,
                                image:     hiRes,
                                wineData:  wine
                           
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
