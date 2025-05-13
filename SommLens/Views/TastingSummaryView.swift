//
//  TastingSummaryView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct TastingSummaryView: View {
    let input:      TastingInput
    let aiProfile:  AITastingProfile
    let wineName:   String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Tasting vs. Classic Profile")
                    .font(.title3).bold()
                
                // five core structure rows
                summaryRow(title: "Acidity",   user: input.acidity,   classic: aiProfile.acidity)
                summaryRow(title: "Alcohol",   user: input.alcohol,   classic: aiProfile.alcohol)
                summaryRow(title: "Tannin",    user: input.tannin,    classic: aiProfile.tannin)
                summaryRow(title: "Body",      user: input.body,      classic: aiProfile.body)
                summaryRow(title: "Sweetness", user: input.sweetness, classic: aiProfile.sweetness)
                
                // flavours
                if !input.flavors.isEmpty {
                    Divider()
                    Text("Your Flavors:").font(.headline)
                    Text(input.flavors.joined(separator: ", "))
                }
                
                // free‑form notes
                if !input.notes.isEmpty {
                    Divider()
                    Text("Notes:").font(.headline)
                    Text(input.notes)
                }
                
                // palate tip
                if let tip = aiProfile.tips.first {
                    Divider()
                    Text("Palate Tip:").font(.headline)
                    Text(tip).italic()
                }
            }
            .padding()
        }
    }
    
    /// Generic helper rows – works for any enum with `RawValue == String`
    private func summaryRow<E: RawRepresentable>(title: String,
                                                 user: E,
                                                 classic: E) -> some View where E.RawValue == String
    {
        HStack {
            Text(title)
                .frame(width: 90, alignment: .leading)
            
            Spacer()
            
            Text(pretty(user.rawValue))
                .fontWeight(.medium)
            
            Spacer()
            
            Text("Classic: \(pretty(classic.rawValue))")
                .foregroundColor(.secondary)
        }
    }
    
    /// Replace hyphen with non‑breaking “‑” and capitalize
    private func pretty(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: "‑").capitalized
    }
}
