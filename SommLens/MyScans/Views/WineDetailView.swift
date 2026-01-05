//
//  WineDetailView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//
// IMPROVED: Modern card-style layout using Latte + Burgundy palette

import SwiftUI
import CoreData

struct WineDetailView: View {
    
    @StateObject private var vm: WineDetailViewModel
    
    @ObservedObject var bottle: BottleScan
    let wineData: WineData
    let snapshot: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest private var tastings: FetchedResults<TastingSessionEntity>
    
    @State private var showImageFullScreen = false
    
    init(
        bottle: BottleScan,
        wineData: WineData,
        snapshot: UIImage?,
        openAIManager: OpenAIManager,
        ctx: NSManagedObjectContext
    ) {
        self.bottle   = bottle
        self.wineData = wineData
        self.snapshot = snapshot
        
        self._vm = StateObject(
            wrappedValue: WineDetailViewModel(
                openAIManager: openAIManager,
                ctx: ctx,
                wineData: wineData,
                bottle: bottle
            )
        )
        
        _tastings = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TastingSessionEntity.date, ascending: false)],
            predicate: NSPredicate(format: "bottle == %@", bottle),
            animation: .default
        )
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    
                    // ── Full-width hero image + rating chip
                    headerSection
                    
                    // ── Main content
                    VStack(spacing: 28) {
                        
                        // Title block under the image (clean white background)
                        titleSection
                        
                        // Tasting notes
                        if let notes = wineData.tastingNotes?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !notes.isEmpty {
                            Text(notes)
                                .font(.body.italic())
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .padding(.top, 6)
                                .padding(.horizontal)
                        }
                        
                        // Tasting CTA / existing tasting
                        tastingSection
                        
                        // Cards
                        CardBlock(title: "Wine Info") {
                            InfoTile(label: "Subregion",   value: wineData.subregion)
                            InfoTile(label: "Appellation", value: wineData.appellation)
                            InfoTile(label: "Vineyard",    value: wineData.vineyard)
                            InfoTile(
                                label: "Grapes",
                                value: wineData.grapes?.joined(separator: ", ")
                            )
                            InfoTile(
                                label: "Food Pairings",
                                value: wineData.pairings?.joined(separator: ", ")
                            )
                        }
                        
                        CardBlock(title: "Terroir") {
                            InfoTile(label: "Climate", value: wineData.climate)
                            InfoTile(label: "Soil",    value: wineData.soilType)
                        }
                        
                        CardBlock(title: "Extras") {
                            InfoTile(label: "Classification", value: wineData.classification)
                            let abv = wineData.abv?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            InfoTile(
                                label: "Alcohol",
                                value: abv.isEmpty
                                    ? "Not found. Check back label."
                                    : abv
                            )
                            InfoTile(label: "Drink", value: wineData.drinkingWindow)
                            InfoTile(label: "Style", value: wineData.winemakingStyle)
                        }
                        
                        // Footer
                        VStack(spacing: 4) {
                            Text("SommLens")
                                .font(.caption2)
                                .foregroundColor(.black.opacity(0.6))
                            Image("OpenAIBadge")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 24)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                }
            }
            
            // Close button
            Button {
                dismiss()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.burgundy)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.burgundy.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 4)
            }
            .padding()
        }
        
        .alert(
            "Rating unavailable",
            isPresented: Binding(
                get: { vm.ratingError != nil },
                set: { newValue in
                    if !newValue {
                        vm.ratingError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                vm.ratingError = nil
            }
        } message: {
            Text(vm.ratingError ?? "")
        }
        
        // Rating breakdown sheet
        .sheet(isPresented: $vm.showRatingSheet) {
            if let r = vm.aiRating ?? bottle.toAIRating() {
                AIRatingSheet(rating: r)
                    .presentationDetents([.medium, .large])
            }
        }
        
        // Tasting summary sheet
        .sheet(item: $vm.selectedDTO) { dto in
            TastingSummaryView(
                input: .constant(dto.userInput),
                aiProfile: dto.aiProfile,
                wineName: dto.wineName
            )
            .padding(.horizontal, 16)
            .presentationDetents([.medium])
        }
        
        // Full tasting form
        .fullScreenCover(isPresented: $vm.showTasteSheet) {
            if let profile = vm.aiProfile {
                TastingFormView(
                    aiProfile: profile,
                    wineData:  wineData,
                    snapshot:  snapshot
                ) { dto in
                    vm.persistTasting(dto, for: bottle)
                    vm.showTasteSheet = false
                }
                .interactiveDismissDisabled()
            } else {
                ProgressView()
            }
        }
        
        // Full-screen zoomable image viewer (UIScrollView-backed)
        .fullScreenCover(isPresented: $showImageFullScreen) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                
                if let img = snapshot {
                    ZoomableScrollImage(image: img)
                        .ignoresSafeArea()
                }
                
                Button {
                    showImageFullScreen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding()
                }
            }
        }
        
        .onAppear {
            vm.animate = true
        }
        .task {
            // Preload rating but don't pop the sheet
            await vm.fetchAIRatingIfNeeded(openSheet: false)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Subsections

private extension WineDetailView {
    
    // Full-width hero image + rating chip only
    var headerSection: some View {
        Group {
            if let img = snapshot {
                Button {
                    showImageFullScreen = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()
                            .scaleEffect(vm.animate ? 1.0 : 0.97)
                            .opacity(vm.animate ? 1 : 0)
                            .animation(
                                .easeOut(duration: 0.3),
                                value: vm.animate
                            )
                        
                        ratingChip
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 24)
            }
        }
    }
    
    // Clean title block below the header
    var titleSection: some View {
        VStack(spacing: 4) {
            Text(wineData.producer ?? "Unknown Producer")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            if let vintage = wineData.vintage?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !vintage.isEmpty {
                Text(vintage)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            Text("\(wineData.region ?? "–") · \(wineData.country ?? "–")")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !wineData.category.displayName.isEmpty {
                Text(wineData.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    var ratingChip: some View {
        let rating = vm.aiRating ?? bottle.toAIRating()
        let scoreValue = rating?.viniScore
        
        let state: AIRatingChipState = {
            if vm.isLoadingRating {
                return .loading
            } else if let val = scoreValue {
                return .score(val)
            } else {
                return .empty
            }
        }()
        
        return AIRatingCornerChip(
            state: state,
            action: {
                if vm.isLoadingRating { return }
                
                if rating != nil {
                    vm.showRatingSheet = true
                } else {
                    Task {
                        await vm.fetchAIRatingIfNeeded(openSheet: true)
                    }
                }
            }
        )
    }
    
    var tastingSection: some View {
        Group {
            if let tasting = tastings.first {
                Button {
                    vm.selectedDTO = tasting.dto
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.burgundy)
                        Text("You tasted this wine!")
                            .foregroundColor(.burgundy)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.burgundy.opacity(0.9))
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.latte.opacity(0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.burgundy.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                Button {
                    Task { await vm.loadAIProfileAndShowTasting() }
                } label: {
                    Group {
                        if vm.isLoadingTaste {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: .burgundy)
                                    )
                                Text("Loading…")
                                    .foregroundColor(.burgundy)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("Taste with Vini AI")
                                    .foregroundColor(.burgundy)
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.burgundy.opacity(0.9))
                            }
                        }
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.latte.opacity(0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.burgundy.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(vm.isLoadingTaste)
            }
        }
    }
}

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
