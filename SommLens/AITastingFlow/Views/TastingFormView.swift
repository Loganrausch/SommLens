//
//  TastingFormView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI
import StoreKit

enum TastingStep: Int, CaseIterable {
    case acidity, alcohol, tannin, body, sweetness, aromas, flavors, summary
}

struct TastingFormView: View {
    @StateObject private var vm: TastingFormViewModel
    @EnvironmentObject var engagementState: EngagementState
    @Environment(\.dismiss) private var dismiss      // ← add
    
    private let onDismiss: () -> Void   // ✅ Now stored and used
    
    // ---------------- constructor ----------------
       init(aiProfile:  AITastingProfile,
            wineData:   WineData,
            snapshot:   UIImage? = nil,
            onSave:     @escaping (TastingSession) -> Void,
            onDismiss:  @escaping () -> Void = {}) {
       
           self.onDismiss = onDismiss
        
           _vm = StateObject(wrappedValue:
               TastingFormViewModel(aiProfile: aiProfile,
                                    wineData:  wineData,
                                    snapshot:  snapshot,
                                    onSave:    onSave))
       }
    
  
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // ── 1) Pinned Header ──
                HStack(alignment: .top, spacing: 12) {
                    if let img = vm.snapshot {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let vintage = vm.wineData.vintage {
                            Text(vintage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(vm.wineData.producer ?? "Unknown Producer")
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(vm.wineData.region ?? "-") · \(vm.wineData.country ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                // ── 2) Animated Content ──
                ZStack {
                    Group {
                        if vm.step == .summary {
                            TastingSummaryView(
                                input: $vm.input,
                                aiProfile: vm.aiProfile,
                                wineName: vm.wineData.displayName
                            )
                            .frame(maxWidth: .infinity)
                           
                            
                        } else if !vm.isSliderStep {
                            stepContent()
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            stepContent()
                                .padding()
                                .frame(minHeight: 300)
                        }
                    }
                    .id(vm.step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                }
                .animation(.easeInOut(duration: 0.6), value: vm.step)
                .padding(.horizontal, 16)   // ← add this line
                
                // ── 3) Footer ──
                VStack(spacing: 12) {
                    if vm.step != .summary {
                        ProgressView(value: Double(vm.step.rawValue), total: Double(vm.totalSteps))
                            .progressViewStyle(.linear)
                            .tint(Color("Burgundy"))
                    }
                    
                    Button(action: vm.advance) {
                        Text(vm.buttonLabel)
                            .font(.title2.bold())
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color("Latte"))
                            .foregroundColor(Color("Burgundy"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("Burgundy"), lineWidth: 2)
                            )
                    }
                    .disabled(vm.shouldDisableNext)
                }
                
                .padding(.horizontal, 16)   // ← add this line
                .padding(.vertical, 16)
            }
            
            
            // ── Vini Intro Overlay ──
            if vm.showViniIntro {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 24) {
                        Text("👋 Hi, I’m Vini — your personal AI sommelier.")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black.opacity(0.8))
                        
                        Text("Taste the wine and jot down your impressions first. Once you’re done, I’ll reveal my notes so we can compare — happy tasting!")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.horizontal, 24)
                        
                        Button("Got it!") {
                            withAnimation {
                                vm.showViniIntro = false
                            }
                        }
                        .font(.headline)
                        .foregroundColor(Color("Burgundy"))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 3)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                }
            }
               
            Button {
                vm.showCancelAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.burgundy)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(radius: 3)
                    }
                    .padding(.top, 30)
                    .padding(.trailing, 20)
                    .accessibilityLabel("Cancel tasting")
                }
        .alert("Cancel Tasting?",
               isPresented: $vm.showCancelAlert) {
              Button("Delete Tasting", role: .destructive) {
                  onDismiss()
                  dismiss()
              }
              Button("Keep Going", role: .cancel) { }
          } message: {
              Text("This will discard your current tasting notes and return to the previous screen.")
          }
    }

    @ViewBuilder
    private func stepContent() -> some View {
        switch vm.step {
        case .acidity:
            VerticalTubeStep(
                title: "Acidity",
                options: Intensity5.allCases,
                selection: $vm.input.acidity
            )
            
        case .alcohol:
            VerticalTubeStep(
                title: "Alcohol",
                options: Intensity5.allCases,
                selection: $vm.input.alcohol
            )
            
        case .tannin:
            if vm.showsTannin {
                VerticalTubeStep(
                    title: "Tannin",
                    options: Intensity5.allCases,
                    selection: $vm.input.tannin
                )
            } else {
                Text("No tannins to assess for this wine!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
            
        case .body:
            VerticalTubeStep(
                title: "Body",
                options: BodyLevel.allCases,
                selection: $vm.input.body
            )
            
        case .sweetness:
            VerticalTubeStep(
                title: "Sweetness",
                options: SweetnessLevel.allCases,
                selection: $vm.input.sweetness
            )
            
        case .aromas:
            SelectionGrid(
                title: "Which aromas do you notice?",
                options: vm.aromaOptions,
                selection: $vm.input.aromas
            )
            
        case .flavors:
            SelectionGrid(
                title: "Which flavors do you notice?",
                options: vm.flavorOptions,
                selection: $vm.input.flavors
            )
            
        default:
            EmptyView()  // summary is handled outside of this function
        }
    }
}


