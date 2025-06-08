//
//  ResetService.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import CoreData

struct ResetService {
    private let ctx: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.ctx = context }

    /// Deletes every BottleScan record and returns the count removed.
    @discardableResult
    func deleteAllScans() throws -> Int {
        let req: NSFetchRequest<BottleScan> = BottleScan.fetchRequest()
        let items = try ctx.fetch(req)
        items.forEach(ctx.delete)
        try ctx.save()
        ctx.refreshAllObjects()          // flush caches
        return items.count
    }

    /// Deletes every TastingSessionEntity (if you’re persisting them) and returns the count.
    @discardableResult
    func deleteAllTastingSessions() throws -> Int {
        let req: NSFetchRequest<TastingSessionEntity> = TastingSessionEntity.fetchRequest()
        let items = try ctx.fetch(req)
        items.forEach(ctx.delete)
        try ctx.save()
        return items.count
    }
}
