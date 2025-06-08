//
//  WineDetailViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI
import CoreData

@MainActor
final class WineDetailViewModel: ObservableObject {
    @Published var animate = false
    @Published var selectedDTO: TastingSession? = nil
    @Published var showTasteSheet = false
    @Published var aiProfile: AITastingProfile? = nil
    @Published var isLoadingTaste = false
    
    private let openAIManager: OpenAIManager
    private let ctx: NSManagedObjectContext
    private let wineData: WineData
    
    init(openAIManager: OpenAIManager, ctx: NSManagedObjectContext, wineData: WineData) {
        self.openAIManager = openAIManager
        self.ctx = ctx
        self.wineData = wineData
    }
    
    func loadAIProfileAndShowTasting() async {
        guard !isLoadingTaste else { return }
        isLoadingTaste = true
        defer { isLoadingTaste = false }

        do {
            let profile = try await openAIManager.tastingProfile(for: wineData)
            self.aiProfile      = profile
            self.showTasteSheet = true
        } catch {
            // TODO: replace with user-visible alert / toast
            print("❌ AI fetch failed:", error.localizedDescription)
        }
    }
    
    func persistTasting(_ dto: TastingSession, for bottle: BottleScan) {
            do {
                _ = try TastingSessionEntity(from: dto, bottle: bottle, context: ctx)
                bottle.lastTasted = dto.date
                if ctx.hasChanges { try ctx.save() }
            } catch {
                print("❌ Failed to persist tasting:", error.localizedDescription)
            }
        }
    }
