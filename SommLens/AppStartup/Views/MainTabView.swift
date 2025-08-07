//
//  MainTabView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI
import CoreData
import RevenueCatUI

enum MainTab: Hashable {
    case home, scan, history
}

struct MainTabView: View {
    
    @EnvironmentObject var auth: AuthViewModel

    // 🔹 Tab tracking
    @State private var _selectedTab: MainTab = .home

    // 🔹 Scan-related state (lifted up from MainScanView)
    @State private var frozenImage: UIImage? = nil
    @State private var scanResult: ScanResult? = nil
    @State private var isProcessing: Bool = false
    @State private var showOverlay: Bool = false
    @State private var hasExtracted: Bool = false

    // 🔹 Computed binding that catches re-taps on .scan
    private var selectedTabBinding: Binding<MainTab> {
        Binding(
            get: { _selectedTab },
            set: { newTab in
                if newTab == .scan {
                    cleanupScanState()
                }
                _selectedTab = newTab
            }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            // ── Home Tab ──
            NavigationStack {
                HeroHomeView(selectedTab: selectedTabBinding)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(MainTab.home)

            // ── Scan Tab ──
            NavigationStack {
                MainScanView(
                    selectedTab: selectedTabBinding,
                    frozenImage: $frozenImage,
                    scanResult: $scanResult,
                    isProcessing: $isProcessing,
                    showOverlay: $showOverlay,
                    hasExtracted: $hasExtracted
                )
            }
            .tabItem {
                Label("Scan", systemImage: "camera.viewfinder")
            }
            .tag(MainTab.scan)

            // ── History Tab ──
            NavigationStack {
                MyScansView()
            }
            .tabItem {
                Label("My Wines", systemImage: "wineglass")
            }
            .tag(MainTab.history)
        }
        .accentColor(Color("Burgundy"))
        .toolbarBackground(Color("Latte"), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        
        // 📍 SINGLE place the paywall is presented
              .sheet(isPresented: $auth.isPaywallPresented) {
                  PaywallView()          // <- your RevenueCatUI view
              }
    }

    // 🔹 Resets scan state when Scan tab is tapped again
    private func cleanupScanState() {
        frozenImage = nil
        scanResult = nil
        isProcessing = false
        showOverlay = false
        hasExtracted = false
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .previewDevice("iPhone 15 Pro") // Or any device you prefer
            .environment(\.colorScheme, .light) // Preview in light mode
    }
}
