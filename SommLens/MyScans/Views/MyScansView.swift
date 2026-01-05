//
//  MyScansView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

//  Displays user scan history with filter, search, and multi-select delete.
//
//  Yeah, this file does a lot — but everything here is UI-facing or scoped to this view.
//  I considered a ViewModel, but honestly it would’ve just moved code around without
//  adding clarity. Nothing here is reused and it's easy to follow.
//  Keeping it lean and local made more sense than slicing it up just to check MVVM box, will revisit if view expands.
//


import SwiftUI
import CoreData
import UIKit   // for UIImage

struct MyScansView: View {
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var openAIManager: OpenAIManager
    
    // Own this locally
    @State private var editMode: EditMode = .inactive
    
    @FetchRequest(
        fetchRequest: BottleScan.scansFetchRequest(),
        animation: .default
    )
    private var scans: FetchedResults<BottleScan>
    
    // Single-tap detail
    @State private var selectedScan: BottleScan? = nil
    // Multi-select delete
    @State private var selectedScanIDs = Set<UUID>()
    
    // Search & filter state
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
                        // small top spacer section
                        Section(
                            header: Color.clear
                                .frame(height: 10)
                                .listRowInsets(.init())
                        ) {
                            ForEach(filteredScans, id: \.identity) { scan in
                                scanRow(scan)   // ✅ no JSON decode here

                                    .onTapGesture {
                                        if editMode == .active {
                                            // multi-select toggle
                                            if let id = scan.id {
                                                if selectedScanIDs.contains(id) {
                                                    selectedScanIDs.remove(id)
                                                } else {
                                                    selectedScanIDs.insert(id)
                                                }
                                            }
                                        } else {
                                            // normal navigation → open detail sheet
                                            selectedScan = scan
                                        }
                                    }
                                    
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            if let idx = filteredScans.firstIndex(where: { $0.id == scan.id }) {
                                                deleteScans(at: IndexSet(integer: idx))
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .tint(.red)    // selection circles + swipe button accent
                    .searchable(text: $searchText, prompt: "Producer, region, grape…")
                    
                    // Detail sheet (JSON decode only happens here)
                    .sheet(item: $selectedScan) { scan in
                        if let rawJSON = scan.rawJSON,
                           let data    = rawJSON.data(using: .utf8),
                           let wine    = try? JSONDecoder().decode(WineData.self, from: data) {
                            
                            WineDetailView(
                                bottle:   scan,
                                wineData: wine,
                                snapshot: scan.screenshot.flatMap { UIImage(data: $0) },
                                openAIManager: openAIManager,
                                ctx: ctx
                            )
                        } else {
                            VStack {
                                Text("Couldn't load details")
                                    .font(.headline)
                                    .padding()
                            }
                        }
                    }
                }
            }
            
            .navigationTitle("My Wines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: EditButton
                ToolbarItem(placement: .navigationBarLeading) {
                    if !scans.isEmpty {
                        EditButton().bold()
                    }
                }
                
                // Trailing: Delete Selected (in edit) or Filter menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !scans.isEmpty {
                        if editMode == .active {
                            Button("Delete Selected", role: .destructive) {
                                deleteSelectedScans()
                            }
                            .tint(.red)
                            .disabled(selectedScanIDs.isEmpty)
                        } else {
                            Menu {
                                ForEach(ScanFilter.allCases) { f in
                                    Button {
                                        filter = f
                                    } label: {
                                        Label {
                                            Text(f.label)
                                        } icon: {
                                            if f == filter {
                                                Image(systemName: "checkmark")
                                            } else {
                                                EmptyView()
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
                }
            }
        }
        // attach editMode binding at the NavigationStack root
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Filtered list (search + colour filter)
    private var filteredScans: [BottleScan] {
        scans.filter { scan in
            // 1) Colour bucket
            if filter != .all,
               let catRaw = scan.category,
               !filter.matchingRawValues.contains(catRaw) {
                return false
            }
            
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
    
    // MARK: - Row view (no JSON decode)
    private func scanRow(_ scan: BottleScan) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scan.timestamp.map { "\($0, formatter: dateFormatter)" } ?? "-")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    // If you have a vintage property on BottleScan, use it:
                    if let vintage = scan.vintage, !vintage.isEmpty {
                        Text(vintage)
                            .font(.subheadline.weight(.medium))
                    }
                    
                    Text(scan.producer?.isEmpty == false ? scan.producer! : "Unknown Producer")
                        .lineLimit(1)
                        .font(.body)
                        .foregroundColor(scan.producer == nil ? .secondary : .primary)
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
        .contentShape(Rectangle())    // whole row is tappable
    }
    
    // MARK: – Delete helpers
    private func deleteScans(at offsets: IndexSet) {
        offsets.map { filteredScans[$0] }.forEach(ctx.delete)
        saveContext()
    }
    
    private func deleteSelectedScans() {
        selectedScanIDs.forEach { id in
            if let s = scans.first(where: { $0.id == id }) {
                ctx.delete(s)
            }
        }
        saveContext()
        selectedScanIDs.removeAll()
    }
    
    private func saveContext() {
        try? ctx.save()
    }
}

// Shared date formatter
private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f
}()
