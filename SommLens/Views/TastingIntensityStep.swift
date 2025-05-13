//
//  TastingIntensityStep.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct PickerStep<E: RawRepresentable & CaseIterable & Hashable>: View
where E.RawValue == String {
    let title: String
    let options: [E]
    @Binding var selection: E
    
    var body: some View {
        VStack(spacing: 24) {
            Text("How would you rate the \(title.lowercased())?")
                .font(.title2)
                .multilineTextAlignment(.center)
            
            Picker("", selection: $selection) {
                ForEach(options.filter { "\($0)".lowercased() != "unknown" }, id: \.self) { opt in
                    Text(optLabel(opt))
                }
            }
            .pickerStyle(.segmented)
        }
    }
    private func optLabel(_ opt: E) -> String {
        opt.rawValue.replacingOccurrences(of: "-", with: "‑").capitalized
    }
}
