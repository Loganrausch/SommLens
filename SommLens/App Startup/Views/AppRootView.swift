//
//  AppRootView.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var openAI: OpenAIManager

    @State private var readyForLaunch = false   // becomes true after prompt
    @State private var showLaunch = true

    var body: some View {
           ZStack {
               if !readyForLaunch {
                   // blank (or a tiny spinner) while waiting for the user’s choice
                   Color.latte.ignoresSafeArea()
               } else if showLaunch {
                   LaunchAnimationView()
                       .transition(.opacity)
               } else {
                   ContentView()
                       .transition(.opacity)
               }
           }
           // 1️⃣ listen for the post-prompt notification
           .onReceive(NotificationCenter.default.publisher(for: .pushPromptFinished)) { _ in
               readyForLaunch = true
               // 2️⃣ start 3.6-second timer once, then fade to main UI
               DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                   withAnimation(.easeInOut(duration: 0.4)) {
                       showLaunch = false
                   }
               }
           }
       }
   }
