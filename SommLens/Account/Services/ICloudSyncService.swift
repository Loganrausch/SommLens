//
//  ICloudSyncService.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import Foundation
import CloudKit

// ICloudSyncService.swift
struct ICloudSyncService {
    private let container = CKContainer(identifier: "iCloud.com.SommLens") // <— update if needed
    
    func isICloudAvailable() async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            container.accountStatus { status, error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: status == .available) }
            }
        }
    }
}
