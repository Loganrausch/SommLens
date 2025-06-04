//
//  Persistence.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import CoreData
import CloudKit

struct PersistenceController {
    // MARK: – Shared instances
    static let shared  = PersistenceController()
    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    // MARK: – Core Data stack
    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // 1️⃣ Use CloudKit-aware container
        container = NSPersistentCloudKitContainer(name: "SommLens")

        // 2️⃣ Configure the store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("❌ Missing store description")
        }

        if inMemory {
            // In-memory store for previews / tests
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // --► Tell Core Data which CloudKit container to use
            let options = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.SommLens"
            )
            description.cloudKitContainerOptions = options
        }

        // 3️⃣ Load the store
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data error: \(error)") }
        }

        // 4️⃣ Merge background changes automatically
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
