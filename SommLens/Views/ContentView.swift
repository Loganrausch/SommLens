//
//  ContentView.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI
import CoreData

enum MainTab: Hashable {           // ① one enum for safety
    case home, scan, history
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home   // ② single source of truth

    var body: some View {
        TabView(selection: $selectedTab) {            // ③ bind TabView

            /* ── Home ── */
            NavigationStack {
                HomeView(selectedTab: $selectedTab)   // ④ inject binding
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(MainTab.home)

            /* ── Scan ── */
            NavigationStack {
                ARScanView()
            }
            .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
            .tag(MainTab.scan)

            /* ── History ── */
            NavigationStack {
                MyScansView()
            }
            .tabItem { Label("My Wines", systemImage: "wineglass") }
            .tag(MainTab.history)
        }
        .accentColor(Color("Burgundy"))
        .toolbarBackground(Color("Latte"), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 15 Pro") // Or any device you prefer
            .environment(\.colorScheme, .light) // Preview in light mode
    }
}
