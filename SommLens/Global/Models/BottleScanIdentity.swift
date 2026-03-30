//
//  BottleScan+Identifiable.swift
//  SommLens
//
//  Created by Logan Rausch on 5/29/25.
//

import Foundation
import CoreData

extension BottleScan {
    /// Safe ID accessor for use in SwiftUI lists — avoids crash after deletions
    public var identity: UUID {
        id ?? UUID() // Just return a throwaway UUID if nil, don't assign it
    }
}

extension BottleScan {
    static func scansFetchRequest() -> NSFetchRequest<BottleScan> {
        let request: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BottleScan.timestamp, ascending: false)
        ]
        
        // 🔹 Key line: only load a chunk at a time
        request.fetchBatchSize = 25   // tweak (20, 50, etc.) if you like

        
        return request
    }
}
