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
    @StateObject private var engagementState = EngagementState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    let persistenceController = PersistenceController.shared
    @StateObject private var auth = AuthViewModel()
    @StateObject private var openAIManager = OpenAIManager()
    @Environment(\.scenePhase) private var scenePhase
    
    
    // 3) App appearance setup
    init() {
        configureNavigationBar()
        setupTabBarAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light)
                .environmentObject(openAIManager)
                .environmentObject(auth)
                .environmentObject(engagementState)
                .onAppear {
                    EngagementPromptManager.engagementState = engagementState
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
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
