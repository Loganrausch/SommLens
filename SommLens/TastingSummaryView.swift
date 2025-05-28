//
//  TastingSummaryView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

// MARK: - Shared helpers (file‑private, visible only inside this file)

fileprivate let pillWidth: CGFloat = {
    let w = UIScreen.main.bounds.width * 0.28
    return min(max(w, 96), 150)
}()

fileprivate let pillBG     = Color("Latte")        // pill background
fileprivate let classicFG  = Color("Burgundy")     // burgundy “Somm” text

/// Normalises raw enum strings so the pills look nice
fileprivate func pretty(_ raw: String) -> String {
    raw.replacingOccurrences(of: "medium-", with: "Med‑")
        .replacingOccurrences(of: "medium+", with: "Med+")
        .replacingOccurrences(of: "-",       with: "‑")
        .capitalized
}

// MARK: – Pill helper that can draw an optional border
fileprivate func pill(_ text: String,
                      matched: Bool = false,
                      fg: Color = .primary) -> some View {
    Text(text)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)          // allow flexible columns
        .background(pillBG)
        .foregroundColor(fg)
        .clipShape(Capsule())
        .overlay(                           // highlight if both detected
            Capsule()
                .stroke(matched ? .green.opacity(0.7) : .clear, lineWidth: 1.5)
        )
}


// MARK: - Main view
struct TastingSummaryView: View {
    @Binding var input: TastingInput
    let aiProfile:  AITastingProfile
    let wineName:   String
    
    @FocusState private var notesFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                
                
                Text("Tasting Review")
                    .font(.title2.bold())
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Structure").font(.headline)
                    card { comparisonRows }
                }
                
                Rectangle()
                    .fill(Color.burgundy)       // Use .fill instead of .foregroundStyle for reliability
                    .frame(height: 0.5)            // This sets the thickness
                
                // Aromas
                if !input.aromas.isEmpty || !aiProfile.aromas.isEmpty {
                    card {
                        pillColumnsSection(title: "Aromas",
                                           you:   input.aromas,
                                           somm:  aiProfile.aromas)
                    }
                }
                
                Rectangle()
                    .fill(Color.burgundy)       // Use .fill instead of .foregroundStyle for reliability
                    .frame(height: 0.5)             // This sets the thickness
                
                // Flavors
                if !input.flavors.isEmpty || !aiProfile.flavors.isEmpty {
                    card {
                        pillColumnsSection(title: "Flavors",
                                           you:   input.flavors,
                                           somm:  aiProfile.flavors)
                    }
                }
                
                Rectangle()
                    .fill(Color.burgundy)       // Use .fill instead of .foregroundStyle for reliability
                    .frame(height: 0.5)          // This sets the thickness
                
                // notes
                card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").font(.headline)
                        NotesStep(notes: $input.notes)
                    }
                }
                
                Rectangle()
                    .fill(Color.burgundy)       // Use .fill instead of .foregroundStyle for reliability
                    .frame(height: 0.5)            // This sets the thickness
                
                // palate tip
                if let tip = aiProfile.tips.first {
                    card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Palate Tip").font(.headline)
                            Text(tip).italic()
                        }
                    }
                }
            }
           
            .padding(.horizontal)
            .padding(.bottom, 32)
            }
            .safeAreaInset(edge: .bottom) {
              Color.clear.frame(height: 20)   // reserve 72 pts for your button
            }
            .safeAreaInset(edge: .top) {
              Color.clear.frame(height: 20)   // reserve 72 pts for your button
            }
            .scrollDismissesKeyboard(.interactively)
                // tap anywhere to dismiss keyboard
                .onTapGesture {
                    UIApplication.shared.sendAction(
                      #selector(UIResponder.resignFirstResponder),
                      to: nil, from: nil, for: nil
                    )
                }
            }

// MARK: – Comparison rows
private var comparisonRows: some View {
    VStack(spacing: 15) {
        // header
        HStack {
            Spacer().frame(width: 90)
            Spacer(minLength: 12)
            Text("You")
                .font(.headline.bold())
                .foregroundStyle(Color.burgundy)
                .frame(width: pillWidth)
            
            Spacer(minLength: 12)
            Text("Vini AI")
                .font(.headline.bold())
                .foregroundStyle(Color.burgundy)
                .frame(width: pillWidth)
        }
        
        // data rows
        compRow("Acidity",   input.acidity,   aiProfile.acidity)
        compRow("Alcohol",   input.alcohol,   aiProfile.alcohol)
        
        // ← only show Tannin if hasTannin == true
               if aiProfile.hasTannin {
                   compRow("Tannin", input.tannin, aiProfile.tannin)
               }
        
        compRow("Body",      input.body,      aiProfile.body)
        compRow("Sweetness", input.sweetness, aiProfile.sweetness)
    }
}

private func compRow<E: RawRepresentable>(
    _ title: String, _ you: E, _ classic: E
) -> some View where E.RawValue == String {
    let youTxt = pretty(you.rawValue)
    let clsTxt = pretty(classic.rawValue)
    let differs = youTxt != clsTxt
    
    return HStack {
        Text(title)
            .frame(width: 90, alignment: .leading)
        
        Spacer(minLength: 12)
        
        pill(youTxt, fg: .primary)
        
        Image(systemName: differs ? "xmark.circle.fill" : "checkmark.circle.fill")
            .foregroundColor(differs ? .orange : .green)
            .font(.caption)
            .accessibilityHidden(true)
        
        pill(clsTxt, fg: .primary)
    }
}

// MARK: – New grouped comparison section
@ViewBuilder
private func pillColumnsSection(title: String,
                                you: [String],
                                somm: [String]) -> some View {
    
    let shared     = Set(you).intersection(somm)
    let youOnly    = you.filter { !shared.contains($0) }
    let sommOnly   = somm.filter { !shared.contains($0) }
    
    VStack(alignment: .leading, spacing: 12) {
        
        Text(title).font(.headline)
        
        HStack(alignment: .top, spacing: 12) {
            
            // ── Left column: You Detected ──────────────
            VStack(alignment: .center, spacing: 8) {
                Text("You Detected")
                    .font(.headline.bold())
                    .foregroundStyle(classicFG)
                ForEach(shared.sorted(),  id: \.self) {
                    pill(pretty($0), matched: true)
                }
                ForEach(youOnly.sorted(), id: \.self) {
                    pill(pretty($0))                     // no border
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // ── Right column: Somm Detected ───────────
            VStack(alignment: .center, spacing: 8) {
                Text("Vini AI Detected")
                    .font(.headline.bold())
                    .foregroundStyle(classicFG)
                ForEach(shared.sorted(),  id: \.self) {
                    pill(pretty($0), matched: true)
                }
                ForEach(sommOnly.sorted(), id: \.self) {
                    pill(pretty($0))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: – Card wrapper
@ViewBuilder
private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Latte").opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}
}

#if DEBUG
// ---------- Quick Preview ----------

/// Quick mock enums so the preview compiles in isolation
private enum MockIntensity: String, CaseIterable {
    case low, mediumMinus = "medium-", medium, mediumPlus = "medium+", high, unknown
}
private enum MockBody: String, CaseIterable { case light, medium, full, unknown }
private enum MockSweet: String, CaseIterable {
    case boneDry = "bone-dry", dry, offDry = "off-dry", sweet, verySweet, unknown
}

/// Dummy input & AI profile
private var sampleInput: TastingInput {
    var inpt = TastingInput()
    inpt.acidity   = .mediumPlus
    inpt.alcohol   = .medium
    inpt.tannin    = .low
    inpt.body      = .medium
    inpt.sweetness = .dry
    inpt.aromas    = ["Cherry", "Vanilla"]
    inpt.flavors   = ["Cherry", "Vanilla"]
    inpt.notes     = "Bright and balanced, subtle oak."
    return inpt
}

private let sampleAI = AITastingProfile(
    acidity:   .high,
    alcohol:   .medium,
    tannin:    .low,
    body:      .medium,
    sweetness: .dry,
    aromas:    ["Cherry", "Rose", "Earth"],
    flavors:    ["Cherry", "Rose", "Earth"],
    tips:      ["Focus on the crisp acidity — think green apple."],
    hasTannin: true
)

struct TastingSummaryView_Previews: PreviewProvider {
    @State static var input = sampleInput   // binding for live editing
    
    static var previews: some View {
        TastingSummaryView(
            input: $input,
            aiProfile: sampleAI,
            wineName: "Château Preview 2020"
        )
        .preferredColorScheme(.light)
        .previewLayout(.sizeThatFits)
    }
}
#endif
