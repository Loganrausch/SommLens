//
//  FlavorSelectionStep.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct FlavorSelectionStep: View {
    @Binding var selectedFlavors: [String]
    let options: [String]

    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        VStack(spacing: 16) {
            Text("Which flavors do you notice?")
                .font(.title2)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(options, id: \.self) { flavor in
                    Button { toggle(flavor) } label: {
                        Text(flavor)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedFlavors.contains(flavor)
                                ? Color.accentColor.opacity(0.8)
                                : Color.secondary.opacity(0.15)
                            )
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private func toggle(_ flavor: String) {
        if let idx = selectedFlavors.firstIndex(of: flavor) {
            selectedFlavors.remove(at: idx)
        } else {
            selectedFlavors.append(flavor)
        }
    }
}
