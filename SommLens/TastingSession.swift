//
//  TastingSession.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

struct TastingSession: Identifiable, Codable {
    var id = UUID()
    // core wine metadata (adjust as you like)
    var wineID:     String          // barcode, label hash, etc.
    var wineName:   String
    var grape:      String
    var region:     String
    var vintage:    String?

    // user + AI
    var userInput:  TastingInput
    var aiProfile:  AITastingProfile

    var date:       Date = Date()
}
