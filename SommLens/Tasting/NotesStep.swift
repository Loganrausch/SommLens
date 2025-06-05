//
//  NotesStep.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

// MARK: - NotesStep with focus‑aware placeholder
struct NotesStep: View {
    @Binding var notes: String
    @FocusState private var isEditing: Bool
    private let placeholder = "Jot down your impressions..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Any other thoughts?")
                .font(.body)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .padding(8)
                    .background(Color.clear)
                    .focused($isEditing)
                   
                
                // Placeholder disappears as soon as field gains focus
                if notes.isEmpty && !isEditing {
                    Text(placeholder)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                
                }
            }
            .frame(height: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.4))
            )
        }
        .tint(.burgundy)
    }
}
