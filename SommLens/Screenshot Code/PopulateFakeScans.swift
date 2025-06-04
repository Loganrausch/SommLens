//
//  PopulateFakeScans.swift
//  SommLens
//
//  Created by Logan Rausch on 6/2/25.
//

import SwiftUI
import CoreData
import UIKit

func forceInjectSanityCheckScans(context: NSManagedObjectContext) {
    let fakeWines: [String] = [
        """
        {
             "producer": "Château Lagrille",
             "region": "Haut-Rive",
             "country": "France",
             "grapes": ["Pinot Noir"],
             "vintage": "2020",
             "classification": "Grand Sélection",
             "tastingNotes": "Cherry, rose petal, forest floor.",
             "pairings": ["Duck breast", "Mushroom risotto"],
             "vibeTag": "Elegant & Earthy",
             "vineyard": "Clos des Ailes",
             "soilType": "Limestone",
             "climate": "Continental",
             "drinkingWindow": "2023–2029",
             "abv": "13.2",
             "winemakingStyle": "Neutral oak barrels",
             "category": "red"
           }
        """,
        """
        {
             "producer": "Vigneti Auriani",
             "region": "Colle Fiorito",
             "country": "Italy",
             "grapes": ["Sangiovese", "Colorino"],
             "vintage": "2019",
             "classification": "IGT",
             "tastingNotes": "Black cherry, dried herbs, cocoa.",
             "pairings": ["Lasagna", "Aged pecorino"],
             "vibeTag": "Bold & Warm",
             "vineyard": "Poggio della Notte",
             "soilType": "Clay and limestone",
             "climate": "Mediterranean",
             "drinkingWindow": "2023–2032",
             "abv": "14.0",
             "winemakingStyle": "Aged in barrique",
             "category": "red"
           }
        """,
        """
        {
          "producer": "Domaine Luneval",
          "region": "Burgundy",
          "country": "France",
          "grapes": ["Pinot Noir"],
          "vintage": "2022",
          "classification": "Appellation Contrôlée",
          "tastingNotes": "Aromatic layers of red cherry, crushed raspberry, dried rose petal, subtle baking spice, and a touch of forest floor.",
          "pairings": ["Duck confit", "Wild mushroom tart", "Roasted quail with thyme"],
          "vibeTag": "Graceful, earthy, and quietly seductive — a true expression of Burgundian finesse.",
          "vineyard": "Les Brumes",
          "soilType": "Chalky marl",
          "climate": "Cool continental",
          "drinkingWindow": "2024–2035",
          "abv": "12.5",
          "winemakingStyle": "Fermented in stainless steel, aged in seasoned oak for finesse",
          "category": "red"
        }
        """,
        """
        {
          "producer": "Viña Rocablanca",
          "region": "Altura del Sur",
          "country": "Argentina",
          "grapes": ["Malbec"],
          "vintage": "2021",
          "classification": "Reserva",
          "tastingNotes": "Plum, violet, mocha.",
          "pairings": ["Grilled steak", "Chimichurri"],
          "vibeTag": "Dark & Juicy",
          "vineyard": "Piedra del Sol",
          "soilType": "Alluvial gravel",
          "climate": "High-altitude desert",
          "drinkingWindow": "2023–2028",
          "abv": "14.5",
          "winemakingStyle": "French oak aging",
          "category": "red"
        }
        """,
        """
         {
              "producer": "Weingut Fernblick",
              "region": "Mosel",
              "country": "Germany",
              "grapes": ["Riesling"],
              "vintage": "2021",
              "classification": "Kabinett",
              "tastingNotes": "Peach, slate, honeysuckle.",
              "pairings": ["Spicy Thai", "Schnitzel"],
              "vibeTag": "Fresh & Aromatic",
              "vineyard": "Sonnenfeld",
              "soilType": "Slate",
              "climate": "Cool river valley",
              "drinkingWindow": "2023–2031",
              "abv": "10.5",
              "winemakingStyle": "Cold fermentation",
              "category": "white"
            }
        """
        
        
    ]
    
    for (index, json) in fakeWines.enumerated() {
        let scan = BottleScan(context: context)
        scan.id = UUID()
        scan.timestamp = Date()
        scan.rawJSON = json
        
        let imageName = "TESTWINE\(index + 1)"
        if let image = UIImage(named: imageName),
           let imageData = image.jpegData(compressionQuality: 0.8) {
            scan.screenshot = imageData
        } else {
            print("❌ Failed to load image named \(imageName)")
        }
        
        // ✅ Only mark scans 1, 4, 7, and 11 (indices 0, 3, 6, 10) as tasted
        if [5, 8, 11].contains(index) {
            let tasting = TastingSessionEntity(context: context)
            tasting.id = UUID()
            tasting.date = Date()
            tasting.bottle = scan
            // Optionally add dummy values like acidity, tannin, etc. here
        }
    }
}


func deleteAllScans(context: NSManagedObjectContext) {
    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BottleScan")
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
    _ = try? context.execute(deleteRequest)
    try? context.save()
}


func findFakeScan(named producer: String,
                  from scans: [BottleScan]) -> BottleScan? {
    for scan in scans {
        guard let data = scan.rawJSON else {
            print("❌ Missing rawJSON")
            continue
        }

        guard let wine = try? JSONDecoder().decode(WineData.self, from: Data(data.utf8)) else {
            print("❌ JSON decode failed for scan:", data)
            continue
        }

        if wine.producer == producer {
            print("✅ Found scan for:", producer)
            return scan
        }
    }

    print("❌ No scan matched producer:", producer)
    return nil
}

struct DebugFailView: View {
    let message: String
    init(_ msg: String) { self.message = msg }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Text(message)
                .foregroundColor(.red)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
