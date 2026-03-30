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
    // Existing
    @Published var animate = false
    @Published var showTasteSheet = false

    // Rating
    @Published var aiRating: AIRating?
    @Published var isLoadingRating = false
    @Published var showRatingSheet = false
    @Published var ratingError: String? = nil   // ← NEW

    // Dependencies
    private let openAIManager: OpenAIManager
    private let ctx: NSManagedObjectContext
    private let wineData: WineData
    private let bottle: BottleScan

    init(
        openAIManager: OpenAIManager,
        ctx: NSManagedObjectContext,
        wineData: WineData,
        bottle: BottleScan
    ) {
        self.openAIManager = openAIManager
        self.ctx           = ctx
        self.wineData      = wineData
        self.bottle        = bottle

        // Preload any stored rating so the chip shows instantly
        if let stored = bottle.toAIRating() {
            self.aiRating = stored
        }
    }


    // ---------- Rating ----------
    private func hasMinimumKeys(_ w: WineData) -> Bool {
        let hasProducer = !(w.producer?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        let hasAppOrCountry =
            !(w.appellation?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) ||
            !(w.country?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        return hasProducer && hasAppOrCountry
    }

    /// Core loader; can be used for preload (openSheet = false)
    /// or chip tap (openSheet = true).
    func fetchAIRatingIfNeeded(openSheet: Bool = false) async {
        // Already loading? Do nothing.
        if isLoadingRating { return }

        // Already have a rating?
        if let _ = aiRating {
            if openSheet { showRatingSheet = true }
            return
        }

        // If we really have nothing to work with, bail quietly.
        guard hasMinimumKeys(wineData) else { return }

        isLoadingRating = true
        ratingError     = nil
        defer { isLoadingRating = false }

        do {
            // You've already aligned/weighted inside assessWineRating,
            // so no need to call alignedToLocalMath() again here.
            let aligned = try await openAIManager.assessWineRating(from: wineData)

            self.aiRating = aligned
            try bottle.applyAIRating(from: aligned, ctx: ctx)

            if openSheet {
                showRatingSheet = true
            }

        } catch {
            print("❌ rating fetch failed:", error.localizedDescription)
            ratingError = "Unable to load rating right now. Please try again."
        }
    }
}


