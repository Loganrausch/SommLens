//
//  SommLensApp.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import SwiftUI
import CoreData          // keep if you still use PersistenceController

@main
struct SommLensApp: App {
    
    // 1) Managers
    @StateObject private var openAIManager = OpenAIManager()
    
    // 2) Existing CoreData stack (if you still need it elsewhere)
    let persistenceController = PersistenceController.shared
    
    // 3) App appearance setup
    init() {
        configureNavigationBar()
        setupTabBarAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // CoreData context (only if your other views need it)
                .environment(\.managedObjectContext,
                              persistenceController.container.viewContext)
                .preferredColorScheme(.light)
                
                // Inject both managers for child views
                .environmentObject(openAIManager)
        }
    }
    
    // MARK: - UI appearance helpers
    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color("Latte"))
        appearance.titleTextAttributes      = [.foregroundColor: UIColor.burgundy]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.burgundy]
        
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        UIPageControl.appearance().currentPageIndicatorTintColor =
            UIColor(named: "Burgundy") ?? .red
        UIPageControl.appearance().pageIndicatorTintColor =
            UIColor(named: "Burgundy") ?? .gray
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Latte")
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
