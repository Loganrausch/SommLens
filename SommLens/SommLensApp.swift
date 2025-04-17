//
//  SommLensApp.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI

@main
struct SommLensApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
