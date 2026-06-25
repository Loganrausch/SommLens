//
//  AppRootView.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import SwiftUI

struct AppRootView: View {
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            if showLaunch {
                LaunchAnimationView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showLaunch = false
                }
            }
        }
    }
}
