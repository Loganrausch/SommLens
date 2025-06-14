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
    
    init(bottle: BottleScan, wineData: WineData, snapshot: UIImage?, openAIManager: OpenAIManager, ctx: NSManagedObjectContext) {
        self.bottle   = bottle
        self.wineData = wineData
        self.snapshot = snapshot
        self._vm = StateObject(wrappedValue: WineDetailViewModel(
                  openAIManager: openAIManager,
                  ctx: ctx,
                  wineData: wineData
              ))
        
        _tastings = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TastingSessionEntity.date, ascending: false)],
            predicate: NSPredicate(format: "bottle == %@", bottle),
            animation: .default
        )
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 28) {
                    if let img = snapshot {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(20)
                            .shadow(color: .primary.opacity(0.2), radius: 20, x: 0, y: 10)
                            .padding(.horizontal, 24)
                            .scaleEffect(vm.animate ? 1.0 : 0.95)
                            .opacity(vm.animate ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: vm.animate)
                    }
                    
                    
                    VStack(spacing: 6) {
                        if let vintage = wineData.vintage?.trimmingCharacters(in: .whitespaces), !vintage.isEmpty {
                            Text(vintage)
                                .font(.title3.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(wineData.producer ?? "Unknown Producer")
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        
                        Text("\(wineData.region ?? "–") · \(wineData.country ?? "–")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(wineData.category.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    if let vibe = wineData.vibeTag?.trimmingCharacters(in: .whitespacesAndNewlines), !vibe.isEmpty {
                        Text("“\(vibe)”")
                            .font(.body.italic())
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.top, 6)
                            .padding(.horizontal)
                    }
                    
                    if let tasting = tastings.first {
                        Button {
                            vm.selectedDTO = tasting.dto
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.burgundy) // ← make the checkmark burgundy
                                Text("You tasted this wine!")
                                    .foregroundColor(.primary)
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.burgundy.opacity(0.8))
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.burgundy.opacity(0.1), in: Capsule())
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
                                            .progressViewStyle(CircularProgressViewStyle(tint: .burgundy))
                                        Text("Loading…")
                                            .foregroundColor(.primary)
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wineglass")
                                            .foregroundColor(.burgundy)
                                        Text("Taste with Vini AI")
                                            .foregroundColor(.primary)
                                        Image(systemName: "chevron.right")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.burgundy.opacity(0.8))
                                    }
                                }
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.burgundy.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isLoadingTaste)
                        .animation(.easeInOut, value: tastings.count)
                    }
                    
                    CardBlock(title: "Wine Info") {
                        InfoTile(label: "Subregion",   value: wineData.subregion)
                        InfoTile(label: "Appellation", value: wineData.appellation)
                        InfoTile(label: "Vineyard", value: wineData.vineyard)
                        InfoTile(label: "Grapes", value: wineData.grapes?.joined(separator: ", "))
                        InfoTile(label: "Food Pairings", value: wineData.pairings?.joined(separator: ", "))
                    }
                    
                    CardBlock(title: "Tasting Notes") {
                        if let notes = wineData.tastingNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    CardBlock(title: "Terroir") {
                        InfoTile(label: "Climate", value: wineData.climate)
                        InfoTile(label: "Soil", value: wineData.soilType)
                    }
                    
                    CardBlock(title: "Extras") {
                        InfoTile(label: "Classification", value: wineData.classification)
                        let abv = wineData.abv?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        InfoTile(label: "Alcohol", value: abv.isEmpty ? "Not found. Check back label." : abv)
                        InfoTile(label: "Drink", value: wineData.drinkingWindow)
                        InfoTile(label: "Style", value: wineData.winemakingStyle)
                    }
                    
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
                .padding(.top, 36)
            }
            
            Button {
                dismiss()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.burgundy)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.burgundy.opacity(0.2), lineWidth: 1))
                    .shadow(radius: 4)
            }
            .padding()
        }
        .sheet(item: $vm.selectedDTO) { dto in
            TastingSummaryView(
                input: .constant(dto.userInput),
                aiProfile: dto.aiProfile,
                wineName: dto.wineName
            )
            .padding(.horizontal, 16) // ✅ Apply here for the sheet only
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $vm.showTasteSheet) {
            if let profile = vm.aiProfile {
                TastingFormView(
                    aiProfile: profile,
                    wineData:  wineData,
                    snapshot:  snapshot          // same image already in view
                ) { dto in
                    vm.persistTasting(dto, for: bottle)
                    vm.showTasteSheet = false
                }
                .interactiveDismissDisabled()
            } else {
                ProgressView()
            }
        }
        .onAppear { vm.animate = true }
        .navigationBarHidden(true)
    }
}



