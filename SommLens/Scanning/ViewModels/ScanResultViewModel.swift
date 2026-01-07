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
    // MARK: - Sheet / UI state
    @Published var showDetailSheet = false

    // Rating
    @Published var aiRating: AIRating?
    @Published var isLoadingRating = false
    @Published var showRatingSheet = false

    // MARK: - Dependencies / data
    let openAIManager: OpenAIManager
    let ctx: NSManagedObjectContext
    let bottle: BottleScan
    let capturedImage: UIImage
    let wineData: WineData

    // MARK: - Init

    init(
        ctx: NSManagedObjectContext,
        openAIManager: OpenAIManager,
        wineData: WineData,
        bottle: BottleScan,
        capturedImage: UIImage
    ) {
        self.ctx           = ctx
        self.openAIManager = openAIManager
        self.wineData      = wineData
        self.bottle        = bottle
        self.capturedImage = capturedImage

        // If this particular BottleScan already has a rating, show it immediately.
        if let stored = bottle.toAIRating() {
            self.aiRating = stored
        }
    }
    // MARK: - Rating

    /// Look for any *other* BottleScan with the same fingerprint that already has a rating.
    private func existingRatingForCurrentWine() -> AIRating? {
        guard
            let fpRaw = bottle.fingerprint?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !fpRaw.isEmpty
        else {
            return nil
        }

        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        req.predicate = NSPredicate(
            format: "fingerprint == %@ AND aiScore > 0",
            fpRaw
        )
        req.fetchLimit = 1

        guard
            let match = try? ctx.fetch(req).first,
            let rating = match.toAIRating()
        else {
            return nil
        }

        return rating
    }

    /// Fetch an AI rating if we don't already have one.
    /// Reuses an existing rating for the same fingerprint when possible.
    func fetchAIRatingIfNeeded() async {
        // Already loading or already have a rating? Do nothing.
        guard aiRating == nil, !isLoadingRating else { return }

        // 1️⃣ Try to reuse any rating for this wine's fingerprint.
        if let cached = existingRatingForCurrentWine() {
            aiRating = cached
            do {
                try bottle.applyAIRating(from: cached, ctx: ctx)
            } catch {
                print("❌ failed to copy cached rating to this bottle:", error.localizedDescription)
            }
            return
        }

        // 2️⃣ Otherwise, call OpenAI for a fresh rating.
        isLoadingRating = true
        defer { isLoadingRating = false }

        do {
            // assessWineRating already returns an aligned / canonical AIRating
            let aligned = try await openAIManager.assessWineRating(from: wineData)

            self.aiRating = aligned
            try bottle.applyAIRating(from: aligned, ctx: ctx)
        } catch {
            print("❌ rating failed:", error.localizedDescription)
        }
    }
}
