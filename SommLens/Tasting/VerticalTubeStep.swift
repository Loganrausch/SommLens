//
//  TastingIntensityStep.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI
import UIKit   // haptics

struct VerticalTubeStep<E>: View where
    E: RawRepresentable & CaseIterable & Hashable,
    E.RawValue == String
{
    let title: String
    let options: [E]
    @Binding var selection: E
    
    private var filtered: [E] { options.filter { "\($0)" != "unknown" } }
    private var idx: Int      { filtered.firstIndex(of: selection) ?? 0 }
    private var count: Int    { filtered.count }
    
    var body: some View {
        VStack(spacing: 24) {
            
            Text("How would you rate this wine’s \(title.lowercased())?")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 40)
            
            GeometryReader { geo in
                let stroke: CGFloat = 2
                let tubeW:  CGFloat = 90
                let tubeH            = geo.size.height
                let innerH           = tubeH - stroke * 2
                let segH             = innerH / CGFloat(count)
                
                // ── Tube centred; labels over‑laid to the right ─────────
                ZStack {
                    // tube + liquid
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.burgundy)
                            .frame(
                                width: tubeW - stroke,
                                height: idx == count - 1
                                    ? innerH + 3
                                    : (CGFloat(idx) + 0.75) * segH
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.black, lineWidth: stroke)
                            .frame(width: tubeW)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let y     = max(0, min(val.location.y, tubeH))
                                let newIx = count - 1 - Int((y - stroke) / segH)
                                updateSelection(to: newIx)
                            }
                    )
                    .animation(.easeInOut(duration: 0.15), value: selection)
                    
                    // labels overlay (doesn't affect centering)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered.reversed(), id:\.self) { opt in
                            Text(label(opt))
                                .font(.caption)
                                .bold()
                                .frame(height: segH)
                                .foregroundColor(opt == selection ? .burgundy : .secondary)
                        }
                    }
                    .offset(x: tubeW / 2 + 40)       // 8‑pt gap to the right of tube
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 450)
        }
        .padding()
    }
    
    // MARK: helpers
    private func updateSelection(to newIdx: Int) {
        guard filtered.indices.contains(newIdx), filtered[newIdx] != selection else { return }
        selection = filtered[newIdx]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func label(_ opt: E) -> String {
        opt.rawValue
            .replacingOccurrences(of: "medium-",  with: "Med‑")
            .replacingOccurrences(of: "medium+",  with: "Med+")
            .replacingOccurrences(of: "-",        with: "‑")
            .capitalized
    }
}

#if DEBUG
fileprivate enum Mock: String, CaseIterable, Hashable {
    case low, mediumMinus = "medium-", medium, mediumPlus = "medium+", high
}

struct TubePreview: View {
    @State private var sel: Mock = .medium
    var body: some View {
        VerticalTubeStep(title: "Acidity",
                         options: Mock.allCases,
                         selection: $sel)
            .frame(width: 180)
            .padding()
    }
}

struct TubePreview_Previews: PreviewProvider {
    static var previews: some View { TubePreview() }
}
#endif
