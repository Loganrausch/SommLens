//
//  DashboardView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import SwiftUI
import CoreData
import UIKit          // for UIImage

struct DashboardView: View {

    // MARK: – Environment / Bindings
    @Environment(\.managedObjectContext) private var ctx
    @Binding var selectedTab: MainTab   // lets the button jump to Scan tab

    // MARK: – Core Data Fetches
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BottleScan.timestamp,
                                           ascending: false)],
        animation: .default
    ) private var allScans: FetchedResults<BottleScan>

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
        ScrollView {
            VStack(spacing: 24) {
                
                // ── Header ──
                HStack {
                    Text("Your Dashboard")
                        .font(.title.bold())
                    
                    Spacer()
                    
                    Button {
                        showingAccount = true            // open sheet
                    } label: {
                        Image(systemName: "gearshape")   // SF-Symbols gear
                            .font(.title2)
                            .foregroundColor(.burgundy)
                    }
                }
                .padding(.horizontal)
                
                // ── Scan Stats Section ──
                Text("Scan Stats")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    StatCard(title: "Monthly Scans", value: "\(scansThisMonth)")
                    StatCard(title: "Total Scans",   value: "\(allScans.count)")
                }
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
                        let wine = decodeWine(scan)
                        let img  = decodeImage(scan)
                        RecentScanCard(wine: wine, image: img)
                            .frame(width: 140)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: – Helpers
    private var scansThisMonth: Int {
        let cal   = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        let start = cal.date(from: comps)!
        return allScans.filter { ($0.timestamp ?? .distantPast) >= start }.count
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
            let newPrompt = scanPrompts.randomElement() ?? ""
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
