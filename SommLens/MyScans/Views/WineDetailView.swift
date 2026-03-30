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
    @EnvironmentObject var auth: AuthViewModel
    
    
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
    }
    
    private var isPro: Bool { auth.hasActiveSubscription }
    
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
                        
                        // 👇 FREE ONLY vibeTag
                        if !isPro,
                           let vibe = wineData.vibeTag?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !vibe.isEmpty {
                            
                            Text(vibe)
                                .font(.body.italic())
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary.opacity(0.85))
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                        }
                        
                        if isPro {
                            
                            if let notes = wineData.tastingNotes?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                               !notes.isEmpty {
                                
                                Text(notes)
                                    .font(.body.italic())
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 4)
                                    .padding(.bottom, 4)
                            }
                            
                            viniTakeCard
                            
                            CardBlock(title: "Wine Info") {
                                
                                // ✅ Repeat header fields here (labeled)
                                InfoTile(label: "Producer", value: wineData.producer)
                                InfoTile(label: "Vintage", value: wineData.vintage)
                                InfoTile(label: "Region", value: wineData.region)
                                InfoTile(label: "Country", value: wineData.country)
                                InfoTile(label: "Category", value: wineData.category.displayName)
                                
                                InfoTile(label: "Subregion",   value: wineData.subregion)
                                InfoTile(label: "Appellation", value: wineData.appellation)
                                InfoTile(label: "Vineyard",    value: wineData.vineyard)
                                InfoTile(label: "Grapes", value: wineData.grapes?.joined(separator: ", "))
                            }
                            
                            CardBlock(title: "Food Pairings") {
                                let value = wineData.pairings?.joined(separator: ", ")
                                InfoTile(
                                    label: "Pair with",
                                    value: (value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                                    ? value
                                    : "Not available for this bottle yet."
                                )
                            }
                            
                            CardBlock(title: "Terroir") {
                                InfoTile(label: "Climate", value: wineData.climate)
                                InfoTile(label: "Soil", value: wineData.soilType)
                            }
                            
                            CardBlock(title: "Additional Info") {
                                InfoTile(label: "Classification", value: wineData.classification)
                                let abv = wineData.abv?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                InfoTile(label: "Alcohol", value: abv.isEmpty ? "Not found. Check back label." : abv)
                                InfoTile(label: "Drink", value: wineData.drinkingWindow)
                                InfoTile(label: "Style", value: wineData.winemakingStyle)
                            }
                            
                        } else {
                            
                            // ✅ FREE: Wine Info first
                            CardBlock(title: "Wine Info") {
                                
                                // ✅ Repeat header fields here (labeled)
                                InfoTile(label: "Producer", value: wineData.producer)
                                InfoTile(label: "Vintage", value: wineData.vintage)
                                InfoTile(label: "Region", value: wineData.region)
                                InfoTile(label: "Country", value: wineData.country)
                                InfoTile(label: "Category", value: wineData.category.displayName)
                                InfoTile(label: "Subregion",   value: wineData.subregion)
                                InfoTile(label: "Grapes", value: wineData.grapes?.joined(separator: ", "))
                            }
                            
                            // ✅ FREE: single upsell card
                            proUpsellCard
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
            "Impression unavailable",
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
        
        .sheet(isPresented: $vm.showRatingSheet) {
            if let r = vm.aiRating ?? bottle.toAIRating() {
                AIRatingSheet(
                    rating: r,
                    isUnlocked: auth.hasActiveSubscription,
                    unlockAction: { auth.isPaywallPresented = true }
                )
                .presentationDetents([.medium, .large])
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
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 24)
            }
        }
    }
    
    var titleSection: some View {
        VStack(spacing: 6) {
            
            Text(wineData.producer ?? "Unknown Producer")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            // Combined line
            if let vintage = wineData.vintage?.trimmingCharacters(in: .whitespacesAndNewlines),
               !vintage.isEmpty {
                
                Text("\(vintage) · \(wineData.region ?? "–"), \(wineData.country ?? "–")")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(wineData.region ?? "–"), \(wineData.country ?? "–")")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !wineData.category.displayName.isEmpty {
                Text(wineData.category.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    var viniTakeCard: some View {
        let rating = vm.aiRating ?? bottle.toAIRating()
        
        let state: AIRatingChipState = {
            if vm.isLoadingRating {
                return .loading
            } else if let r = rating {
                return .impression(r.overallImpression)
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
    
    
    
    var proUpsellCard: some View {
        CardBlock(title: "Want to learn more about this wine?") {
            VStack(alignment: .leading, spacing: 12) {
                
                HStack(spacing: 8) {
                    
                    Text("SommLens Pro includes:")
                        .font(.subheadline.bold())
                        .foregroundColor(.black.opacity(0.75))
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    proBullet("Full tasting notes")
                    proBullet("Food pairings")
                    proBullet("Terroir: climate + soil")
                    proBullet("Additional Info: ABV, classification, drinking window, style")
                    proBullet("Complete impression breakdown")
                    proBullet("Full scan history")
                }
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.75))
                
                Button {
                    auth.isPaywallPresented = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.circle.fill")
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundColor(.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.latte.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.burgundy.opacity(0.4), lineWidth: 1)
                )
            }
            .padding(.top, 5)
        }
    }
    
    private func proBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.burgundy.opacity(0.85))
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)
            
            Text(text)
        }
    }
}
