//
//  TastingSession.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct TastingSession: Identifiable, Codable {
    var id = UUID()
    var wineID:     String
    var wineName:   String
    var grape:      String
    var region:     String
    var vintage:    String?

    // user + AI
    var userInput:  TastingInput
    var aiProfile:  AITastingProfile

    var date:       Date = Date()
}
