//
//  FlavorSelectionStep.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct SelectionGrid: View {
    let title: String
    let options: [String]
    @Binding var selection: [String]
    var maxSelection: Int = 4                       // ← easily tweaked later
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                
                Text("(Choose up to Four)")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(options, id: \.self) { item in
                    let isSelected = selection.contains(item)
                    let atLimit    = selection.count >= maxSelection
                    let blocked    = !isSelected && atLimit       // can’t pick more
                    
                    Button {
                        toggle(item, blocked: blocked)
                    } label: {
                        Text(item)
                            .font(.callout.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                isSelected ? Color("Burgundy")
                                           : (blocked ? Color("Latte").opacity(0.4)
                                                      : Color("Latte"))
                            )
                            .foregroundColor(
                                isSelected ? Color("Latte")
                                           : Color("Burgundy").opacity(blocked ? 0.4 : 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("Burgundy"), lineWidth: 2)
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(blocked)                      // taps ignored when at limit
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .center)   // vertical centring
    }
    
    // MARK: – Toggle + haptic
    private func toggle(_ item: String, blocked: Bool) {
        if blocked {
            let warn = UINotificationFeedbackGenerator()
            warn.notificationOccurred(.error)              // attempted 5th selection
            return
        }
        
        let tap = UIImpactFeedbackGenerator(style: .light)
        tap.impactOccurred()
        
        if let idx = selection.firstIndex(of: item) {
            selection.remove(at: idx)
        } else {
            selection.append(item)
        }
    }
}
