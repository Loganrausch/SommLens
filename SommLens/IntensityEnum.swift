//
//  IntensityEnum.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

enum Intensity5: String, Codable, CaseIterable {
    case low, mediumMinus = "medium-", medium, mediumPlus = "medium+", high, unknown
    
    init(from decoder: Decoder) throws {
        self = Intensity5(rawValue:
            try decoder.singleValueContainer().decode(String.self).lowercased()
        ) ?? .unknown
    }
}

enum BodyLevel: String, Codable, CaseIterable {
    case light, mediumMinus = "medium-", medium, mediumPlus = "medium+", full, unknown
    init(from decoder: Decoder) throws {
        self = BodyLevel(rawValue:
            try decoder.singleValueContainer().decode(String.self).lowercased()
        ) ?? .unknown
    }
}

enum SweetnessLevel: String, Codable, CaseIterable {
    case boneDry = "bone-dry", dry, offDry = "off-dry", sweet, verySweet = "very sweet", unknown
    init(from decoder: Decoder) throws {
        self = SweetnessLevel(rawValue:
            try decoder.singleValueContainer().decode(String.self).lowercased()
        ) ?? .unknown
    }
}
