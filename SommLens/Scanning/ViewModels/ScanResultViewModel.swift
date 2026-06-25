//
//  ScanResultViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 6/5/25.
//

import SwiftUI
import CoreData

@MainActor
final class ScanResultViewModel: ObservableObject {
    // MARK: - Sheet / UI state
    @Published var showDetailSheet = false

    // MARK: - Dependencies / data
    let openAIManager: OpenAIManager
    let ctx: NSManagedObjectContext
    let bottle: BottleScan
    let capturedImage: UIImage
    let wineData: WineData

    // MARK: - Init

    init(
        ctx: NSManagedObjectContext,
        openAIManager: OpenAIManager,
        wineData: WineData,
        bottle: BottleScan,
        capturedImage: UIImage
    ) {
        self.ctx           = ctx
        self.openAIManager = openAIManager
        self.wineData      = wineData
        self.bottle        = bottle
        self.capturedImage = capturedImage
    }
}
