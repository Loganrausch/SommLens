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
    @EnvironmentObject var engagementState: EngagementState
    @Environment(\.dismiss) private var dismiss      // ← add

    // Inject these when presenting the sheet
    let aiProfile: AITastingProfile
    let wineData:   WineData            // ← add your WineData here
    let snapshot:   UIImage?            // ← and the optional image
    let onSave: (TastingSession) -> Void
    let onDismiss: () -> Void = {}   // 🔁 cleans up Core Data / scan state, passed from parent
    
    @State private var step: TastingStep = .acidity
    @State private var previousStep: TastingStep = .acidity
    @State private var input = TastingInput()
    @State private var showViniIntro = false
    @State private var showCancelAlert = false
    
    private var aromaOptions:  [String] { wineData.category.aromaPool }
    private var flavorOptions: [String] { wineData.category.flavourPool }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // ── 1) Pinned Header ──
                HStack(alignment: .top, spacing: 12) {
                    if let img = snapshot {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let vintage = wineData.vintage {
                            Text(vintage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(wineData.producer ?? "Unknown Producer")
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(wineData.region ?? "-") · \(wineData.country ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // ── 2) Animated Content ──
                ZStack {
                    Group {
                        if step == .summary {
                            TastingSummaryView(
                                input: $input,
                                aiProfile: aiProfile,
                                wineName: wineData.displayName
                            )
                            .padding()
                        } else if !isSliderStep {
                            stepContent()
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            stepContent()
                                .padding()
                                .frame(minHeight: 300)
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                }
                .animation(.easeInOut(duration: 0.6), value: step)
                
                // ── 3) Footer ──
                VStack(spacing: 12) {
                    if step != .summary {
                        ProgressView(value: Double(step.rawValue), total: Double(totalSteps))
                            .progressViewStyle(.linear)
                            .tint(Color("Burgundy"))
                    }
                    
                    Button(action: advance) {
                        Text(buttonLabel)
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
                    .disabled(shouldDisableNext)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                
            }
            
            // ── Vini Intro Overlay ──
            if showViniIntro {
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
                                showViniIntro = false
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
                        showCancelAlert = true
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
                 isPresented: $showCancelAlert) {
              Button("Delete Tasting", role: .destructive) {
                  dismiss()          // (or onDismiss(); dismiss() if you added it)
              }
              Button("Keep Going", role: .cancel) { }
          } message: {
              Text("This will discard your current tasting notes and return to the previous screen.")
          }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasSeenViniIntro") {
                showViniIntro = true
                UserDefaults.standard.set(true, forKey: "hasSeenViniIntro")
            }
        }
    }
    
    // MARK: – Helpers
    
    
    private var totalSteps: Int {
        showsTannin ? TastingStep.allCases.count - 1
                    : TastingStep.allCases.count - 2   // minus summary & tannin
    }
    
    private var isSliderStep: Bool {
        switch step {
        case .acidity, .alcohol, .body, .sweetness:
            return true                    // always show these sliders
        case .tannin:
            return showsTannin             // slider only when the AI expects tannin
        default:
            return false
        }
    }
    
    private var showsTannin: Bool {
        aiProfile.hasTannin || wineData.category.tanninExists
    }

    
    private var buttonLabel: String {
        if shouldDisableNext {                 // user hasn’t answered the current step
            return "Make a Selection"
        } else {
            return step == .summary ? "Save Tasting" : "Next"
        }
    }
    
    private var shouldDisableNext: Bool {
        switch step {
        case .acidity:   return input.acidity   == .unknown
        case .alcohol:   return input.alcohol   == .unknown
        case .tannin:
            return showsTannin ? input.tannin == .unknown : false
        case .body:      return input.body      == .unknown
        case .sweetness: return input.sweetness == .unknown
        default:         return false
        }
    }
    
    // 3️⃣ advance() logic stays the same, skipping `.tannin` when `!showsTannin`
    private func advance() {
      withAnimation {
        if step == .summary {
          saveSession()
          return
        }
        previousStep = step
        var nextRaw = step.rawValue + 1

        if nextRaw == TastingStep.tannin.rawValue && !showsTannin {
          nextRaw += 1
        }

        step = TastingStep(rawValue: nextRaw) ?? .summary
      }
    }
    
    // ▼ paste over your existing saveSession()
    private func saveSession() {
        // Build the lightweight DTO the UI works with
        let dto = TastingSession(
            id: UUID(),                               // auto-id for this tasting
            wineID:   wineData.id,                    // <<< NOT random any more
            wineName: wineData.displayName,
            grape:    aiProfile.aromas.first ?? "",
            region:   wineData.region ?? "",
            vintage:  wineData.vintage,
            userInput: input,
            aiProfile: aiProfile,
            date: Date()
        )

        onSave(dto)           // fires the closure supplied by ARScanResultView
        
    }
    
    
    @ViewBuilder
    private func stepContent() -> some View {
        switch step {
        case .acidity:
            VerticalTubeStep(
                title: "Acidity",
                options: Intensity5.allCases,
                selection: $input.acidity
            )
            
        case .alcohol:
            VerticalTubeStep(
                title: "Alcohol",
                options: Intensity5.allCases,
                selection: $input.alcohol
            )
            
        case .tannin:
            if showsTannin {
                VerticalTubeStep(
                    title: "Tannin",
                    options: Intensity5.allCases,
                    selection: $input.tannin
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
                selection: $input.body
            )
            
        case .sweetness:
            VerticalTubeStep(
                title: "Sweetness",
                options: SweetnessLevel.allCases,
                selection: $input.sweetness
            )
            
        case .aromas:
            SelectionGrid(
                title: "Which aromas do you notice?",
                options: aromaOptions,
                selection: $input.aromas
            )
            
        case .flavors:
            SelectionGrid(
                title: "Which flavors do you notice?",
                options: flavorOptions,
                selection: $input.flavors
            )
            
        default:
            EmptyView()  // summary is handled outside of this function
        }
    }
}


