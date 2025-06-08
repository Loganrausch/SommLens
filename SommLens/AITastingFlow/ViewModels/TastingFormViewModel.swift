//
//  TastingFormViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 6/7/25.
//

import SwiftUI

@MainActor
final class TastingFormViewModel: ObservableObject {
    
    let aiProfile: AITastingProfile
    let wineData:   WineData            // ← add your WineData here
    let onSave: (TastingSession) -> Void
    let snapshot:   UIImage?            // ← and the optional image
    
    @Published var step: TastingStep = .acidity
    @Published var previousStep: TastingStep = .acidity
    @Published var input = TastingInput()
    @Published var showViniIntro = false
    @Published var showCancelAlert = false
    
    init(aiProfile:  AITastingProfile,
         wineData:   WineData,
         snapshot:   UIImage?           = nil,
         onSave:     @escaping (TastingSession) -> Void)
    {
        self.aiProfile = aiProfile
        self.wineData  = wineData
        self.snapshot  = snapshot
        self.onSave    = onSave
        
        // first-launch overlay
        if !UserDefaults.standard.bool(forKey: "hasSeenViniIntro") {
            showViniIntro = true
            UserDefaults.standard.set(true, forKey: "hasSeenViniIntro")
        }
    }
    var showsTannin: Bool {
            aiProfile.hasTannin || wineData.category.tanninExists
        }
    
    var totalSteps: Int {
        showsTannin ? TastingStep.allCases.count - 1
                    : TastingStep.allCases.count - 2   // minus summary & tannin
    }
    
    var isSliderStep: Bool {
        switch step {
        case .acidity, .alcohol, .body, .sweetness:
            return true                    // always show these sliders
        case .tannin:
            return showsTannin             // slider only when the AI expects tannin
        default:
            return false
        }
    }
    
    var shouldDisableNext: Bool {
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
    
    var buttonLabel: String {
        if shouldDisableNext {                 // user hasn’t answered the current step
            return "Make a Selection"
        } else {
            return step == .summary ? "Save Tasting" : "Next"
        }
    }
    
    var aromaOptions:  [String] { wineData.category.aromaPool }
    var flavorOptions: [String] { wineData.category.flavourPool }
    
    // 3️⃣ advance() logic stays the same, skipping `.tannin` when `!showsTannin`
    func advance() {
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
    
    func saveSession() {
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
    
    
}

