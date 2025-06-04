//
//  DebugSection.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

#if DEBUG
import SwiftUI

struct DebugSection: View {
    @AppStorage("forceFreeMode") private var forceFreeMode = false
    
    var body: some View {
        Section("Developer") {
            Toggle("Pretend Free Tier", isOn: $forceFreeMode)
                .tint(.red)
            Text("When ON, app ignores your real Pro subscription.\n(Launch-time toggle.)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
