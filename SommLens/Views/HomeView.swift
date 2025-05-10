//
//  HomeView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/21/25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Binding var selectedTab: MainTab          // ← injected binding

    // last 5 scans
    @FetchRequest(
        fetchRequest: {
            let req = BottleScan.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)]
            req.fetchLimit = 5
            return req
        }(), animation: .default
    ) private var recentScans: FetchedResults<BottleScan>

    @State private var pulse = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 24) {

                    // ─── Fixed card that hosts the carousel ───
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 6)

                        if !recentScans.isEmpty {
                            TabView {
                                ForEach(recentScans, id: \.self) { scan in
                                    if let data = scan.screenshot,
                                       let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()      // keep whole shot, no crop
                                            .cornerRadius(20)
                                            .padding(12)        // keep away from edges
                                    } else {
                                        Color.secondary.opacity(0.1)
                                            .overlay(Text("No Image")
                                                .foregroundColor(.secondary))
                                    }
                                }
                            }
                            .tabViewStyle(
                                PageTabViewStyle(indexDisplayMode: .automatic)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            Text("Your recent scans will appear here.")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .frame(height: 300)           // <- ONLY fixed dimension
                    .padding(.horizontal, 20)     // aligns with button

                    Spacer()                       // push button down

                    /* ── Scan Bottle button now just switches tab ── */
                                       Button {
                                           selectedTab = .scan          // ← jump to Scan tab
                                       } label: {
                                           Text("Scan a Bottle")
                            .font(.title2.bold())
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color("Latte"))
                            .foregroundColor(Color("Burgundy"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("Burgundy").opacity(0.4), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(pulse ? 0.4 : 0.2),
                                    radius: pulse ? 20 : 8, y: 5)
                            .scaleEffect(pulse ? 1.03 : 1)
                            .animation(
                                .easeInOut(duration: 1.4)
                                    .repeatForever(autoreverses: true),
                                value: pulse
                            )
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("SommLens")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { pulse = true }
        }
    }
}
