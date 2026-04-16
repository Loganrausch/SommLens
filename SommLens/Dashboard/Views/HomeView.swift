//
//  HomeView.swift
//  SommLens
//
//  Created by Logan Rausch on 3/31/26.
//

// HomeView.swift
// Replaces HeroHomeView + DashboardView as a single unified home screen.
import SwiftUI
import CoreData
import UIKit

struct HomeView: View {
    
    // MARK: - Environment
    @EnvironmentObject private var openAIManager: OpenAIManager
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.managedObjectContext) private var ctx
    
    @Binding var selectedTab: MainTab
    
    // MARK: - Core Data
    @FetchRequest(
        fetchRequest: {
            let req = BottleScan.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)]
            req.fetchLimit = 5
            return req
        }(), animation: .default
    ) private var recentScans: FetchedResults<BottleScan>
    
    // MARK: - State
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("homeViewOpenCount") private var openCount = 0
    @AppStorage("lastScanPrompt")    private var lastScanPrompt = ""
    
    @State private var scanPrompt: String = ""
    @State private var showOverlay = false
    @State private var showingAccount = false
    
    @StateObject private var refreshNotifier = RefreshNotifier()
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Warm latte background
                Color(hex: "#F5EDE7")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        
                        topBar
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        
#if DEBUG
                        debugPicker
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
#endif
                        
                        scanHeroCard
                            .padding(.horizontal, 24)
                            .padding(.top, 28)
                        
                        statPills
                            .padding(.top, 26)
                        
                        recentScansSection
                            .padding(.top, 26)
                        
                        inspirationCard
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear(perform: updatePrompt)
        .onAppear(perform: checkOnboarding)
        .overlay {
            if showOverlay {
                UnifiedOnboardingOverlayView(isVisible: $showOverlay)
                    .transition(.opacity)
            }
        }
        .onChange(of: showOverlay) { _, newValue in
            if !newValue { hasSeenOnboarding = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didResetOnboarding)) { _ in
            hasSeenOnboarding = false
            withAnimation { showOverlay = true }
        }
        .sheet(isPresented: $showingAccount) {
            NavigationStack {
                AccountView(
                    refreshNotifier: refreshNotifier,
                    context: ctx
                )
                .environment(\.managedObjectContext, ctx)
            }
        }
    }
}

// MARK: - Subviews

private extension HomeView {
    
    // MARK: Top Bar
    
    var topBar: some View {
        HStack {
            Text("SommLens")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.burgundy)
            
            Spacer()
            
            if auth.hasActiveSubscription {
                Label {
                    Text("Pro")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.subheadline.bold())
                .foregroundColor(.latte)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Color.burgundy.opacity(0.85)) // instead of full solid
                .clipShape(Capsule())
            } else {
                Button {
                    auth.isPaywallPresented = true
                } label: {
                    Text("Upgrade")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.burgundy.opacity(0.85)) // instead of full solid
                        .clipShape(Capsule())
                }
            }
            
            Button {
                showingAccount = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3.bold())
                    .foregroundColor(.burgundy.opacity(0.85)) // instead of full solid)
            }
            .padding(.leading, 6)
        }
    }
    
    // MARK: Scan Hero Card
    
    var scanHeroCard: some View {
        Button {
            selectedTab = .scan
        } label: {
            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#C07A5C"),
                                Color(hex: "#B86E50"),
                                Color(hex: "#9E5A42")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 160, height: 160)
                    .offset(x: 110, y: -60)
                
                Circle()
                    .fill(Color.burgundy.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .offset(x: 80, y: 70)
                
                // Content — centered
                VStack(spacing: 10) {
                    Text("Your AI Sommelier")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.2)
                        .foregroundColor(.white.opacity(0.65))
                    
                    Text("Instantly understand\nevery bottle.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    
                  
                        HStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#c8816a"))
                            Text("Scan a Label")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                        .foregroundColor(Color(hex: "#c8816a"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 10)
                }
                .padding(28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: Stat Pills
    
    var statPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statPill(value: "\(totalScanCount)", label: "wines explored")
                statPill(value: "\(topRegionLabel) ↑", label: "trend")
                statPill(value: "\(scansThisWeek)", label: "scans this week")
            }
            .padding(.horizontal, 20)
        }
    }
    
    func statPill(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.burgundy)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.burgundy.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.burgundy.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: Recent Scans
    
    var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("WINES SCANNED")
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(1.2)
                    .foregroundColor(.burgundy.opacity(0.75))
                
                Spacer()
                
                Button {
                    selectedTab = .history
                } label: {
                    Text("See all →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.burgundy.opacity(0.75))
                }
            }
            .padding(.horizontal, 24)
            
            if recentScans.isEmpty {
                emptyState
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentScans.prefix(5), id: \.objectID) { scan in
                            let wine = decodeWine(scan)
                            let image = decodeImage(scan)
                            
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
                                    HomeScanCard(wine: wine, image: image, bottle: scan)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    var emptyState: some View {
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
        .background(Color.burgundy.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.burgundy.opacity(0.05), lineWidth: 0.5)
        )
        .onTapGesture {
            selectedTab = .scan
        }
    }
    
    // MARK: Inspiration
    
    var inspirationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // TITLE OUTSIDE
            Text("INSPIRATION")
                .font(.system(size: 12, weight: .semibold))
                .kerning(1.2)
                .foregroundColor(.burgundy.opacity(0.7))
                .padding(.bottom, 6)
            
            
            // CARD
            Text(scanPrompt.isEmpty
                 ? "Scan your first bottle to get personalized tips!"
                 : scanPrompt)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.burgundy.opacity(0.85))
            .lineSpacing(3)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.burgundy.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.burgundy.opacity(0.08), lineWidth: 0.5)
            )
            
        }
    }
    
    // MARK: Debug
    
#if DEBUG
    var debugPicker: some View {
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
    }
#endif
}

// MARK: - Scan Card for Home

private struct HomeScanCard: View {
    let wine: WineData
    let image: UIImage
    let bottle: BottleScan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 145, height: 105)
                    .clipped()
                
                
            }
            .frame(width: 145, height: 105)
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(wine.producer ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.burgundy)
                    .lineLimit(1)
                
                Text("\(wine.vintage ?? "–") · \(wine.region ?? "–")")
                    .font(.system(size: 11))
                    .foregroundColor(.burgundy.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 145)
        .background(Color(hex: "#FFFBF8"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.burgundy.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Helpers

private extension HomeView {
    
    func decodeWine(_ scan: BottleScan) -> WineData? {
        guard let raw = scan.rawJSON,
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WineData.self, from: data)
    }
    
    func decodeImage(_ scan: BottleScan) -> UIImage? {
        guard let data = scan.screenshot else { return nil }
        return UIImage(data: data)
    }
    
    func updatePrompt() {
        openCount += 1
        if openCount == 1 || openCount % 3 == 0 {
            let newPrompt = ScanPrompts.all.randomElement() ?? ""
            lastScanPrompt = newPrompt
            scanPrompt = newPrompt
        } else {
            scanPrompt = lastScanPrompt
        }
    }
    
    func checkOnboarding() {
        if !hasSeenOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { showOverlay = true }
            }
        }
    }
    
    /// Last 20 scans by timestamp — used for trends
    private var recentTwentyScans: [BottleScan] {
        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)]
        req.fetchLimit = 20
        return (try? ctx.fetch(req)) ?? []
    }
    
    // Computed stat helpers
    var totalScanCount: Int {
        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        return (try? ctx.count(for: req)) ?? 0
    }
    
    var scansThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }
        
        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        req.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp < %@",
            interval.start as NSDate,
            interval.end as NSDate
        )
        
        return (try? ctx.count(for: req)) ?? 0
    }
    
    var topRegionLabel: String {
        let regions = recentTwentyScans.compactMap { scan -> String? in
            guard let raw = scan.rawJSON,
                  let data = raw.data(using: .utf8),
                  let wine = try? JSONDecoder().decode(WineData.self, from: data)
            else { return nil }
            return wine.country
        }
        
        let counts = Dictionary(grouping: regions, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }
}

// MARK: - Notification (was in HeroHomeView)
extension Notification.Name {
    static let didResetOnboarding = Notification.Name("didResetOnboarding")
}



#if DEBUG

#Preview("With Scans") {
    let ctx = PersistenceController.preview.container.viewContext
    
    // Seed a few mock scans
    let wines: [(String, String, String, String)] = [
        ("Château Margaux", "2018", "Margaux", "France"),
        ("Opus One",        "2019", "Napa Valley", "USA"),
        ("Barolo Riserva",  "2016", "Piedmont", "Italy"),
    ]
    
    for (producer, vintage, region, country) in wines {
        let scan = BottleScan(context: ctx)
        scan.id = UUID()
        scan.timestamp = Date()
        
        let wine = WineData(
            producer:       producer,
            region:         region,
            country:        country,
            subregion:      nil,
            appellation:    nil,
            grapes:         ["Cabernet Sauvignon"],
            vintage:        vintage,
            classification: nil,
            tastingNotes:   "Rich and structured with layers of dark fruit.",
            pairings:       ["Lamb", "Beef"],
            vibeTag:        "Bold and contemplative",
            vineyard:       nil,
            soilType:       nil,
            climate:        nil,
            drinkingWindow: "2024–2040",
            abv:            "14.0%",
            winemakingStyle: nil,
            category:       .red
        )
        
        if let json = try? JSONEncoder().encode(wine),
           let str = String(data: json, encoding: .utf8) {
            scan.rawJSON = str
        }
        
        // Generate a simple color swatch as placeholder image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let img = renderer.image { ctx in
            UIColor.systemBrown.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        scan.screenshot = img.jpegData(compressionQuality: 0.8)
    }
    
    try? ctx.save()
    
    return HomeView(selectedTab: .constant(.home))
        .environment(\.managedObjectContext, ctx)
        .environmentObject(AuthViewModel())
        .environmentObject(OpenAIManager())
}

#Preview("Empty State") {
    let ctx = PersistenceController.preview.container.viewContext
    
    return HomeView(selectedTab: .constant(.home))
        .environment(\.managedObjectContext, ctx)
        .environmentObject(AuthViewModel())
        .environmentObject(OpenAIManager())
}

#endif
