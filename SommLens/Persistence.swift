//
//  Persistence.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    // ✅ Add this preview instance
       static var preview: PersistenceController = {
           let controller = PersistenceController(inMemory: true)

           // Optionally pre-populate data here if needed
           return controller
       }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SommLens")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { storeDesc, error in
            if let error = error {
                fatalError("Unresolved Core Data error \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
