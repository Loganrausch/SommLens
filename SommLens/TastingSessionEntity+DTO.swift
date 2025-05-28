//
//  TastingSessionEntity+DTO.swift
//  SommLens
//
//  Created by Logan Rausch on 5/23/25.
//

import CoreData

// MARK: – DTO bridge
extension TastingSessionEntity {

    // ⇢ Convert Core-Data row -> Swift struct
    var dto: TastingSession {
        TastingSession(
            id: id ?? UUID(),
            wineID: bottle?.id?.uuidString ?? "",
            wineName: bottle?.producer ?? "",
            grape: decodedInput.aromas.first ?? "",
            region: bottle?.region ?? "",
            vintage: bottle?.vintage,
            userInput: decodedInput,
            aiProfile: decodedAI,
            date: date ?? .distantPast          // fallback if still optional
        )
    }

    // ⇢ Create / update Core-Data row from Swift struct
    convenience init(from dto: TastingSession,
                     bottle: BottleScan,
                     context: NSManagedObjectContext) throws {
        self.init(context: context)
        id            = dto.id
        date          = dto.date
        userInputData = try JSONEncoder().encode(dto.userInput) as NSData
        aiProfileData = try JSONEncoder().encode(dto.aiProfile) as NSData
        self.bottle   = bottle
    }

    // ---------- private helpers ----------
    private var decodedInput: TastingInput {
        guard let data = userInputData as? Data else { return .init() }
        return (try? JSONDecoder().decode(TastingInput.self, from: data)) ?? .init()
    }

    private var decodedAI: AITastingProfile {
        guard let data = aiProfileData as? Data else {
            // minimal fallback so UI never crashes
            return AITastingProfile(acidity: .unknown,
                                    alcohol: .unknown,
                                    tannin: .unknown,
                                    body: .unknown,
                                    sweetness: .unknown,
                                    aromas: [],
                                    flavors: [],
                                    tips: [],
                                    hasTannin: false)
        }
        return (try? JSONDecoder().decode(AITastingProfile.self, from: data)) ??
               AITastingProfile(acidity: .unknown,
                                alcohol: .unknown,
                                tannin: .unknown,
                                body: .unknown,
                                sweetness: .unknown,
                                aromas: [],
                                flavors: [],
                                tips: [],
                                hasTannin: false)
    }
}

// MARK: – Bottle convenience
extension BottleScan {
    /// Sorted newest-first
    var tastingsArray: [TastingSessionEntity] {
        (tastings as? Set<TastingSessionEntity> ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}
