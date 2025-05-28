//
//  AccountView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import SwiftUI
import CoreData

struct AccountView: View {
    // MARK: – Dependencies
    @Environment(\.managedObjectContext) private var context
    @Environment(\.openURL)              private var openURL
    @ObservedObject                      var refreshNotifier: RefreshNotifier
    
    @StateObject private var viewModel: AccountViewModel
    
    // MARK: – Init
    init(refreshNotifier: RefreshNotifier,
         context: NSManagedObjectContext) {
        self.refreshNotifier = refreshNotifier
        _viewModel = StateObject(
            wrappedValue: AccountViewModel(
                context: context,
                refreshNotifier: refreshNotifier
            )
        )
    }
    
    // MARK: – Body
    var body: some View {
        VStack {
            formSection
            footer
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.onAppear() }
        // ── Toasts ───────────────────────────────────────────────
        .toast(message: "All Scans deleted!", isShowing: $viewModel.showingScansResetToast)
        // ── Sheets ──────────────────────────────────────────────
        .sheet(isPresented: $viewModel.showingFeedbackSheet) {
            ContactFormView().environment(\.colorScheme, .light)
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            ShareSheet(activityItems: [
                "SommLens makes learning wine effortless – download it here: <App Store URL>"
            ])
            .environment(\.colorScheme, .light)
        }
        // ── Alerts ──────────────────────────────────────────────
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .resetScans:
                return resetAlert(title: "Delete All Scans", action: viewModel.deleteMyScans)
            case .iCloudEnabled:
                return Alert(title: Text("iCloud Synced"),
                             message: Text("Your data is synchronized."),
                             dismissButton: .default(Text("OK")))
            case .iCloudDisabled:
                return Alert(title: Text("iCloud Disabled"),
                             message: Text("Enable iCloud in Settings."),
                             primaryButton: .default(Text("Settings"), action: openSettings),
                             secondaryButton: .cancel())
            }
        }
        // ── App-rating prompt ──────────────────────────────────
        .alert("Enjoying SommLens?",
               isPresented: $viewModel.showRateAlert) {
            Button("Rate Now", action: viewModel.openAppStoreForRating)
            Button("Later", role: .cancel) { }
        } message: {
            Text("Please take a moment to rate us on the App Store.")
        }
    }
    
    // MARK: – Sub-views
    private var formSection: some View {
        Form {
            generalSection
            accountSection
            legalSection
        }
        .accentColor(.black)
    }
    
    private var generalSection: some View {
        Section("General") {
            Button("Feedback",       action: viewModel.feedbackTapped)
            Button("Invite Friends", action: viewModel.inviteFriends)
            Button("Rate SommLens",  action: viewModel.rateAppTapped)
        }
    }
    
    private var accountSection: some View {
        Section("Account") {
            Button("Delete All Scans") { viewModel.activeAlert = .resetScans }
            Button {
                Task { await viewModel.checkICloud(showAlert: true) }
            } label: {
                HStack {
                    Text("iCloud Sync")
                    Spacer()
                    if viewModel.isCheckingICloud {
                        ProgressView()
                    } else if viewModel.isICloudAvailable {
                        Image(systemName: "checkmark.circle").foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle").foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var legalSection: some View {
        Section("Legal") {
            Button("Privacy Policy") {
                openURL(URL(string: "https://YOUR_PRIVACY_POLICY_URL")!)
            }
            Button("Terms and Conditions") {
                openURL(URL(string: "https://YOUR_TERMS_URL")!)
            }
        }
    }
    
    private var footer: some View {
        VStack(spacing: 4) {
            Text(viewModel.appVersion).font(.footnote).foregroundColor(.gray)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: – Helpers
    private func resetAlert(title: String, action: @escaping () -> Void) -> Alert {
        Alert(title: Text("Confirm Delete"),
              message: Text("Are you sure you want to \(title.lowercased())? This cannot be undone."),
              primaryButton: .destructive(Text("Delete"), action: action),
              secondaryButton: .cancel())
    }
    
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

