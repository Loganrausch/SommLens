//
//  ARScanResultView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/23/25.
//

import SwiftUI

struct ARScanResultView: View {
    @Environment(\.dismiss) private var dismiss

    let capturedImage: UIImage
    let wineData:      WineData

    // sheet toggle
    @State private var showSheet = false

    var body: some View {
        ZStack {
            /* ───── Hero bottle photo ───── */
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea(.container, edges: .horizontal)   // ← match ARScanView
            
            /* ───── Gradient for legibility ───── */
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .center, endPoint: .bottom
            )
            .allowsHitTesting(false)              // let touches through

            /* ───── Quick‑info overlay ───── */
            VStack(spacing: 0) {
                Spacer()                                  // push overlay to bottom edge

                /* material‑backed tray */
                VStack(spacing: 12) {

                    // drag‑handle / chevron AT TOP
                    Button { showSheet = true } label: {
                        Image(systemName: "chevron.up")
                            .font(.title2.weight(.medium))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    // cards now naturally sit ~centre of the tray
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            QuickCard(title: "Producer", text: wineData.producer)
                            QuickCard(title: "Vintage",  text: wineData.vintage)
                            QuickCard(title: "Region",   text: wineData.region)
                            QuickCard(title: "Grapes",   text: wineData.grapes?.joined(separator: ", "))
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 90)

                }
                .padding(.vertical, 12)                   // equal top / bottom padding
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 12)
                .padding(.bottom, 20)                     // safe distance from bottom
            }
            .frame(maxWidth: .infinity)
            // blur behind cards
            
        }
        .navigationBarBackButtonHidden(true)          // custom dismiss
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(radius: 3)
            }
            .padding(.top, 30)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showSheet) {
            WineDetailView(wineData: wineData,
                           snapshot: capturedImage)
            .presentationDetents([.large])
        }
    }
}

/* ---------- Quick info card (uniform width) ---------- */
private struct QuickCard: View {
    let title: String
    let text:  String?

    private let cardWidth:  CGFloat = 170
    private let cardHeight: CGFloat = 95

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.burgundy)
                .bold()

            Text(text ?? "-")
                .font(.headline).bold()
                .lineLimit(2)              // wrap once; truncate beyond that
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
