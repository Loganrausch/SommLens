//
//  AuthViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 5/28/25.
//

import Foundation
import RevenueCat
import os
import SwiftUI

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

    /// ✅ What the rest of the app should use for gating.
    @Published var hasActiveSubscription: Bool    = false

    @Published var isPaywallPresented:    Bool    = false

    // MARK: - Private
    private let logger = Logger(subsystem: "com.sommlens.auth", category: "Auth")

    /// RevenueCat source-of-truth (never overridden)
    private var rcHasActiveSubscription: Bool = false

    // MARK: - DEBUG override (compiled out of Release)
    #if DEBUG
    enum DebugEntitlementOverride: Int, CaseIterable {
        case none = 0
        case forceFree = 1
        case forcePro = 2

        var label: String {
            switch self {
            case .none: return "Use RevenueCat"
            case .forceFree: return "Force Free"
            case .forcePro: return "Force Pro"
            }
        }
    }

    @AppStorage("debug_entitlement_override")
    private var debugOverrideRaw: Int = DebugEntitlementOverride.none.rawValue

    private var debugOverride: DebugEntitlementOverride {
        get { DebugEntitlementOverride(rawValue: debugOverrideRaw) ?? .none }
        set { debugOverrideRaw = newValue.rawValue }
    }
    #endif

    override init() {
        super.init()

        configureRevenueCat()
        Purchases.shared.delegate = self
        refreshCustomerInfo()
    }

    private func configureRevenueCat() {
        Purchases.configure(withAPIKey: RC.apiKey)
        Task { try? await Purchases.shared.syncPurchases() }
        logger.debug("RevenueCat configured")
    }

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

            self.rcHasActiveSubscription =
                info?.entitlements[RC.entitlementID]?.isActive ?? false

            self.applyEffectiveEntitlement()
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

            self.rcHasActiveSubscription =
                info?.entitlements[RC.entitlementID]?.isActive ?? false

            self.applyEffectiveEntitlement()
        }
    }

    private func applyEffectiveEntitlement() {
        #if DEBUG
        switch debugOverride {
        case .none:
            hasActiveSubscription = rcHasActiveSubscription
        case .forceFree:
            hasActiveSubscription = false
        case .forcePro:
            hasActiveSubscription = true
        }
        #else
        hasActiveSubscription = rcHasActiveSubscription
        #endif
    }

    #if DEBUG
    // MARK: - Debug helpers for UI
    func debugOverrideLabel() -> String {
        debugOverride.label
    }

    func setDebugOverride(_ value: DebugEntitlementOverride) {
        debugOverride = value
        applyEffectiveEntitlement()
    }

    func getDebugOverride() -> DebugEntitlementOverride {
        debugOverride
    }
    #endif
}

// MARK: - PurchasesDelegate
extension AuthViewModel: PurchasesDelegate {
    nonisolated func purchases(_ p: Purchases, receivedUpdated info: CustomerInfo) {
        Task { @MainActor in
            self.rcHasActiveSubscription =
                info.entitlements[RC.entitlementID]?.isActive ?? false
            self.applyEffectiveEntitlement()
        }
    }
}
