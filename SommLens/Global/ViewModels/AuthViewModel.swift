//
//  AuthViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 5/28/25.
//

// TODO: Refactor - Should move scan quota logic into a dedicated ScanQuotaManager.
// This logic probably doesn't belong in AuthViewModel, which should focus only on auth/subscription.
// A separate manager would improve modularity, testability, and single responsibility.


import Foundation
import SwiftUI
import RevenueCat
import os                       // Unified logging
import CoreData

// MARK: - RevenueCat Constants
enum RC {
    static let apiKey        = "appl_xjnJfyLnUmSUTrhLNxLwbZiPSRv"
    static let entitlementID = "SommLens_Pro"
}

@MainActor
final class AuthViewModel: NSObject, ObservableObject {

    // MARK: - Public, Published
    @Published var errorMessage:          String? = nil
    @Published var isLoading:             Bool    = true
    @Published var hasActiveSubscription: Bool    = false
    @Published var isPaywallPresented:    Bool    = false         // RC pay-wall trigger

    // MARK: - Quota Scan Limits
    private let proLimit  = 200 // MONTHLY
    private let freeLimit = 10  // LIFETIME
    
    // One key that never resets for free users
    private let freeScanKey = "freeScanCount"
    
    var   scanLimit: Int  { hasActiveSubscription ? proLimit : freeLimit }

    // MARK: - Private
    private let logger = Logger(subsystem: "com.sommlens.auth", category: "Auth")
   
    private static let iso = ISO8601DateFormatter()               // reuse

    override init() {
        super.init()

        configureRevenueCat()
        Purchases.shared.delegate = self

        // 2️⃣ RevenueCat may refine this (e.g. Pro renewal)
        refreshCustomerInfo()
    }

    private func configureRevenueCat() {
        let id = ScanQuotaKeychain.loadOrCreateAppUserID()          // ← NEW
        Purchases.configure(withAPIKey: RC.apiKey, appUserID: id)   // ← NEW

        Task { try? await Purchases.shared.syncPurchases() }        // ← NEW
        logger.debug("RevenueCat configured with ID \(id, privacy: .public)")
    }

    // MARK: - Customer status
    private func refreshCustomerInfo() {
        isLoading = true
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self else { return }
            defer { self.isLoading = false }

            if let error {
                self.logger.error("CustomerInfo error: \(error, privacy: .public)")
                self.errorMessage = "Unable to fetch subscription status."
                return
            }

            self.hasActiveSubscription = info?.entitlements[RC.entitlementID]?.isActive ?? false
        }
    }

    func restorePurchases() {
        isLoading = true
        Purchases.shared.restorePurchases { [weak self] info, error in
            guard let self else { return }
            defer { self.isLoading = false }

            if let error {
                self.logger.error("Restore failed: \(error, privacy: .public)")
                self.errorMessage = "Restore failed. Please try again."
                return
            }

            self.hasActiveSubscription = info?.entitlements[RC.entitlementID]?.isActive ?? false
        }
    }
    
    // MARK: - Quota Flow
    
    /// 1) Read current usage
    func getScanCount() -> Int {
           let key = hasActiveSubscription ? scanCountKey() : freeScanKey
           return ScanQuotaKeychain.loadCount(for: key) ?? 0
       }

    /// 2) Decide if the user can scan under the current limit
    func canScan(currentCount: Int) -> Bool {
        currentCount < scanLimit
    }
    
    /// 3) Commit usage after a successful scan
    func incrementScanCount() {
           let key = hasActiveSubscription ? scanCountKey() : freeScanKey
           let current = ScanQuotaKeychain.loadCount(for: key) ?? 0
           ScanQuotaKeychain.saveCount(current + 1, for: key)
       }
    
    /// Helper used only by Pro path (monthly bucket) - New bucket every month for reset.
    func scanCountKey(for date: Date = Date()) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return "scanCount_\(comps.year!)_\(comps.month!)"
    }
}

// MARK: - PurchasesDelegate

extension AuthViewModel: PurchasesDelegate {
    nonisolated func purchases(_ p: Purchases, receivedUpdated info: CustomerInfo) {
        Task { @MainActor in
            self.hasActiveSubscription = info.entitlements[RC.entitlementID]?.isActive ?? false
        }
    }
}

