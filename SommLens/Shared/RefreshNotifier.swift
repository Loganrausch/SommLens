//
//  RefreshNotifier.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import Combine

final class RefreshNotifier: ObservableObject {
    @Published var needsRefresh = false
}
