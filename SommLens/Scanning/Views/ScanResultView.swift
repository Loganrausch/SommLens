//
//  ARScanResultView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/23/25.
//
//

import SwiftUI
import CoreData

struct ScanResultView: View {
    
    @StateObject private var vm: ScanResultViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var engagementState: EngagementState
    @EnvironmentObject var auth: AuthViewModel
    
    @Binding var selectedTab: MainTab
    
    let onDismiss: () -> Void    // ← new callback
    
    init(
           bottle: BottleScan,
           capturedImage: UIImage,
           wineData: WineData,
           onDismiss: @escaping () -> Void,
           selectedTab: Binding<MainTab>,
           ctx: NSManagedObjectContext,
           openAIManager: OpenAIManager
    ) {
        _vm = StateObject(wrappedValue: ScanResultViewModel(
            ctx: ctx,
            openAIManager: openAIManager,
            wineData: wineData,
            bottle: bottle,
            capturedImage: capturedImage
        ))
        self.onDismiss = onDismiss
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        ZStack {
            
            
            /* ───── Bottle photo ───── */
            GeometryReader { geo in
                Image(uiImage: vm.capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                
            }
            .ignoresSafeArea()           // ← ADD THIS
            
            /* ───── Gradient for legibility ───── */
            LinearGradient(colors: [.clear, .black.opacity(0.45)],
                           startPoint: .center, endPoint: .bottom)
            .allowsHitTesting(false)
            .ignoresSafeArea()    // ← also stretch into the inset
            
            /* ───── Bottom info tray ───── */
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 14) {
                    
                    Button {
                        vm.showDetailSheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "chevron.up")
                                .font(.title2.weight(.medium))
                                .foregroundColor(Color.burgundy)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                    
                    /* quick cards */
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let vintage = vm.wineData.vintage?.trimmingCharacters(in: .whitespacesAndNewlines), !vintage.isEmpty {
                                QuickCard(title: "Vintage", text: vintage)
                            }
                            if let producer = vm.wineData.producer?.trimmingCharacters(in: .whitespacesAndNewlines), !producer.isEmpty {
                                QuickCard(title: "Producer", text: producer)
                            }
                            if let appellation = vm.wineData.appellation?.trimmingCharacters(in: .whitespacesAndNewlines), !appellation.isEmpty {
                                QuickCard(title: "Appellation", text: appellation)
                            }
                            if let region = vm.wineData.region?.trimmingCharacters(in: .whitespacesAndNewlines), !region.isEmpty {
                                QuickCard(title: "Region", text: region)
                            }
                            if let grapes = vm.wineData.grapes, !grapes.isEmpty {
                                let joined = grapes
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: ", ")
                                if !joined.isEmpty {
                                    QuickCard(title: "Grapes", text: joined)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 90)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        
        .tint(.burgundy)
        
        .navigationBarBackButtonHidden(true)
        
        .task {
            await vm.fetchAIRatingIfNeeded()
        }
        
        .overlay(alignment: .topLeading) {
            let state: AIRatingChipState = {
                if vm.isLoadingRating { return .loading }
                if let r = vm.aiRating { return .impression(r.overallImpression) }
                return .empty
            }()

            AIRatingCornerChip(state: state) {
                if vm.aiRating != nil {
                    vm.showRatingSheet = true
                } else {
                    Task { await vm.fetchAIRatingIfNeeded() }
                }
            }
            .padding(.top, 30)
            .padding(.leading, 20)
            .disabled(vm.isLoadingRating)
        }
        
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()     // ← clean state first
                dismiss()       // ← then dismiss
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(radius: 3)
            }
            .tint(.burgundy)
            .padding(.top, 30)
            .padding(.trailing, 20)
        }
        
        /* ───── Sheets ───── */
        
        .sheet(isPresented: $vm.showRatingSheet) {
            if let r = vm.aiRating {
                AIRatingSheet(
                    rating: r,
                    isUnlocked: auth.hasActiveSubscription,
                )
                .presentationDetents([.medium, .large])
            }
        }
        
        // Wine‑detail sheet
        .fullScreenCover(isPresented: $vm.showDetailSheet) {
            WineDetailView(
                bottle:   vm.bottle,           // 👈 NEW
                wineData: vm.wineData,
                snapshot: vm.capturedImage,
                openAIManager: vm.openAIManager,
                ctx: vm.ctx
            )
            .presentationDetents([.large])
        }
    
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .scan {
                print("🔁 Tab re-tap detected in ScanResultView")
                onDismiss()  // <- clears vm.scanResult
                dismiss()    // <- exits the screen
            }
        }
        
    }
}
