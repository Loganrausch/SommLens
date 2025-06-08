//
//  Untitled.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI

struct InfoTile: View {
    var label: String
    var value: String?
    
    var body: some View {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
