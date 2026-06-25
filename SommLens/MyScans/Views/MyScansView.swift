//
//  MyScansView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.

import SwiftUI
import CoreData
import UIKit
import ImageIO

// MARK: - Thumbnail cache

enum ThumbnailCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 60
        c.totalCostLimit = 25 * 1024 * 1024
        return c
    }()

    static func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    static func decode(data: Data, key: String, maxPixelSize: CGFloat = 480) async -> UIImage? {
        if let hit = get(key) { return hit }

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                let opts: [CFString: Any] = [
                    kCGImageSourceShouldCache: false,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize * 3
                ]

                guard let src = CGImageSourceCreateWithData(data as CFData, nil),
                      let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
                else { return nil }

                let img = UIImage(cgImage: cg, scale: 3, orientation: .up)
                cache.setObject(img, forKey: key as NSString, cost: cg.bytesPerRow * cg.height)
                return img
            }
        }.value
    }
}

// MARK: - MyScansView

struct MyScansView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var openAIManager: OpenAIManager
    @EnvironmentObject var auth: AuthViewModel

    @State private var scans: [BottleScan] = []
    @State private var page = 0
    @State private var totalCount = 0
    @State private var isLoading = false

    private let pageSize = 6
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var totalPages: Int {
        max(1, Int(ceil(Double(totalCount) / Double(pageSize))))
    }

    private var hasNextPage: Bool {
        auth.hasActiveSubscription && (page + 1) < totalPages
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F5EDE7").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        if !auth.hasActiveSubscription {
                            upgradeBanner
                                .padding(.horizontal, 24)
                                .padding(.top, 28)
                        }

                        if scans.isEmpty && !isLoading {
                            emptyState.padding(.top, 40)
                        } else {
                            sectionLabel("WINES SCANNED")
                                .padding(.horizontal, 24)
                                .padding(.top, 28)
                                .padding(.bottom, 5)

                            grid
                                .padding(.horizontal, 24)
                                .padding(.top, 12)

                            if auth.hasActiveSubscription && (hasNextPage || page > 0) {
                                pagingControls.padding(.top, 30)
                            }
                        }

                        Spacer().frame(height: 100)
                    }
                }
            }
            .navigationTitle("My Wines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { upgradeToolbar }
            .overlay {
                if isLoading && scans.isEmpty { ProgressView() }
            }
            .navigationDestination(for: NSManagedObjectID.self) { scanID in
                let _ = print("🔵 NAV DESTINATION received scanID: \(scanID)")
                WineDetailLoader(
                    scanID: scanID,
                    openAIManager: openAIManager,
                    ctx: ctx
                )
                .id(scanID)
            }
            .task { await loadPage(reset: true) }

            .onChange(of: auth.hasActiveSubscription) { _, _ in
                Task { await loadPage(reset: true) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadPage(reset: false) }
                }
            }
        }
    }

    // MARK: - Subviews

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(scans, id: \.objectID) { scan in
                let wine = decodeWine(scan)
                let _ = print("🟢 GRID card: \(wine?.producer ?? "?") → objectID: \(scan.objectID)")

                NavigationLink(value: scan.objectID) {
                    MyScansCard(scan: scan, wine: wine)
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
    }

    @ToolbarContentBuilder
    private var upgradeToolbar: some ToolbarContent {
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

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .kerning(1.2)
                .foregroundColor(Color(hex: "#C07A5C").opacity(0.95))
            Spacer()
        }
    }

    private var upgradeBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Unlock your full scan history")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Free plan shows 6 most recent wines")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button {
                auth.isPaywallPresented = true
            } label: {
                Text("Go Pro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#C07A5C"), Color(hex: "#9E5A42")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.burgundy.opacity(0.5))
            VStack(spacing: 4) {
                Text("No wines scanned yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.burgundy)
                Text("Start by scanning your first bottle")
                    .font(.system(size: 12))
                    .foregroundColor(.burgundy.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .background(Color.burgundy.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 24)
    }

    private var pagingControls: some View {
        HStack(spacing: 18) {
            pageButton(systemName: "chevron.left", disabled: page == 0) {
                Task { await loadPage(reset: false, newPage: page - 1) }
            }

            Text("Page \(page + 1) of \(totalPages)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#C07A5C").opacity(0.9))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(hex: "#C07A5C").opacity(0.08))
                .clipShape(Capsule())

            pageButton(systemName: "chevron.right", disabled: !hasNextPage) {
                Task { await loadPage(reset: false, newPage: page + 1) }
            }
        }
    }

    private func pageButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.burgundy)
                .frame(width: 44, height: 44)
                .background(Color.burgundy.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(disabled || isLoading)
        .opacity(disabled ? 0.35 : 1)
    }

    // MARK: - Data

    @MainActor
    private func loadPage(reset: Bool, newPage: Int? = nil) async {
        guard !isLoading else { return }

        // Refault previous scans so Core Data drops their blobs
        for old in scans {
            ctx.refresh(old, mergeChanges: false)
        }

        isLoading = true
        defer { isLoading = false }

        let isPro = auth.hasActiveSubscription
        if reset || !isPro {
            page = 0
        } else if let newPage {
            page = max(0, newPage)
        }

        let countReq: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        totalCount = (try? ctx.count(for: countReq)) ?? 0

        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        req.sortDescriptors = [
            NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \BottleScan.id, ascending: false)
        ]
        req.fetchLimit = pageSize
        req.fetchOffset = isPro ? page * pageSize : 0

        scans = (try? ctx.fetch(req)) ?? []
    }

    @MainActor
    private func delete(_ scan: BottleScan) {
        ctx.delete(scan)
        try? ctx.save()
        Task {
            await loadPage(reset: false)
            if scans.isEmpty && page > 0 {
                await loadPage(reset: false, newPage: page - 1)
            }
        }
    }

    private func decodeWine(_ scan: BottleScan) -> WineData? {
        guard let raw = scan.rawJSON,
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WineData.self, from: data)
    }
}

// MARK: - Card

private struct MyScansCard: View {
    let scan: BottleScan
    let wine: WineData?

    @State private var thumbnail: UIImage?
    @State private var isLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.burgundy.opacity(0.06)

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .opacity(isLoaded ? 1 : 0)
                        .animation(.easeIn(duration: 0.35), value: isLoaded)
                }
            }
            .frame(height: 120)
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(wine?.producer ?? "Unknown")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.burgundy)
                    .lineLimit(1)

                Text([wine?.vintage, wine?.region]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundColor(.burgundy.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .background(Color(hex: "#FFFBF8"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())  // ← constrains hit target to visible bounds
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.burgundy.opacity(0.06), lineWidth: 0.5)
        )
        .task(id: scan.objectID) {
            let key = scan.objectID.uriRepresentation().absoluteString

            if let hit = ThumbnailCache.get(key) {
                thumbnail = hit
                isLoaded = true
                return
            }

            guard let data = scan.screenshot else { return }
            let img = await ThumbnailCache.decode(data: data, key: key)

            if !Task.isCancelled {
                thumbnail = img
                withAnimation(.easeIn(duration: 0.25)) {
                    isLoaded = true
                }
            }
        }
    }
}

// MARK: - Detail loader (loads full-res only on tap)

private struct WineDetailLoader: View {
    let scanID: NSManagedObjectID
    let openAIManager: OpenAIManager
    let ctx: NSManagedObjectContext

    @State private var snapshot: UIImage?
    @State private var scan: BottleScan?
    @State private var wineData: WineData?

    var body: some View {
        Group {
            if let scan, let snapshot, let wineData {
                WineDetailView(
                    bottle: scan,
                    wineData: wineData,
                    snapshot: snapshot,
                    openAIManager: openAIManager,
                    ctx: ctx
                )
                .id(scanID)
            } else {
                ProgressView()
                    .task(id: scanID) {
                        print("🟡 LOADER fetching scanID: \(scanID)")
                        guard let obj = try? ctx.existingObject(with: scanID) as? BottleScan else {
                            print("🔴 LOADER failed to fetch object for scanID: \(scanID)")
                            return
                        }
                        scan = obj

                        if let data = obj.screenshot {
                            snapshot = UIImage(data: data)
                        }

                        if let raw = obj.rawJSON,
                           let data = raw.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode(WineData.self, from: data) {
                            wineData = decoded
                            print("🟡 LOADER decoded: \(decoded.producer ?? "?") for scanID: \(scanID)")
                        } else {
                            print("🔴 LOADER failed to decode wineData for scanID: \(scanID)")
                        }
                    }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
private func makePreviewContext(wineCount: Int) -> NSManagedObjectContext {
    let ctx = PersistenceController.preview.container.viewContext

    let wines: [(String, String, String, String)] = [
        ("Château Margaux", "2018", "Margaux", "France"),
        ("Opus One",        "2019", "Napa Valley", "USA"),
        ("Barolo Riserva",  "2016", "Piedmont", "Italy"),
        ("Penfolds Grange", "2017", "Barossa Valley", "Australia"),
        ("Sassicaia",       "2018", "Bolgheri", "Italy"),
        ("Cloudy Bay",      "2022", "Marlborough", "New Zealand"),
    ].prefix(wineCount).map { $0 }

    for (producer, vintage, region, country) in wines {
        let scan = BottleScan(context: ctx)
        scan.id = UUID()
        scan.timestamp = Date()

        let wine = WineData(
            producer: producer, region: region, country: country,
            subregion: nil, appellation: nil, grapes: ["Cabernet Sauvignon"],
            vintage: vintage, classification: nil,
            tastingNotes: "Rich and structured with layers of dark fruit.",
            pairings: ["Lamb", "Beef"], vibeTag: "Bold and contemplative",
            vineyard: nil, soilType: nil, climate: nil,
            drinkingWindow: "2024–2040", abv: "14.0%",
            winemakingStyle: nil, category: .red
        )

        if let json = try? JSONEncoder().encode(wine),
           let str = String(data: json, encoding: .utf8) {
            scan.rawJSON = str
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        scan.screenshot = renderer.image { ctx in
            UIColor.systemBrown.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }.jpegData(compressionQuality: 0.8)
    }

    try? ctx.save()
    return ctx
}

#Preview("With Scans") {
    MyScansView()
        .environment(\.managedObjectContext, makePreviewContext(wineCount: 6))
        .environmentObject(AuthViewModel())
        .environmentObject(OpenAIManager())
}

#Preview("Empty State") {
    MyScansView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthViewModel())
        .environmentObject(OpenAIManager())
}

#Preview("Free User") {
    MyScansView()
        .environment(\.managedObjectContext, makePreviewContext(wineCount: 3))
        .environmentObject(AuthViewModel())
        .environmentObject(OpenAIManager())
}
#endif
