//
//  ScanResultViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI
import CoreData

@MainActor
final class ScanResultViewModel: ObservableObject {
    @Published var showDetailSheet = false
    @Published var showTasteSheet  = false
    @Published var aiProfile: AITastingProfile?
    @Published var isLoadingTaste  = false
    
    let openAIManager: OpenAIManager
    let ctx: NSManagedObjectContext
    let bottle: BottleScan
    let capturedImage: UIImage
    let wineData:      WineData
    
    init(ctx: NSManagedObjectContext, openAIManager: OpenAIManager, wineData: WineData, bottle: BottleScan, capturedImage: UIImage) {
        self.ctx = ctx
        self.openAIManager = openAIManager
        self.wineData = wineData
        self.bottle = bottle
        self.capturedImage = capturedImage
    }
    
    func loadAIProfileAndShowTasting() async {
        guard !isLoadingTaste else { return }
        isLoadingTaste = true
        defer { isLoadingTaste = false }
        
        do {
            let profile = try await openAIManager.tastingProfile(for: wineData)
            self.aiProfile     = profile
            self.showTasteSheet = true
        } catch {
            // TODO: replace with user‑visible alert / toast
            print("❌ AI fetch failed:", error.localizedDescription)
        }
    }
    
    
    func persistTasting(_ dto: TastingSession) throws {
        // 1️⃣ create the tasting entity
        _ = try TastingSessionEntity(
            from: dto,
            bottle: bottle,       // ← uses stored property
            context: ctx
        )
        
        // 2️⃣ update the bottle metadata
        bottle.lastTasted = dto.date
        
        // 3️⃣ commit to Core Data
        if ctx.hasChanges {
            try ctx.save()
        }
    }
}
