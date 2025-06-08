//
//  DashboardView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//
//  Handles the main Dashboard tab.
//  It includes scan stats, recent scans, subscription info, and scan prompt rotation.
//
//  Supporting views like StatCard, QuotaCard, and RecentScanCard are kept inline
//  because they’re small, used only within this file, and don’t carry independent logic.
//  Splitting them out would’ve added noise to the project structure without
//  improving clarity, so everything remains scoped and self-contained.

import SwiftUI
import CoreData
import UIKit          // for UIImage
import RevenueCatUI

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
    
    private var resetString: String {
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        
        guard let startOfMonth = Calendar.current.date(from: comps),
              let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            return "--"
        }

        return nextMonth.formatted(date: .abbreviated, time: .omitted)
    }
    
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
                    
                    // ── Scan Stats Section ──
                    Text("Scan Stats")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    QuotaCard(
                        used: scansUsed,
                        limit: auth.scanLimit,
                        resetDate: auth.hasActiveSubscription ? resetString : "--"
                    )
                    .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    
                    
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
                        .multilineTextAlignment(.center)
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
    
    private var scansUsed: Int {
        auth.getScanCount()
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
                                RecentScanCard(wine: wine, image: image)
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
    

// MARK: – StatCard
private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            Color(.latte),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.burgundy, lineWidth: 1)
        )
    }
}

// ─────────────────────────────────────────────────────────────
// QuotaCard: shows scans-used and reset-date under each title
// ─────────────────────────────────────────────────────────────
private struct QuotaCard: View {
    let used: Int
    let limit: Int
    let resetDate: String

    var body: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("Scans Used")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(used) / \(limit)")
                    .font(.title3.bold())
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Resets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(resetDate)
                    .font(.title3.bold())
            }
        }
        .padding()
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity)
        .background(
            Color(.latte),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.burgundy, lineWidth: 1)
        )
    }
}

// MARK: – RecentScanCard
private struct RecentScanCard: View {
    let wine: WineData?
    let image: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(radius: 4)
                    .frame(height: 140)

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Color.secondary.opacity(0.1)
                        .frame(height: 140)
                        .cornerRadius(12)
                        .overlay(
                            Text("No Image")
                                .foregroundColor(.secondary)
                        )
                }
            }

            if let wine = wine {
                Text("\(wine.vintage ?? "-") • \(wine.producer ?? "Unknown")")
                    .font(.caption.bold())
                    .foregroundColor(.black) // 👈 force black
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(wine.region ?? "-")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No Data")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 140)
    }
}
