//
//  WineDetailView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//
// IMPROVED: Modern card-style layout using Latte + Burgundy palette

import SwiftUI
import CoreData

struct WineDetailView: View {
    
    @StateObject private var vm: WineDetailViewModel
    
    @ObservedObject var bottle: BottleScan
    let wineData: WineData
    let snapshot: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel
    
    
    @State private var showImageFullScreen = false
    
    init(
        bottle: BottleScan,
        wineData: WineData,
        snapshot: UIImage?,
        openAIManager: OpenAIManager,
        ctx: NSManagedObjectContext
    ) {
        self.bottle   = bottle
        self.wineData = wineData
        self.snapshot = snapshot
        
        self._vm = StateObject(
            wrappedValue: WineDetailViewModel(
                openAIManager: openAIManager,
                ctx: ctx,
                wineData: wineData,
                bottle: bottle
            )
        )
    }
    
    private var isPro: Bool { auth.hasActiveSubscription }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    
                    heroSection

                    // ── Main content
                    VStack(spacing: 22) {
                        
                        // 👇 FREE ONLY vibeTag
                        if !isPro,
                           let vibe = wineData.vibeTag?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !vibe.isEmpty {
                            
                            Text("\u{201C}\(vibe)\u{201D}")
                                .font(.custom("CormorantGaramond-SemiBold", size: 19.5))
                                .foregroundColor(.primary.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.top, 6)
                            
                            viniTakeCard
                        }
                        
                        if isPro {

                            if let notes = wineData.tastingNotes?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                               !notes.isEmpty {
                                Text("\u{201C}\(notes)\u{201D}")
                                    .font(.custom("CormorantGaramond-Medium", size: 19.5))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    
                            }
                            
                            viniTakeCard
                            
                            detailsSection
                            
                            pairingsSection
                            
                            terroirSection
                            
                            atAGlanceSection

                        } else {

                            VStack(alignment: .leading, spacing: 0) {
                                Text("Details")
                                    .font(.system(size: 12, weight: .medium))
                                    .kerning(1.5)
                                    .foregroundColor(.black.opacity(0.55))
                                    .foregroundColor(.secondary)


                                detailRow(label: "Subregion",   value: wineData.subregion)
                                detailRow(label: "Appellation", value: wineData.appellation)
                                detailRow(label: "Grapes",      value: wineData.grapes?.joined(separator: ", "))
                            }

                            lockedContentPreview
                        }
                        
                        // Footer
                        VStack(spacing: 4) {
                            Text("SommLens")
                                .font(.caption2)
                                .foregroundColor(.black.opacity(0.6))
                            Image("OpenAIBadge")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 24)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                }
            }
            
            // Close button
            Button {
                dismiss()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.burgundy)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.burgundy.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 4)
            }
            .padding()
        }
        
        .alert(
            "Impression unavailable",
            isPresented: Binding(
                get: { vm.ratingError != nil },
                set: { newValue in
                    if !newValue {
                        vm.ratingError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                vm.ratingError = nil
            }
        } message: {
            Text(vm.ratingError ?? "")
        }
        
        .fullScreenCover(isPresented: $vm.showRatingSheet) {
            if let r = vm.aiRating ?? bottle.toAIRating() {
                AIRatingSheet(
                    rating: r,
                    isUnlocked: auth.hasActiveSubscription,
                )
            }
        }
        
        // Full-screen zoomable image viewer (UIScrollView-backed)
        .fullScreenCover(isPresented: $showImageFullScreen) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                
                if let img = snapshot {
                    ZoomableScrollImage(image: img)
                        .ignoresSafeArea()
                }
                
                Button {
                    showImageFullScreen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding()
                }
            }
        }
        
        .onAppear {
            vm.animate = true
        }
        .task {
            // Preload rating but don't pop the sheet
            await vm.fetchAIRatingIfNeeded(openSheet: false)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Subsections

private extension WineDetailView {
    
    var heroSection: some View {
        Group {
            if let img = snapshot {
                Button {
                    showImageFullScreen = true
                } label: {
                    ZStack(alignment: .bottomLeading) {

                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 375)
                            .clipped()
                            .scaleEffect(vm.animate ? 1.0 : 0.97)
                            .opacity(vm.animate ? 1 : 0)
                            .animation(.easeOut(duration: 0.35), value: vm.animate)

                        LinearGradient(
                            stops: [
                                .init(color: .clear,               location: 0.35),
                                .init(color: .black.opacity(0.55), location: 0.7),
                                .init(color: .black.opacity(0.85), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 375)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(wineData.producer ?? "Unknown Producer")
                                .font(.title.weight(.bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let vintage = wineData.vintage?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                               !vintage.isEmpty {
                                Text("\(vintage) · \(wineData.region ?? "–"), \(wineData.country ?? "–")")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white.opacity(0.75))
                            } else {
                                Text("\(wineData.region ?? "–"), \(wineData.country ?? "–")")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white.opacity(0.75))
                            }

                            if !wineData.category.displayName.isEmpty {
                                Text(wineData.category.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .buttonStyle(.plain)

            } else {
                Color.clear.frame(height: 24)
            }
        }
    }
    
    var viniTakeCard: some View {
        let rating = vm.aiRating ?? bottle.toAIRating()

        return Button {
            guard !vm.isLoadingRating else { return }
            if rating != nil {
                vm.showRatingSheet = true
            } else {
                Task { await vm.fetchAIRatingIfNeeded(openSheet: true) }
            }
        } label: {
            HStack(spacing: 14) {

                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color.burgundy.opacity(0.3))
                        .frame(width: 38, height: 38)

                    Image(systemName: rating != nil ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#c8816a"))
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text("Vini's Take")
                        .font(.system(size: 11, weight: .medium))
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .foregroundColor(.white.opacity(0.8))

                    if vm.isLoadingRating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else if let impression = rating?.overallImpression {
                        Text(impression)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            
                        Text("Tap to see why")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            
                    } else {
                        Text("Tap to get Vini’s take")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(height: 40)

                Spacer()

                if !vm.isLoadingRating {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#c8816a"))
                }
            }
            .padding(.vertical, 25)
            .padding(.horizontal, 18)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
    
    
    var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Details")
                .font(.system(size: 12, weight: .semibold))
                   .kerning(1.2)
                   .textCase(.uppercase)
                   .foregroundColor(.black.opacity(0.55))
                   .padding(.bottom, 8)

            VStack(spacing: 0) {
                detailRow(label: "Subregion",      value: wineData.subregion)
                detailRow(label: "Appellation",    value: wineData.appellation)
                detailRow(label: "Vineyard",       value: wineData.vineyard)
                detailRow(label: "Grapes",         value: wineData.grapes?.joined(separator: ", "))
                detailRow(label: "Classification", value: wineData.classification)
            }
        }
    }

    // Single label/value row — no card, just a hairline separator
    private func detailRow(label: String, value: String?) -> some View {
        Group {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(label)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(value)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    Divider()
                }
            }
        }
    }

    var pairingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pair with")
                .font(.system(size: 12, weight: .semibold))
                   .kerning(1.2)
                   .textCase(.uppercase)
                   .foregroundColor(.black.opacity(0.55))
                   .padding(.bottom, 8)

            if let pairings = wineData.pairings, !pairings.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pairings, id: \.self) { pairing in
                            Text(pairing)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.latte.opacity(0.75))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.horizontal, -24)
            } else {
                Text("Not available for this bottle yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    var terroirSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terroir")
                .font(.system(size: 12, weight: .semibold))
                   .kerning(1.2)
                   .textCase(.uppercase)
                   .foregroundColor(.black.opacity(0.55))
                   .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 11) {
                if let climate = wineData.climate,
                   !climate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    terroirRow(label: "Climate", value: climate)
                }
                if let soil = wineData.soilType,
                   !soil.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    terroirRow(label: "Soil", value: soil)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.latte.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func terroirRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.burgundy.opacity(0.8))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    var atAGlanceSection: some View {
        let abv = wineData.abv?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            Text("At a glance")
                .font(.system(size: 12, weight: .semibold))
                   .kerning(1.2)
                   .textCase(.uppercase)
                   .foregroundColor(.black.opacity(0.55))
                   .padding(.bottom, 8)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                statTile(value: abv.isEmpty ? "See back label" : abv, label: "ABV")
                statTile(value: wineData.drinkingWindow ?? "—", label: "Drinking window")

                if let style = wineData.winemakingStyle,
                   !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    statTile(value: style, label: "Winemaking style")
                        .gridCellColumns(2)
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .kerning(0.5)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.latte.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private func proBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.burgundy.opacity(0.85))
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)
            
            Text(text)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension WineDetailView {
 
    /// Replaces `proUpsellCard` — shows blurred previews of pro sections

    var lockedContentPreview: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
 
                GhostSection {
                    VStack(spacing: 22) {
                        pairingsSection
                        terroirSection
                        atAGlanceSection
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.25),
                            .init(color: .clear, location: 0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
 
                upgradePrompt
                         .padding(.bottom, 8)
                         .background(
                             LinearGradient(
                                 colors: [
                                     Color(.systemBackground).opacity(0.0),
                                     Color(.systemBackground).opacity(0.85),
                                     Color(.systemBackground)
                                 ],
                                 startPoint: .top,
                                 endPoint: .bottom
                             )
                         )
                 }
             }
    }
 
    /// Compact upgrade prompt — matches detail view's visual language
    private var upgradePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#c8816a"))
 
            Text("Unlock the full picture")
                .font(.headline)
                .foregroundColor(.primary)
 
            Text("Expanded tasting notes, food pairings, climate, soil, and more.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
 
            Button {
                auth.isPaywallPresented = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundColor(Color(hex: "#c8816a"))
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                       
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 20)
    }
}


// MARK: - Preview

#Preview {
    let auth = AuthViewModel()
    // auth.hasActiveSubscription is whatever your default is
    
    return WineDetailView(
        bottle: PreviewBottleScan(),
        wineData: PreviewWineData(),
        snapshot: sampleImage(),
        openAIManager: OpenAIManager(),
        ctx: PersistenceController.preview.container.viewContext
    )
    .environmentObject(auth)
}

// ── Helpers ──────────────────────────────────────────────

private func sampleImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
    return renderer.image { ctx in
        UIColor.systemBrown.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
    }
}

private func PreviewWineData() -> WineData {
    WineData(
        producer:        "Château Margaux",
        region:          "Margaux",
        country:         "France",
        subregion:       "Left Bank",
        appellation:     "Margaux AOC",
        grapes:          ["Cab. Sauvignon", "Merlot", "Petit Verdot"],
        vintage:         "2018",
        classification:  "Premier Grand Cru Classé",
        tastingNotes:    "Layers of cassis and violet over a spine of iron and cedar — effortlessly precise, with a finish that lingers long past the last sip.",
        pairings:        ["Lamb rack", "Duck confit", "Aged cheddar", "Beef tenderloin", "Truffle dishes"],
        vibeTag:         "Structured and contemplative. A good wine with winey flav",
        vineyard:        "Château Margaux Estate",
        soilType:        "Deep gravel over clay and limestone",
        climate:         "Maritime — temperate with warm, dry summers",
        drinkingWindow:  "2026–2045",
        abv:             "14.0%",
        winemakingStyle: "Traditional — aged 18 mo. in French oak",
        category:        .red
    )
}

private func PreviewBottleScan() -> BottleScan {
    let ctx = PersistenceController.preview.container.viewContext
    let bottle = BottleScan(context: ctx)
    // set any required fields your BottleScan needs
    return bottle
}


