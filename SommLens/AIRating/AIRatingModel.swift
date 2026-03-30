//
//  AIRating.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//

import Foundation

struct AIRating: Codable, Equatable {
    struct Factor: Codable, Equatable {
        let name: String        // e.g. "style match", "producer", "terroir", "craft"
        let score: Int          // 0–100
        let weight: Double      // 0.0–1.0 (∑ ≈ 1.0)
        let reason: String
    }

    let aiRating: Int // 0–100 overall (stored/internal); UI uses viniScore (0–10)
    let ratingExplanation: String
    let factors: [Factor]       // detailed breakdown
    let weightedTotal: Double?  // Σ(score * weight) before normalization
    let confidence: Double      // 0.0–1.0
}

extension AIRating {

    /// Recompute a weighted total, optionally overriding weights by factor name.
    func recomputedWeightedTotal(overridingWeights: [String: Double]? = nil) -> Double {
        // Apply override map if provided
        let effectiveFactors: [Factor] = {
            guard let map = overridingWeights, !map.isEmpty else { return factors }

            return factors.map { f in
                let keyLower = f.name.lowercased()
                let override = map[keyLower] ?? map[f.name]
                return Factor(
                    name:   f.name,
                    score:  f.score,
                    weight: override ?? f.weight,
                    reason: f.reason
                )
            }
        }()

        let sumW = effectiveFactors.reduce(0.0) { $0 + $1.weight }

        #if DEBUG
        print("📐 recomputedWeightedTotal()")
        print("   overridingWeights: \(overridingWeights ?? [:])")
        print("   effectiveFactors:")
        for f in effectiveFactors {
            let wStr = String(format: "%.4f", f.weight)
            print("   • \(f.name) | score=\(f.score) | weight=\(wStr)")
        }
        print("   sumW = \(sumW)")
        #endif

        guard sumW > 0 else {
            #if DEBUG
            print("   sumW == 0 → falling back to aiRating: \(aiRating)")
            #endif
            return Double(aiRating)
        }

        let raw = effectiveFactors.reduce(0.0) { partial, f in
            partial + (Double(f.score) * f.weight)
        }
        let normalized = raw / sumW
        let clamped = max(0, min(100, normalized))

        #if DEBUG
        print("   raw Σ(score*weight) = \(raw)")
        print("   normalized (raw / sumW) = \(normalized)")
        print("   clamped to [0,100] = \(clamped)")
        #endif

        return clamped
    }

    /// Return a copy whose aiRating & weightedTotal match our local math,
    /// and whose factors have any app-side weight overrides baked in.
    func alignedToLocalMath(overridingWeights: [String: Double]? = nil) -> AIRating {
        #if DEBUG
        print("🛠 alignedToLocalMath(overridingWeights: \(overridingWeights ?? [:]))")
        #endif

        let effectiveFactors: [Factor] = {
            guard let map = overridingWeights, !map.isEmpty else { return factors }

            return factors.map { f in
                let keyLower = f.name.lowercased()
                let override = map[keyLower] ?? map[f.name]
                return Factor(
                    name:   f.name,
                    score:  f.score,
                    weight: override ?? f.weight,
                    reason: f.reason
                )
            }
        }()

        let sumW = effectiveFactors.reduce(0.0) { $0 + $1.weight }

        let total: Double
        if sumW > 0 {
            let raw = effectiveFactors.reduce(0.0) { $0 + Double($1.score) * $1.weight }
            let normalized = raw / sumW
            total = max(0, min(100, normalized))

            #if DEBUG
            print("   effectiveFactors (after overrides):")
            for f in effectiveFactors {
                let wStr = String(format: "%.4f", f.weight)
                print("   • \(f.name) | score=\(f.score) | weight=\(wStr)")
            }
            print("   sumW = \(sumW)")
            print("   raw Σ(score*weight) = \(raw)")
            print("   normalized = \(normalized)")
            print("   total (clamped 0–100) = \(total)")
            #endif
        } else {
            total = Double(aiRating)

            #if DEBUG
            print("   sumW == 0 in alignedToLocalMath → using aiRating \(aiRating) as total")
            #endif
        }

        let rounded = Int(total.rounded())

        #if DEBUG
        print("   FINAL rounded aiRating = \(rounded)")
        #endif

        return AIRating(
            aiRating:          rounded,
            ratingExplanation: ratingExplanation,
            factors:           effectiveFactors,
            weightedTotal:     total,
            confidence:        confidence
        )
    }
}

extension AIRating {
    
    /// Internal 0–100 value we already compute/store.
       /// (Falls back safely if weightedTotal is missing.)
       var internalScore100: Double {
           let base = weightedTotal ?? Double(aiRating)   // 0–100
           return max(0, min(100, base))
       }

    var overallImpression: String {
        switch internalScore100 {
        case 0..<70:   return "Easy and Simple"
        case 70..<78:  return "Solid Go-To"
        case 78..<84:  return "Classic Style"
        case 84..<89:  return "Thoughtful and Distinct"
        case 89..<93:  return "Serious Wine"
        case 93..<96:  return "Standout Bottle"
        default:       return "Iconic Bottle"
        }
    }

       /// Optional: for factor chips if you ever want a short phrase
       var impressionShort: String {
           overallImpression
       }
    
    /// 0–10 score for overall UI, derived from the weighted math.
    var viniScore: Double {
        let base = weightedTotal ?? Double(aiRating)   // 0–100
        let clamped = max(0, min(100, base))
        let scaled = clamped / 10.0                    // now 0–10
        return (scaled * 10).rounded() / 10            // one decimal place
    }


    /// 0–10 score for each factor
    func tenPoint(for factor: Factor) -> Double {
        let scaled = Double(factor.score) / 10.0
        return (scaled * 10).rounded() / 10
    }
}
