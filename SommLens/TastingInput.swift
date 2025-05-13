//
//  TastingInput.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct TastingInput: Identifiable, Codable {
    var id = UUID()
    var acidity:  Intensity5      = .unknown
    var alcohol:  Intensity5      = .unknown
    var tannin:   Intensity5      = .unknown
    var body:     BodyLevel       = .unknown
    var sweetness:SweetnessLevel  = .unknown
    var flavors:  [String]        = []
    var notes:    String          = ""
}
