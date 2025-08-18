//
//  TastingSessionEntity+DTO.swift
//  SommLens
//
//  Created by Logan Rausch on 5/23/25.
//

import CoreData

// MARK: – DTO bridge
extension TastingSessionEntity {

// MARK: – Core Data to Swift Struct
    
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

// MARK: – Swift Struct to Core Data
    
    // ⇢ Create / update Core-Data row from Swift struct
    convenience init(from dto: TastingSession,
                     bottle: BottleScan,
                     context: NSManagedObjectContext) throws {
        self.init(context: context)
        id            = dto.id
        date          = dto.date
        userInputData = try JSONEncoder().encode(dto.userInput) as NSData
        aiProfileData = try JSONEncoder().encode(dto.aiProfile) as NSData
        self.bottle   = bottle // attach to correct bottle
    }

    // ---------- private helpers ----------
    
    // MARK: – User Input Data JSON to usable TastingInput Struct
    
    private var decodedInput: UserTastingInput {
        guard let data = userInputData as? Data else { return .init() }
        return (try? JSONDecoder().decode(UserTastingInput.self, from: data)) ?? .init()
    }

    // MARK: – AI Profile Data JSON to usable AITastingProfile Struct
    
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


// MARK: – Sort bottles from newest first

extension BottleScan {
    /// Sorted newest-first
    var tastingsArray: [TastingSessionEntity] {
        (tastings as? Set<TastingSessionEntity> ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}
