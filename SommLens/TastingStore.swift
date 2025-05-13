//
//  TastingStore.swift
//  SommLens
//
//  Created by Logan Rausch on 5/11/25.
//

import SwiftUI

@MainActor
final class TastingStore: ObservableObject {
    @Published private(set) var sessions: [TastingSession] = []
    
    func add(_ session: TastingSession) {
        sessions.append(session)
    }
}
