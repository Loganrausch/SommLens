//
//  NotesStep.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct NotesStep: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anything else you noticed?")
                .font(.title2)

            TextEditor(text: $notes)
                .frame(height: 160)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4))
                )
        }
    }
}
