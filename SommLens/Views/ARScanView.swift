//
//  ARScanView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

// ARScanView.swift

import SwiftUI
import RealityKit
import ARKit
import Vision
import CoreData
import UIKit

// ——————————————
// 1) ScanResult drives navigation
// ——————————————
struct ScanResult: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage
    let wineData: WineData

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ScanResult, rhs: ScanResult) -> Bool { lhs.id == rhs.id }
}

struct ARScanView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var openAI = OpenAIManager()

    @State private var arView: ARView?
    @State private var viewSize: CGSize = .zero

    // ——————————————
    // 2) Capture & processing state
    // ——————————————
    @State private var capturedImage: UIImage? = nil
    @State private var isProcessing    = false

    @State private var scanResult: ScanResult? = nil


    var body: some View {
        NavigationStack {
            ZStack {
                // Live AR feed
                ARViewContainer(arView: $arView, viewSize: $viewSize)
                    .ignoresSafeArea(.container, edges: .horizontal)

                // 1️⃣ In your body, add a transition to the frozen snapshot:
                if let img = capturedImage {
                    Image(uiImage: img)
                      .resizable()
                      .scaledToFill()
                      .ignoresSafeArea(.container, edges: .horizontal)
                      .transition(.opacity)                                    // ← add this
                      .animation(.easeInOut(duration: 0.2), value: capturedImage)

                        }
                
                // 2) The shimmer beam
                             if isProcessing {
                                 HorizontalShimmer(speed: 0.8, beamWidthFraction: 0.2)
                             }
                
                // 3) Camera button (only before snapshot)
                if capturedImage == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                takeSnapshot()
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.largeTitle)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding(25)
                        }
                    }
                }
            }
            // Navigate when we have a result
            .navigationDestination(item: $scanResult) { result in
                ARScanResultView(
                    capturedImage: result.image,
                    wineData:      result.wineData
                )
                .onDisappear {
                    capturedImage = nil
                    scanResult    = nil
                }
            }
        }
    }

    private func takeSnapshot() {
        // 1️⃣ Turn on the spinner immediately
        isProcessing = true

        guard let arView = arView else { return }
        arView.snapshot(saveToHDR: false) { image in
            DispatchQueue.main.async {
                guard let uiImage = image else {
                    // if snapshot somehow fails, hide the spinner
                    isProcessing = false
                    return
                }

                // 2️⃣ Freeze the frame
                capturedImage = uiImage

                // 3️⃣ Do your OCR/OpenAI/CoreData work
                Task {
                    do {
                        let text = try await recognizeText(from: uiImage)
                        let wine = try await openAIExtract(from: text)
                        let rawJSON = (try? JSONEncoder().encode(wine))
                                      .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

                        await MainActor.run {
                            saveScan(wineData: wine,
                                     rawJSON: rawJSON,
                                     screenshot: uiImage)
                            scanResult = ScanResult(image: uiImage,
                                                    wineData: wine)
                        }
                    } catch {
                        print("Scan error:", error)
                    }

                    // 4️⃣ Always hide the spinner at the end
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            }
        }
    }

    private func recognizeText(from image: UIImage) async throws -> String {
        let ci      = CIImage(image: image)!
        let handler = VNImageRequestHandler(ciImage: ci, options: [:])
        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let e = err { return cont.resume(throwing: e) }
                let joined = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ") ?? ""
                cont.resume(returning: joined)
            }
            req.recognitionLevel = .accurate
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([req])
            }
        }
    }

    private func openAIExtract(from text: String) async throws -> WineData {
        try await withCheckedThrowingContinuation { cont in
            openAI.extractWineInfo(from: text) { res in
                switch res {
                case .success(let d): cont.resume(returning: d)
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
    }

    private func saveScan(wineData: WineData,
                          rawJSON: String,
                          screenshot: UIImage) {
        let scan = BottleScan(context: viewContext)
        scan.id               = UUID()
        scan.timestamp        = Date()
        scan.producer         = wineData.producer
        scan.region           = wineData.region
        scan.country          = wineData.country
        scan.grapes           = wineData.grapes?.joined(separator: ", ")
        scan.vintage          = wineData.vintage
        scan.classification   = wineData.classification
        scan.tastingNotes     = wineData.tastingNotes
        scan.pairings         = wineData.pairings?.joined(separator: ", ")
        scan.vibeTag          = wineData.vibeTag
        scan.vineyard         = wineData.vineyard
        scan.soilType         = wineData.soilType
        scan.climate          = wineData.climate
        scan.drinkingWindow   = wineData.drinkingWindow
        scan.abv              = wineData.abv
        scan.winemakingStyle  = wineData.winemakingStyle

        scan.rawJSON          = rawJSON
        if let data = screenshot.jpegData(compressionQuality: 0.8) {
            scan.screenshot   = data
        }

        do {
            try viewContext.save()
        } catch {
            print("Core Data save error:", error)
        }
    }
}

// ——————————————
// ARViewContainer (unchanged)
// ——————————————
struct ARViewContainer: UIViewRepresentable {
    @Binding var arView: ARView?
    @Binding var viewSize: CGSize

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let cfg  = ARWorldTrackingConfiguration()
        view.session.run(cfg)
        DispatchQueue.main.async {
            arView   = view
            viewSize = view.bounds.size
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        DispatchQueue.main.async { viewSize = uiView.bounds.size }
    }
}
