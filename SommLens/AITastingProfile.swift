//
//  AITastingProfile.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct AITastingProfile: Codable {
    var acidity:   Intensity5
    var alcohol:   Intensity5
    var tannin:    Intensity5
    var body:      BodyLevel
    var sweetness: SweetnessLevel
    var aromas:    [String]
    var flavors:   [String]
    var tips:      [String]
    let hasTannin: Bool
}
