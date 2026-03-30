//
//  MyScansView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.

import SwiftUI
import CoreData
import UIKit

struct MyScansView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var openAIManager: OpenAIManager
    @EnvironmentObject var auth: AuthViewModel

    @State private var page: Int = 0
    private let pageSize: Int = 6

    @State private var scans: [BottleScan] = []
    @State private var isLoading = false
    @State private var hasNextPage = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    if !auth.hasActiveSubscription {
                        Text("SommLens Free shows your 6 most recent scans. Upgrade to view your full scan history.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.burgundy)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 5)
                    }

                    if scans.isEmpty && !isLoading {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(scans, id: \.objectID) { scan in
                                let wine = decodeWine(scan)
                                let image = decodeImage(scan)

                                NavigationLink {
                                    if let wine, let image {
                                        WineDetailView(
                                            bottle: scan,
                                            wineData: wine,
                                            snapshot: image,
                                            openAIManager: openAIManager,
                                            ctx: ctx
                                        )
                                    } else {
                                        Text("Couldn’t load this scan.")
                                    }
                                } label: {
                                    RecentScanCard(
                                        wine: wine,
                                        image: image,
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(scan)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .padding(.top, 20)

                        if auth.hasActiveSubscription && (hasNextPage || page > 0) {
                            pagingControls.padding(.top, 8)
                        }
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("My Wines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !auth.hasActiveSubscription {
                        Button {
                            auth.isPaywallPresented = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("Upgrade")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.burgundy)
                        }
                    }
                }
            }
            .overlay(alignment: .center) {
                if isLoading && scans.isEmpty {
                    ProgressView()
                }
            }
            .task { await loadPage(resetToFirst: true) }
            
            .onChange(of: auth.hasActiveSubscription) { _, _ in
                Task { await loadPage(resetToFirst: true) }
            }
            
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadPage(resetToFirst: false) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wineglass")
                .font(.largeTitle)
                .foregroundColor(.burgundy)
            Text("Scan a bottle to get started!")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var pagingControls: some View {
        HStack(spacing: 18) {

            // Previous
            Button {
                Task { await loadPrev() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))   // ⬆️ bigger
                    .frame(width: 44, height: 44)                 // ⬆️ Apple HIG hit area
            }
            .disabled(page == 0 || isLoading)
            .opacity(page == 0 ? 0.35 : 1)

            // Page indicator
            Text("\(page + 1)")
                .font(.headline.weight(.semibold))                // ⬆️ bigger text
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .accessibilityLabel("Page \(page + 1)")

            // Next
            Button {
                Task { await loadNext() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))   // ⬆️ bigger
                    .frame(width: 44, height: 44)
            }
            .disabled(!hasNextPage || isLoading)
            .opacity(!hasNextPage ? 0.35 : 1)
        }
        .padding(.vertical, 16)
    }
    
    
    @MainActor
    private func loadPrev() async {
        guard auth.hasActiveSubscription else { return }
        guard page > 0 else { return }
        page -= 1
        await loadPage(resetToFirst: false)
    }

    @MainActor
    private func loadNext() async {
        guard auth.hasActiveSubscription else { return }
        guard hasNextPage else { return }
        page += 1
        await loadPage(resetToFirst: false)
    }

    @MainActor
    private func loadPage(resetToFirst: Bool) async {
        isLoading = true
        defer { isLoading = false }

        if resetToFirst { page = 0 }

        // ✅ Free users are always locked to page 0
        let isPro = auth.hasActiveSubscription
        if !isPro {
            page = 0
        }

        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        req.sortDescriptors = [
            NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)
        ]

        req.fetchLimit = pageSize + 1

        // ✅ Only allow offset paging for Pro users
        if isPro {
            req.fetchOffset = page * pageSize
        } else {
            req.fetchOffset = 0
        }

        do {
            let result = try ctx.fetch(req)

            scans = Array(result.prefix(pageSize))

            // ✅ Only Pro users can ever have a “next page”
            hasNextPage = isPro && result.count > pageSize
        } catch {
            scans = []
            hasNextPage = false
            #if DEBUG
            print("❌ MyScans loadPage failed:", error.localizedDescription)
            #endif
        }
    }
    
    @MainActor
    private func delete(_ scan: BottleScan) {
        ctx.delete(scan)
        try? ctx.save()

        Task {
            await loadPage(resetToFirst: false)

            // If we deleted the last item on a page, step back one page.
            if scans.isEmpty && page > 0 {
                page -= 1
                await loadPage(resetToFirst: false)
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
}
