//
//  ScanResult.swift
//  SommLens
//
//  Created by Logan Rausch on 8/6/25.
//

import SwiftUI

struct ScanResult: Identifiable, Hashable {
    let id       = UUID()
    let bottle:     BottleScan   // ← store the Core-Data row
    let image: UIImage
    let wineData: WineData

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func ==(a: ScanResult, b: ScanResult) -> Bool { a.id == b.id }
    
}
