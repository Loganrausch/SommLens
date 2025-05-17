//
//  WineDetailView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

// WineDetailView.swift

// WineDetailView.swift

import SwiftUI

struct WineDetailView: View {
    let wineData: WineData
    let snapshot: UIImage?

    @Environment(\.dismiss) private var dismiss
    @State private var animate = false

    var body: some View {
        ZStack {
            // Optional background texture or material
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 32) {
                        // 1) Snapshot Image
                        if let img = snapshot {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 220)
                                .cornerRadius(20)
                                .shadow(color: .primary.opacity(0.2), radius: 20, x: 0, y: 10)
                                .padding(.horizontal, 24)
                                .scaleEffect(animate ? 1.0 : 0.95)
                                .opacity(animate ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animate)
                        }

                        // 2) Title and Region
                        VStack(spacing: 8) {
                            if let vintage = wineData.vintage {
                                    Text(vintage)
                                    .font(.headline)
                                       .foregroundColor(.secondary)
                                       .scaleEffect(animate ? 1.0 : 0.95)
                                       .opacity(animate ? 1 : 0)
                                       .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animate)
                                }

                            Text(wineData.producer ?? "Unknown Producer")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .scaleEffect(animate ? 1.0 : 0.95)
                                .opacity(animate ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animate)

                            Text("\(wineData.region ?? "-") · \(wineData.country ?? "-")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .scaleEffect(animate ? 1.0 : 0.95)
                                .opacity(animate ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animate)
                            
                            Text("\(wineData.category.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .scaleEffect(animate ? 1.0 : 0.95)
                                .opacity(animate ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animate)
                            
                            
                        }

                        // 3) Details
                        VStack(spacing: 16) {
                            DetailSection(title: "Overview") {
                                DetailRow(title: "Grapes", value: (wineData.grapes ?? []).joined(separator: ", "))
                                DetailRow(title: "Vineyard", value: wineData.vineyard ?? "-")
                                DetailRow(title: "Classification", value: wineData.classification ?? "-")
                            }

                            DetailSection(title: "Tasting Notes") {
                                DetailRow(title: "Notes", value: wineData.tastingNotes ?? "-")
                            }
                            
                            DetailSection(title: "Terroir") {
                                DetailRow(title: "Climate", value: wineData.climate ?? "-")
                                DetailRow(title: "Soil Type", value: wineData.soilType ?? "-")
                            }
                            
                            DetailSection(title: "Extras") {
                                DetailRow(title: "Pairings", value: (wineData.pairings ?? []).joined(separator: ", "))
                                DetailRow(title: "Vibe", value: wineData.vibeTag ?? "-")
                                DetailRow(title: "Alcohol Level", value: wineData.abv ?? "-")
                                DetailRow(title: "When to drink", value: wineData.drinkingWindow ?? "-")
                                DetailRow(title: "Winemaking Style", value: wineData.winemakingStyle ?? "-")
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(24)
                        .shadow(radius: 5)
                        .opacity(animate ? 1 : 0) // just fade, no scale
                        .animation(.easeOut(duration: 0.5), value: animate)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(width: geo.size.width)
            }

            // 4) Dismiss Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.burgundy)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.burgundy.opacity(0.2), lineWidth: 1))
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { animate = true }
        .navigationBarHidden(true)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundColor(.burgundy)
            VStack(spacing: 12) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
        .overlay(
            Divider()
                .background(Color("Burgundy")),
            alignment: .bottom
        )
    }
}
