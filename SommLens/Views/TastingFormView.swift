//
//  TastingFormView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

enum TastingStep: Int, CaseIterable {
    case acidity, alcohol, tannin, body, sweetness, flavors, notes, summary
}

struct TastingFormView: View {
    // Inject these when presenting the sheet
    let aiProfile: AITastingProfile
    let wineDisplayName: String
    let onSave: (TastingSession) -> Void       // Return the completed session

    @State private var step: TastingStep = .acidity
    @State private var input = TastingInput()  // Collects user answers

    private let flavorOptions = [
        "Blackberry","Cherry","Vanilla","Earth",
        "Leather","Floral","Citrus","Spice"
    ]

    var body: some View {
        VStack {
            // Progress indicator
            Text("Step \(step.rawValue + 1) of \(TastingStep.allCases.count)")
                .font(.caption)
                .padding(.top, 4)

            // Main step content
            // Main step content
            Group {
                switch step {
                case .acidity:
                    PickerStep(title: "Acidity",
                               options: Intensity5.allCases,
                               selection: $input.acidity)

                case .alcohol:
                    PickerStep(title: "Alcohol",
                               options: Intensity5.allCases,
                               selection: $input.alcohol)

                case .tannin:
                    PickerStep(title: "Tannin",
                               options: Intensity5.allCases,
                               selection: $input.tannin)

                case .body:
                    PickerStep(title: "Body",
                               options: BodyLevel.allCases,
                               selection: $input.body)

                case .sweetness:
                    PickerStep(title: "Sweetness",
                               options: SweetnessLevel.allCases,
                               selection: $input.sweetness)

                case .flavors:
                    FlavorSelectionStep(
                        selectedFlavors: $input.flavors,
                        options: flavorOptions
                    )

                case .notes:
                    NotesStep(notes: $input.notes)

                case .summary:
                    TastingSummaryView(
                        input: input,
                        aiProfile: aiProfile,
                        wineName: wineDisplayName
                    )
                }
            }
            .animation(.easeInOut, value: step)
            .transition(.slide)
            .padding()

            Spacer()

            // Next / Save button
            Button(step == .summary ? "Save Tasting" : "Next") {
                advance()
            }
            .disabled(shouldDisableNext)
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
        .padding(.horizontal)
    }

    // MARK: – Helpers

    private var shouldDisableNext: Bool {
        switch step {
        case .acidity: return input.acidity == .unknown
        case .tannin:  return input.tannin  == .unknown
        case .body:    return input.body    == .unknown
        default:       return false
        }
    }

    private func advance() {
        if step == .summary {
            saveSession()
        } else {
            step = TastingStep(rawValue: step.rawValue + 1) ?? .summary
        }
    }

    private func saveSession() {
        let session = TastingSession(
            wineID: UUID().uuidString,      // Replace with real barcode/hash when you have it
            wineName: wineDisplayName,
            grape: aiProfile.aromas.first ?? "",
            region: "",                     // Fill with scan metadata
            vintage: nil,
            userInput: input,
            aiProfile: aiProfile,
            date: Date()
        )
        onSave(session)
    }
}
