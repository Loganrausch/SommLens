//
//  MyScansView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI
import CoreData
import UIKit   // for UIImage

/* ────────────────────────────────────────
 UI-level colour buckets → WineCategory
 ──────────────────────────────────────── */
enum ScanFilter: String, CaseIterable, Identifiable {
    case all, red, white, rosé, sparkling, orange
    var id: Self { self }
    var label: String { rawValue.capitalized }
    
    var matchingRawValues: [String] {
        switch self {
        case .all:
            return []
        case .red:
            return [WineCategory.red,
                    .redDessert,
                    .redFortified,
                    .redSparkling].map(\.rawValue)
        case .white:
            return [WineCategory.white,
                    .whiteDessert,
                    .whiteFortified].map(\.rawValue)
        case .rosé:
            return [WineCategory.rosé.rawValue]
        case .sparkling:
            return [WineCategory.whiteSparkling,
                    .redSparkling].map(\.rawValue)
        case .orange:
            return [WineCategory.orange.rawValue]
            
        }
    }
}

/* ────────────────────────────────────────
 Main View
 ──────────────────────────────────────── */
struct MyScansView: View {
    @Environment(\.managedObjectContext) private var ctx
    
    // Own this locally
    @State private var editMode: EditMode = .inactive
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)],
        animation: .default
    )
    private var scans: FetchedResults<BottleScan>
    
    // Single-tap detail
    @State private var selectedScan: BottleScan? = nil
    // Multi-select delete
    @State private var selectedScanIDs = Set<UUID>()
    
    // 🔹 NEW – search & filter state
    @State private var searchText = ""
    @State private var filter: ScanFilter = .all
    
    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    // ─── Empty placeholder ───
                    VStack(spacing: 12) {
                        Image(systemName: "wineglass")
                            .font(.largeTitle)
                            .foregroundColor(.burgundy)
                        Text("Scan a bottle to get started!")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    
                    List(selection: $selectedScanIDs) {
                        // a Section with an empty, fixed‐height header
                        Section(header:
                                    Color.clear
                            .frame(height: 10)           // ← how much space you want
                            .listRowInsets(.init())      // zero out the default insets
                        ) {
                            ForEach(filteredScans, id: \.id!) { scan in
                                /* ───── Row with thumbnail & badge ───── */
                                if let rawJSON = scan.rawJSON,
                                   let data    = rawJSON.data(using: .utf8),
                                   let wine    = try? JSONDecoder().decode(WineData.self, from: data)
                                {
                                    Button { selectedScan = scan } label: {
                                        HStack(spacing: 12) {
                                            
                                            VStack(alignment: .leading) {
                                                Text(scan.timestamp.map { "\($0, formatter: dateFormatter)" } ?? "-")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                HStack(spacing: 4) {
                                                    if let vintage = wine.vintage, !vintage.isEmpty {
                                                        Text(vintage)
                                                            .font(.body)
                                                    }
                                                    if let producer = wine.producer, !producer.isEmpty {
                                                        Text(producer)
                                                            .font(.body)
                                                            .lineLimit(1)
                                                    } else {
                                                        Text("Unknown Producer")
                                                            .font(.body.italic())
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                            if !scan.tastingsArray.isEmpty {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.burgundy.opacity(0.15))
                                                        .frame(width: 27, height: 27)
                                                    Image(systemName: "wineglass.fill")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.burgundy)
                                                }
                                            }
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            // find index in your filtered array, then delete that one
                                            if let idx = filteredScans.firstIndex(where: { $0.id == scan.id }) {
                                                deleteScans(at: IndexSet(integer: idx))
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                } else {        // invalid JSON fallback (unchanged)
                                    VStack(alignment: .leading) {
                                        Text("Invalid Scan").foregroundColor(.red)
                                        Text(scan.timestamp.map { "\($0, formatter: dateFormatter)" } ?? "-")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .tint(.red)    // only this list’s selection circles become red
                    .searchable(text: $searchText, prompt: "Producer, region, grape…")
                    
                    
                    /* Detail sheet (unchanged) */
                    .sheet(item: $selectedScan) { scan in
                        if let rawJSON = scan.rawJSON,
                           let data    = rawJSON.data(using: .utf8),
                           let wine    = try? JSONDecoder().decode(WineData.self, from: data) {
                            WineDetailView(
                                bottle:   scan,
                                wineData: wine,
                                snapshot: scan.screenshot.flatMap { UIImage(data: $0) }
                            )
                        } else {
                            VStack { Text("Couldn't load details") }
                        }
                    }
                }
            }
            
            .navigationTitle("My Wines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: Select All + EditButton
                ToolbarItem(placement: .navigationBarLeading) {
                    if !scans.isEmpty {                // ← added guard
                        EditButton().bold()
                    }
                }
                // Trailing: Delete Selected (in edit) or Filter menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !scans.isEmpty {                // ← added guard
                        if editMode == .active {
                            Button("Delete Selected", role: .destructive) {
                                deleteSelectedScans()
                            }
                            .tint(.red)
                            .disabled(selectedScanIDs.isEmpty)
                        } else {
                            Menu {
                                ForEach(ScanFilter.allCases) { f in
                                    Button(f.label) { filter = f }
                                }
                            } label: {
                                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
                }
            }
        }
        // **This** is the critical line: attach the binding at the NavigationStack root
        .environment(\.editMode, $editMode)
    }
    
    /* 🔹 Computed list after search + filter */
    private var filteredScans: [BottleScan] {
        scans.filter { scan in
            // 1) Colour bucket
            if filter != .all,
               let catRaw = scan.category,
               !filter.matchingRawValues.contains(catRaw) { return false }
            // 2) Text search
            guard !searchText.isEmpty else { return true }
            let needle = searchText.lowercased()
            let haystack = [
                scan.producer,
                scan.region,
                scan.grapes
            ].compactMap { $0?.lowercased() }
            return haystack.contains { $0.contains(needle) }
        }
    }
    
    // MARK: – Delete helpers (unchanged)
    private func deleteScans(at offsets: IndexSet) {
        offsets.map { filteredScans[$0] }.forEach(ctx.delete)
        saveContext()
    }
    private func deleteSelectedScans() {
        selectedScanIDs.forEach { id in
            if let s = scans.first(where: { $0.id == id }) { ctx.delete(s) }
        }
        saveContext(); selectedScanIDs.removeAll()
    }
    private func saveContext() { try? ctx.save() }
}

/* Shared date formatter (unchanged) */
private let dateFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
}()
