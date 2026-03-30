//
//  DashboardView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//
// Supporting view (RecentScanCard) is kept inline because it’s small and file-scoped.

import SwiftUI
import CoreData
import UIKit          // for UIImage

struct DashboardView: View {
    @EnvironmentObject private var openAIManager: OpenAIManager
    @EnvironmentObject var auth: AuthViewModel
    // MARK: – Environment / Bindings
    @Environment(\.managedObjectContext) private var ctx
    @Binding var selectedTab: MainTab   // lets the button jump to Scan tab
    
    // MARK: – Core Data Fetches
    
    @FetchRequest(
        fetchRequest: {
            let req = BottleScan.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(keyPath: \BottleScan.timestamp,
                                                    ascending: false)]
            req.fetchLimit = 5
            return req
        }(), animation: .default
    ) private var recentScans: FetchedResults<BottleScan>
    
    
    @StateObject private var refreshNotifier = RefreshNotifier()   // ← NEW
    
    // MARK: – State / AppStorage
    @State private var scanPrompt: String = ""
    @State private var showingAccount = false                      // ← NEW
    @AppStorage("homeViewOpenCount") private var openCount     = 0
    @AppStorage("lastScanPrompt")    private var lastScanPrompt = ""
    
    // MARK: – View
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // ── Header ──
                    HStack {
                        Text("Your Dashboard")
                            .font(.title.bold())
                        
                        Spacer()
                        
                        // ⬇︎ SHOW UPGRADE OR PRO BADGE DEPENDING ON SUBSCRIPTION
                        if auth.hasActiveSubscription {
                            // already Pro ➜ show a little badge, no tap action
                            Label {
                                Text("Pro")
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(Color("Latte"))                 // ← text color
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("Burgundy"))                   // ← background fill
                            .clipShape(Capsule())
                            .accessibilityLabel("SommLens Pro active")
                        } else {
                            // on Free tier ➜ tappable Upgrade button
                            Button("Upgrade") {
                                auth.isPaywallPresented = true
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.burgundy)
                            .clipShape(Capsule())
                            .accessibilityLabel("Upgrade to SommLens Pro")
                        }
                        
                        Button {
                            showingAccount = true            // open sheet
                        } label: {
                            Image(systemName: "gearshape")   // SF-Symbols gear
                                .font(.title2.bold())
                                .foregroundColor(.burgundy)
                        }
                    }
                    .padding(.horizontal)
                    
#if DEBUG
Picker("Debug Entitlement", selection: Binding(
    get: { auth.getDebugOverride().rawValue },
    set: { raw in
        let val = AuthViewModel.DebugEntitlementOverride(rawValue: raw) ?? .none
        auth.setDebugOverride(val)
    }
)) {
    Text("RC").tag(AuthViewModel.DebugEntitlementOverride.none.rawValue)
    Text("Free").tag(AuthViewModel.DebugEntitlementOverride.forceFree.rawValue)
    Text("Pro").tag(AuthViewModel.DebugEntitlementOverride.forcePro.rawValue)
}
.pickerStyle(.segmented)
.padding(.horizontal)
#endif
                    
                    
                    // ── Recent Scans Section ──
                    Text("Recent Scans")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    recentScansView
                        .frame(height: 225)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.latte))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.burgundy, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    // ── Inspiration Tip Section ──
                    Text("Need Inspiration?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    Text(scanPrompt)
                        .font(.headline.weight(.regular))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .padding(.top, 24)             // space below drag indicator
            }
        }
        .background(Color.white)           // keep sheet white
        .onAppear(perform: updatePrompt)
        
        .sheet(isPresented: $showingAccount) {
            NavigationStack {
                AccountView(
                    refreshNotifier: refreshNotifier,   // <-- SAME object
                    context: ctx                        // Core-Data context
                )
                .environment(\.managedObjectContext, ctx)
            }
        }
    }
    
    // MARK: – Recent Scans Sub-view
    @ViewBuilder
    private var recentScansView: some View {
        if recentScans.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "wineglass")
                    .font(.title)
                    .foregroundColor(.burgundy)
                Text("No recent scans yet.\nScan a bottle to get started!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recentScans.prefix(5), id: \.id!) { scan in
                        let wine  = decodeWine(scan)
                        let image = decodeImage(scan)
                        
                        // Prevent crashing if decode fails
                        if let wine, let image {
                            NavigationLink {
                                WineDetailView(
                                    bottle: scan,
                                    wineData: wine,
                                    snapshot: image,
                                    openAIManager: openAIManager,
                                    ctx: ctx
                                )
                            } label: {
                                RecentScanCard(
                                    wine: wine,
                                    image: image
                                )
                            }
                            .frame(width: 140)
                        } else {
                            RecentScanCard(wine: nil, image: nil)
                                .frame(width: 140)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func decodeWine(_ scan: BottleScan) -> WineData? {
        guard let raw = scan.rawJSON,
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WineData.self, from: data)
    }
    
    private func decodeImage(_ scan: BottleScan) -> UIImage? {
        guard let data = scan.screenshot else { return nil }
        return UIImage(data: data)
    }
    
    private func updatePrompt() {
        openCount += 1
        if openCount == 1 || openCount % 3 == 0 {
            let newPrompt = ScanPrompts.all.randomElement() ?? ""
            lastScanPrompt = newPrompt
            scanPrompt     = newPrompt
        } else {
            scanPrompt     = lastScanPrompt
        }
    }
}
