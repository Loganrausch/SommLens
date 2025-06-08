//
//  ScanFilter.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import Foundation

enum ScanFilter: String, CaseIterable, Identifiable {
    case all, red, white, rosé, sparkling, orange
    var id: Self { self }
    var label: String { rawValue.capitalized }
    
    var matchingRawValues: [String] {
        switch self {
        case .all:
            return []
        case .red:
            return [WineCategory.red,
                    .redDessert,
                    .redFortified,
                    .redSparkling].map(\.rawValue)
        case .white:
            return [WineCategory.white,
                    .whiteDessert,
                    .whiteFortified].map(\.rawValue)
        case .rosé:
            return [WineCategory.rosé.rawValue]
        case .sparkling:
            return [WineCategory.whiteSparkling,
                    .redSparkling].map(\.rawValue)
        case .orange:
            return [WineCategory.orange.rawValue]
            
        }
    }
}
