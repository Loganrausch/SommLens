//
//  BottleScan+AIRating.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//

// BottleScan+AIRating.swift
import CoreData

private struct AIRatingBox: Codable {
    let factors: [AIRating.Factor]
    let weightedTotal: Double?
}

extension BottleScan {
    func applyAIRating(from rating: AIRating,
                       ctx: NSManagedObjectContext,
                       modelVersion: String = "rating-v1") throws {
        self.aiScore = Int16(rating.aiRating) // store underlying 0–100 score; UI shows overallImpression
        self.aiReason       = rating.ratingExplanation
        self.aiConfidence   = rating.confidence
        self.aiModelVersion = modelVersion

        let box = AIRatingBox(factors: rating.factors, weightedTotal: rating.weightedTotal)
        let data = try JSONEncoder().encode(box)
        self.aiBreakdownJSON = String(data: data, encoding: .utf8)

        if ctx.hasChanges { try ctx.save() }
    }

    func decodedBreakdown() -> (factors: [AIRating.Factor], weightedTotal: Double?)? {
        guard let s = aiBreakdownJSON, let d = s.data(using: .utf8) else { return nil }
        if let box = try? JSONDecoder().decode(AIRatingBox.self, from: d) {
            return (box.factors, box.weightedTotal)
        }
        return nil
    }
}

// Rebuild an AIRating from Core Data so the chip can show immediately
extension BottleScan {
    func toAIRating() -> AIRating? {
        guard aiScore > 0 else { return nil }
        let breakdown = decodedBreakdown()
        return AIRating(
            aiRating: Int(aiScore),
            ratingExplanation: aiReason ?? "",
            factors: breakdown?.factors ?? [],
            weightedTotal: breakdown?.weightedTotal,
            confidence: aiConfidence
        )
    }
}
