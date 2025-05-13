//
//  ARScanResultView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/23/25.
//
//

import SwiftUI

struct ARScanResultView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Inject your managers
    @EnvironmentObject private var openAIManager: OpenAIManager
    @EnvironmentObject private var tastingStore:  TastingStore      // simple CoreData/SwiftData wrapper
    
    // Inputs
    let capturedImage: UIImage
    let wineData:      WineData
    
    // Existing wine‑detail sheet
    @State private var showDetailSheet = false
    
    // NEW – tasting flow sheet
    @State private var showTasteSheet  = false
    @State private var aiProfile: AITastingProfile?
    @State private var isLoadingTaste  = false                      // simple loading flag
    
    var body: some View {
        ZStack {
            /* ───── Bottle photo ───── */
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea(.container, edges: .horizontal)
            
            /* ───── Gradient for legibility ───── */
            LinearGradient(colors: [.clear, .black.opacity(0.45)],
                           startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            
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
                            QuickCard(title: "Producer", text: wineData.producer)
                            QuickCard(title: "Vintage",  text: wineData.vintage)
                            QuickCard(title: "Region",   text: wineData.region)
                            QuickCard(title: "Grapes",   text: wineData.grapes?.joined(separator: ", "))
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
                            Label("Taste This Wine", systemImage: "wineglass")
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
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
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
            WineDetailView(wineData: wineData, snapshot: capturedImage)
                .presentationDetents([.large])
        }
        
        // Tasting flow sheet
        .sheet(isPresented: $showTasteSheet) {
            if let profile = aiProfile {
                TastingFormView(
                    aiProfile: profile,
                    wineDisplayName: wineData.displayName,      // computed property extension
                    onSave: { session in tastingStore.add(session) }
                )
                .presentationDetents([.large])
            } else {
                ProgressView()
                    .presentationDetents([.medium])
            }
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
}

/* ---------- Quick info card ---------- */

private struct QuickCard: View {
    let title: String
    let text:  String?
    
    private let cardWidth:  CGFloat = 170
    private let cardHeight: CGFloat = 95
    
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
