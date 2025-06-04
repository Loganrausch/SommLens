//
//  ARScanResultView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/23/25.
//
//

import SwiftUI
import StoreKit

struct ScanResultView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Inject your managers
    @EnvironmentObject private var openAIManager: OpenAIManager
    @EnvironmentObject var engagementState: EngagementState
    
    @Environment(\.managedObjectContext) private var ctx   // add this
    
    // Inputs
    let bottle: BottleScan
    let capturedImage: UIImage
    let wineData:      WineData
    let onDismiss: () -> Void    // ← new callback
    
    // Existing wine‑detail sheet
    @State private var showDetailSheet = false
    
    // NEW – tasting flow sheet
    @State private var showTasteSheet  = false
    @State private var aiProfile: AITastingProfile?
    @State private var isLoadingTaste  = false
    
    
    @Binding var selectedTab: MainTab
    
    
    var body: some View {
        ZStack {
            
            
            /* ───── Bottle photo ───── */
            GeometryReader { geo in
                Image(uiImage: capturedImage)
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
                    
                    /* drag‑handle → open WineDetailView */
                    Button { showDetailSheet = true } label: {
                        Image(systemName: "chevron.up")
                            .font(.title2.weight(.medium))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    /* quick cards */
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let vintage = wineData.vintage?.trimmingCharacters(in: .whitespacesAndNewlines), !vintage.isEmpty {
                                QuickCard(title: "Vintage", text: vintage)
                            }
                            if let producer = wineData.producer?.trimmingCharacters(in: .whitespacesAndNewlines), !producer.isEmpty {
                                QuickCard(title: "Producer", text: producer)
                            }
                            if let appellation = wineData.appellation?.trimmingCharacters(in: .whitespacesAndNewlines), !appellation.isEmpty {
                                QuickCard(title: "Appellation", text: appellation)
                            }
                            if let region = wineData.region?.trimmingCharacters(in: .whitespacesAndNewlines), !region.isEmpty {
                                QuickCard(title: "Region", text: region)
                            }
                            if let grapes = wineData.grapes, !grapes.isEmpty {
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
                    
                    /* Taste‑this‑wine button */
                    Button {
                        Task { await loadAIProfileAndShowTasting() }
                    } label: {
                        if isLoadingTaste {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        } else {
                            Label("Taste with Vini AI", systemImage: "wineglass")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .background(.thinMaterial, in: Capsule())
                    .disabled(isLoadingTaste)
                    .padding(.horizontal, 32)
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
        
        .navigationBarBackButtonHidden(true)
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
            .padding(.top, 30)
            .padding(.trailing, 20)
        }
        
        /* ───── Sheets ───── */
        
        // Wine‑detail sheet
        .sheet(isPresented: $showDetailSheet) {
            WineDetailView(
                bottle:   bottle,           // 👈 NEW
                wineData: wineData,
                snapshot: capturedImage
            )
            .presentationDetents([.large])
        }
        
        // Tasting flow sheet
        .fullScreenCover(isPresented: $showTasteSheet) {
            if let profile = aiProfile {
                TastingFormView(
                    aiProfile: profile,
                    wineData:  wineData,
                    snapshot:  capturedImage
                ) { dto in
                    try? persist(dto, on: bottle)     // ✅ here
                    showTasteSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onDismiss()
                        dismiss()
                        selectedTab = .home
                    }
                }
                .interactiveDismissDisabled()
            } else {
                ProgressView()
            }
        }
        // ← add these two at the very end:
        .onChange(of: selectedTab) { _ in
            onDismiss()
            dismiss()
        }
        
    }
    
    // MARK: – AI fetch
    
    @MainActor
    private func loadAIProfileAndShowTasting() async {
        guard !isLoadingTaste else { return }
        isLoadingTaste = true
        defer { isLoadingTaste = false }
        
        do {
            let profile = try await openAIManager.tastingProfile(for: wineData)
            self.aiProfile     = profile
            self.showTasteSheet = true
        } catch {
            // TODO: replace with user‑visible alert / toast
            print("❌ AI fetch failed:", error.localizedDescription)
        }
    }
    
    // MARK: – Persist tasting DTO
    /// Adds one tasting to an *already-created* BottleScan row
    private func persist(
        _ dto: TastingSession,
        on bottle: BottleScan            // ← pass the parent row, not WineData
    ) throws {
        
        // 1️⃣ child tasting entity
        _ = try TastingSessionEntity(
            from:    dto,
            bottle:  bottle,
            context: ctx
        )
        
        // 2️⃣ optional meta update on the parent
        bottle.lastTasted = dto.date        // keeps “most-recent tasting” info
        
        // 3️⃣ commit
        if ctx.hasChanges { try ctx.save() }
    }
}

/* ---------- Quick info card ---------- */

private struct QuickCard: View {
    let title: String
    let text:  String?
    
    private let cardWidth:  CGFloat = 170
    private let cardHeight: CGFloat = 85
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption).foregroundColor(.burgundy).bold()
            Text(text ?? "-")
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
