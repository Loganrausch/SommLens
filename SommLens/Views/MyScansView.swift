//
//  MyScansView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI
import CoreData
import UIKit    // for UIImage

struct MyScansView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.editMode) private var editMode

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)],
        animation: .default
    )
    private var scans: FetchedResults<BottleScan>

    // Single‐tap detail
    @State private var selectedScan: BottleScan? = nil
    // Multi‐select delete
    @State private var selectedScanIDs = Set<UUID>()

    var body: some View {
        NavigationStack {
            List(selection: $selectedScanIDs) {
                ForEach(scans, id: \.id) { scan in
                    // Decode WineData for display
                    if let rawJSON = scan.rawJSON,
                       let data    = rawJSON.data(using: .utf8),
                       let wine    = try? JSONDecoder().decode(WineData.self, from: data)
                    {
                        Button {
                            selectedScan = scan
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(scan.timestamp.map { "\($0, formatter: dateFormatter)" } ?? "-")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(wine.producer ?? "Unknown Producer")
                                        .font(.body)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Fallback for invalid scan
                        VStack(alignment: .leading) {
                            Text("Invalid Scan")
                                .foregroundColor(.red)
                            Text(scan.timestamp.map { "\($0, formatter: dateFormatter)" } ?? "-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                // Swipe-to-delete
                .onDelete(perform: deleteScans)
            }
            // Detail sheet on tap
            .sheet(item: $selectedScan) { scan in
                Group {
                    if let rawJSON = scan.rawJSON,
                       let data    = rawJSON.data(using: .utf8),
                       let wine    = try? JSONDecoder().decode(WineData.self, from: data)
                    {
                        let snapshotImage = scan.screenshot
                            .flatMap { UIImage(data: $0) }
                        WineDetailView(wineData: wine, snapshot: snapshotImage)
                            .interactiveDismissDisabled(false)
                    } else {
                        VStack {
                            Text("Couldn't load details")
                            Button("Dismiss") { selectedScan = nil }
                                .padding(.top)
                        }
                        .padding()
                    }
                }
            }

            .navigationTitle("My Scans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Select All (only in Edit mode)
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if editMode?.wrappedValue == .active {
                        Button("Select All") {
                            selectedScanIDs = Set(scans.compactMap { $0.id })
                        }
                        .disabled(scans.isEmpty)
                    }
                }

                // Delete Selected + Edit/Done
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if editMode?.wrappedValue == .active {
                        Button("Delete Selected") {
                            deleteSelectedScans()
                        }
                        .foregroundColor(.red)
                        .disabled(selectedScanIDs.isEmpty)
                    }
                    EditButton()
                }
            }
        }
    }

    // MARK: – Helpers

    private func deleteScans(at offsets: IndexSet) {
        offsets.map { scans[$0] }
               .forEach(viewContext.delete)
        saveContext()
    }

    private func deleteSelectedScans() {
        for id in selectedScanIDs {
            if let scan = scans.first(where: { $0.id == id }) {
                viewContext.delete(scan)
            }
        }
        saveContext()
        selectedScanIDs.removeAll()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Core Data save error:", error)
        }
    }
}

// Shared date‐formatter
private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .short
    df.timeStyle = .short
    return df
}()
