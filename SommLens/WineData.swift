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
    let grapes: [String]?
    let vintage: String?            // always a String in your model
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

    enum CodingKeys: String, CodingKey {
        case producer, region, country, grapes, vintage,
             classification, tastingNotes, pairings, vibeTag,
             vineyard, soilType, climate, drinkingWindow, abv, winemakingStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        producer       = try container.decodeIfPresent(String.self,   forKey: .producer)
        region         = try container.decodeIfPresent(String.self,   forKey: .region)
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
        abv              = try container.decodeIfPresent(String.self,   forKey: .abv)
        winemakingStyle  = try container.decodeIfPresent(String.self,   forKey: .winemakingStyle)
    }
}

extension WineData: Identifiable {
    public var id: String {
        // you can combine fields if you like, but producer+timestamp is unique enough here
        [producer, region, country, vintage]
            .compactMap { $0 }
            .joined(separator: "-")
    }
}

// reuse your existing Vinobytes response structs
struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
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
