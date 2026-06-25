//
//  WineData.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import Foundation


struct WineData: Codable {
    let producer: String?
    let region: String?
    let country: String?
    let subregion: String?
    let appellation: String?
    let grapes: [String]?
    let vintage: String?
    let classification: String?
    let tastingNotes: String?
    let pairings: [String]?
    let vibeTag: String?
    let vineyard: String?
    let soilType: String?
    let climate: String?
    let drinkingWindow: String?
    let abv: String?
    let winemakingStyle: String?
    let category: WineCategory

    enum CodingKeys: String, CodingKey {
        case producer, region, country, grapes, vintage,
             classification, tastingNotes, pairings, vibeTag, subregion, appellation,
             vineyard, soilType, climate, drinkingWindow, abv, winemakingStyle, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        producer       = try container.decodeIfPresent(String.self,   forKey: .producer)
        region         = try container.decodeIfPresent(String.self,   forKey: .region)
        subregion      = try container.decodeIfPresent(String.self,   forKey: .subregion)
        appellation    = try container.decodeIfPresent(String.self,   forKey: .appellation)
        country        = try container.decodeIfPresent(String.self,   forKey: .country)
        grapes         = try container.decodeIfPresent([String].self, forKey: .grapes)

        // ——— Flexible vintage decoding ———
        if let yearInt = try? container.decode(Int.self, forKey: .vintage) {
            vintage = String(yearInt)
        } else {
            vintage = try container.decodeIfPresent(String.self, forKey: .vintage)
        }

        classification   = try container.decodeIfPresent(String.self,   forKey: .classification)
        tastingNotes     = try container.decodeIfPresent(String.self,   forKey: .tastingNotes)
        pairings         = try container.decodeIfPresent([String].self, forKey: .pairings)
        vibeTag          = try container.decodeIfPresent(String.self,   forKey: .vibeTag)
        vineyard         = try container.decodeIfPresent(String.self,   forKey: .vineyard)
        soilType         = try container.decodeIfPresent(String.self,   forKey: .soilType)
        climate          = try container.decodeIfPresent(String.self,   forKey: .climate)
        drinkingWindow   = try container.decodeIfPresent(String.self,   forKey: .drinkingWindow)
       
        // NEW  – accept either "13.5" **or** 13.5
        if let abvStr = try? container.decode(String.self, forKey: .abv) {
            abv = abvStr
        } else if let abvDouble = try? container.decode(Double.self, forKey: .abv) {
            // format: 13   → "13",   13.5 → "13.5"
            abv = String(format: abvDouble == floor(abvDouble) ? "%.0f" : "%.1f", abvDouble)
        } else {
            abv = nil
        }
        
        winemakingStyle  = try container.decodeIfPresent(String.self,   forKey: .winemakingStyle)
        category        = try container.decodeIfPresent(WineCategory.self, forKey: .category) ?? .unknown
    }
}

extension WineData {
    init(
        producer: String?,
        region: String?,
        country: String?,
        subregion: String?,
        appellation: String?,
        grapes: [String]?,
        vintage: String?,
        classification: String?,
        tastingNotes: String?,
        pairings: [String]?,
        vibeTag: String?,
        vineyard: String?,
        soilType: String?,
        climate: String?,
        drinkingWindow: String?,
        abv: String?,
        winemakingStyle: String?,
        category: WineCategory
    ) {
        self.producer = producer
        self.region = region
        self.country = country
        self.subregion = subregion
        self.appellation = appellation
        self.grapes = grapes
        self.vintage = vintage
        self.classification = classification
        self.tastingNotes = tastingNotes
        self.pairings = pairings
        self.vibeTag = vibeTag
        self.vineyard = vineyard
        self.soilType = soilType
        self.climate = climate
        self.drinkingWindow = drinkingWindow
        self.abv = abv
        self.winemakingStyle = winemakingStyle
        self.category = category
    }
}

extension WineData: Identifiable {
    public var id: String {
        // can combine fields, but producer+timestamp is unique enough here
        [producer, region, country, vintage]
            .compactMap { $0 }
            .joined(separator: "-")
    }
}

extension WineData {
    /// Something like “Produttori del Barbaresco 2019”
    var displayName: String {
        var parts: [String] = []
        if let producer = producer { parts.append(producer) }
        if let vintage  = vintage  { parts.append(vintage) }
        return parts.isEmpty ? "Unknown Wine" : parts.joined(separator: " ")
    }
}

// ──────────────────────────────────────────────────────────────
// MARK: – WineCategory  (explicit – 10 cases + fallback)
// ──────────────────────────────────────────────────────────────
enum WineCategory: String, Codable, CaseIterable {
    // still
    case red, white, rosé = "rose", orange        // “rosé” normalises to “rose”
    // sparkling
    case redSparkling     = "red sparkling"
    case whiteSparkling   = "white sparkling"
    // dessert
    case redDessert       = "red dessert"
    case whiteDessert     = "white dessert"
    // fortified
    case redFortified     = "red fortified"
    case whiteFortified   = "white fortified"
    // fallback
    case unknown
}

// ---------- Custom decoder (robust normalisation) -------------
extension WineCategory {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)

        // strip whitespace, accents, case, and trailing “wine”
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current) // rosé → rose
            .lowercased()
            .replacingOccurrences(of: #"\s*wine\s*$"#,
                                  with: "",
                                  options: .regularExpression)

        self = WineCategory(rawValue: cleaned) ?? .unknown
    }

    /// Readable label for UI sheets
    var displayName: String {
        switch self {
        case .unknown:      return "Unknown"
        case .rosé:         return "Rosé Wine"      // restore accent for display
        default:            return rawValue.capitalized + " Wine"
        }
    }
}
