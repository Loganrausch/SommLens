//
//  BottleScan+Identifiable.swift
//  SommLens
//
//  Created by Logan Rausch on 5/29/25.
//

import Foundation

extension BottleScan {
    /// Safe ID accessor for use in SwiftUI lists — avoids crash after deletions
    public var identity: UUID {
        id ?? UUID() // Just return a throwaway UUID if nil, don't assign it
    }
}
