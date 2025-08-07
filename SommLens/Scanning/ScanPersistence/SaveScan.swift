//
//  SaveScan.swift
//  SommLens
//
//  Created by Logan Rausch on 8/6/25.


import UIKit
import CoreData

func saveScan(in ctx: NSManagedObjectContext,
                      wineData: WineData,
                      rawJSON: String,
                      screenshot: UIImage?
) -> BottleScan {
    let scan = BottleScan(context: ctx)
    scan.id              = UUID()
    scan.fingerprint     = wineData.id
    scan.timestamp       = Date()
    scan.producer        = wineData.producer
    scan.region          = wineData.region
    scan.subregion       = wineData.subregion
    scan.appellation     = wineData.appellation
    scan.country         = wineData.country
    scan.grapes          = wineData.grapes?.joined(separator: ", ")
    scan.vintage         = wineData.vintage
    scan.classification  = wineData.classification
    scan.tastingNotes    = wineData.tastingNotes
    scan.pairings        = wineData.pairings?.joined(separator: ", ")
    scan.vibeTag         = wineData.vibeTag
    scan.vineyard        = wineData.vineyard
    scan.soilType        = wineData.soilType
    scan.climate         = wineData.climate
    scan.drinkingWindow  = wineData.drinkingWindow
    scan.abv             = wineData.abv
    scan.winemakingStyle = wineData.winemakingStyle
    scan.category        = wineData.category.rawValue
    scan.rawJSON         = rawJSON
    scan.screenshot      = screenshot?.jpegData(compressionQuality: 0.8)
    try? ctx.save()
    
    return scan
}

