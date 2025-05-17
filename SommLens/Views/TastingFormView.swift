//
//  TastingFormView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

enum TastingStep: Int, CaseIterable {
    case acidity, alcohol, tannin, body, sweetness, aromas, flavors, summary
}

struct TastingFormView: View {
    // Inject these when presenting the sheet
    let aiProfile: AITastingProfile
    let wineData:   WineData            // ← add your WineData here
    let snapshot:   UIImage?            // ← and the optional image
    let onSave: (TastingSession) -> Void
    
    @State private var step: TastingStep = .acidity
    @State private var previousStep: TastingStep = .acidity
    @State private var input = TastingInput()
    
    private var aromaOptions:  [String] { wineData.category.aromaPool }
    private var flavorOptions: [String] { wineData.category.flavourPool }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── 1) Pinned Header ─────────────────────────
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
                    if wineData.category != .unknown {
                        Text(wineData.category.displayName)
                          .font(.caption2)
                          .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            
            // ── 2) Animated Content Area ─────────────────────────────────────────
            ZStack {
                Group {
                    // Summary page — its own scrollable view
                    if step == .summary {
                        TastingSummaryView(
                            input:     $input,
                            aiProfile: aiProfile,
                            wineName:  wineData.displayName
                        )
                        .padding()
                    
                    // Non-slider pages (aromas & flavours) —— centred vertically
                    } else if !isSliderStep {
                        stepContent()
                            .padding()
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .center)      // ⬅️ keeps grid + title centred
                           
                    // Slider pages —— keep original padding and minHeight
                    } else {
                        stepContent()
                            .padding()
                            .frame(minHeight: 300)
                    }
                }
                .id(step)   // force fresh view on step change
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .move(edge: .leading)
                ))
            }
            .animation(.easeInOut(duration: 0.6), value: step)
            
            // ── 3) Fixed Footer ───────────────────────────
            VStack(spacing: 12) {
                if step != .summary {
                    ProgressView(value: Double(step.rawValue),
                                 total: Double(totalSteps))
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
            .background(.ultraThinMaterial)
            
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
    
    // 2️⃣ New helper reads from the AI
    private var showsTannin: Bool {
      aiProfile.hasTannin
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
    
    private func saveSession() {
        let session = TastingSession(
            wineID: UUID().uuidString,
            wineName: wineData.displayName,
            grape: aiProfile.aromas.first ?? "",
            region: wineData.region ?? "",
            vintage: wineData.vintage,
            userInput: input,        //  ← put the whole input here
            aiProfile: aiProfile,
            date: Date()
        )
        onSave(session)
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
                title: "Which flavours do you notice?",
                options: flavorOptions,
                selection: $input.flavors
            )
            
        default:
            EmptyView()  // summary is handled outside of this function
        }
    }
}


