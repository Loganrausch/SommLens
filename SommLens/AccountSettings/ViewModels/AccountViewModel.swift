//
//  AccountViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import Foundation
import CoreData
import CloudKit
import StoreKit
import SwiftUI

@MainActor
final class AccountViewModel: ObservableObject {
    // MARK: – Published UI State
    @Published var showingShareSheet        = false
    @Published var showingFeedbackSheet     = false
    @Published var activeAlert: ActiveAlert?
    
    @Published var showingScansResetToast   = false
    @Published var isICloudAvailable        = false
    @Published var isCheckingICloud         = false
    @Published var showRateAlert            = false
    
    // MARK: – Dependencies
    private let context: NSManagedObjectContext
    private let refreshNotifier: RefreshNotifier
    private let iCloud: ICloudSyncService
    private let resetService: ResetService
    
    // MARK: – Init
    init(context: NSManagedObjectContext,
         refreshNotifier: RefreshNotifier,
         iCloudService: ICloudSyncService = .init(),
         resetService: ResetService? = nil) {
        self.context          = context
        self.refreshNotifier  = refreshNotifier
        self.iCloud           = iCloudService
        self.resetService     = resetService ?? ResetService(context: context)
    }
    
    // MARK: – Computed
    var appVersion: String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "Version \(v) (\(b))"
        }
        return "Version n/a"
    }
    
    // MARK: – Lifecycle
    func onAppear() {
        Task { await checkICloud(showAlert: false) }
    }
    
    // MARK: – Intents
    func inviteFriends() { showingShareSheet = true }
    func feedbackTapped() { showingFeedbackSheet = true }
    func rateAppTapped() { showRateAlert = true }
    
    func openAppStoreForRating() {
        let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id6746465776?action=write-review")!
        if UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL)
        } else {
            let fallbackURL = URL(string: "https://apps.apple.com/app/id6746465776?action=write-review")!
            UIApplication.shared.open(fallbackURL)
        }
    }
    
    // MARK: – iCloud
    func checkICloud(showAlert: Bool) async {
        isCheckingICloud = true
        do {
            let available = try await iCloud.isICloudAvailable()
            isICloudAvailable = available
            if showAlert {
                activeAlert = available ? .iCloudEnabled : .iCloudDisabled
            }
        } catch {
            isICloudAvailable = false
            if showAlert { activeAlert = .iCloudDisabled }
        }
        isCheckingICloud = false
    }
    
    // MARK: – Resets
    func deleteMyScans() {                       // keep or rename to resetMyScans()
        do {
            let deleted = try resetService.deleteAllScans()   // ← CHANGED
            print("Deleted \(deleted) scans")
            showingScansResetToast = true
            refreshNotifier.needsRefresh = true
        } catch {
            print("Reset error: \(error.localizedDescription)")
        }
    }
}
