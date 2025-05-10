//
//  SommLensApp.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI
import CoreData

@main
struct SommLensApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        configureNavigationBar()
        setupTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light) // 👈 This forces Light Mode across all views
        }
    }
    
    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Ensures the background is not transparent
        appearance.backgroundColor = UIColor(Color("Latte"))
        appearance.titleTextAttributes = [.foregroundColor: UIColor.burgundy]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.burgundy]
        
        // Apply the appearance to all navigation bar types
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(named: "Burgundy") ?? .red
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(named: "Burgundy") ?? .gray
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Latte")
        
        
        // Applying the appearance settings
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
