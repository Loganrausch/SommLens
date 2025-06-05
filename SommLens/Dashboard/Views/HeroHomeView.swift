//
//  HeroHomeView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import SwiftUI

struct HeroHomeView: View {
    @Binding var selectedTab: MainTab
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var showOverlay = false
    @State private var showLearnMore = false
    @State private var pulse = false
    @State private var showDash = false

    var body: some View {
        ZStack {
            // ── Burgundy gradient background ──
            LinearGradient(
                gradient: Gradient(colors: [Color("Burgundy").opacity(0.93),
                                            Color("Burgundy").opacity(0.97),
                                            Color("Burgundy")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                Text("SommLens")
                    .font(.title.bold())
                    .foregroundColor(Color("Latte"))
                    .padding(.top, 50)
                
              
                Spacer()
                
                Button {
                    selectedTab = .scan
                } label: {
                    Text("Scan\nBottle")
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color("Burgundy"))
                        .frame(width: 220)
                        .padding(.vertical, 120)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color("Latte").opacity(0.8),
                                                Color("Latte").opacity(0.7)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                                .init(color: Color.clear, location: 0.5)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color.white.opacity(0.9), lineWidth: 6)
                                    .blur(radius: 5)
                                    .offset(x: -4, y: -4)
                                
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color.black.opacity(0.38), lineWidth: 6)
                                    .blur(radius: 5)
                                    .offset(x: 3, y: 3)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 32)
                                            .fill(Color.black)
                                    )
                            }
                        )
                        .cornerRadius(32)
                }
                .scaleEffect(pulse ? 1.05 : 1)
                .shadow(color: .black.opacity(pulse ? 0.4 : 0.15), radius: pulse ? 20 : 8, y: 6)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                
                Spacer()
                
                Button {
                    showDash = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.body.weight(.semibold))
                        Text("View Dashboard")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(Color("Burgundy"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color("Latte").opacity(0.95))
                            .shadow(radius: 4, y: 2)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color("Burgundy"), lineWidth: 2)
                    )
                }
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Group {
                if showOverlay {
                    UnifiedOnboardingOverlayView(isVisible: $showOverlay)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        .onAppear {
            pulse = true
            if !hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        showOverlay = true
                    }
                }
            }
        }
        .sheet(isPresented: $showDash) {
            DashboardView(selectedTab: $selectedTab)
                .presentationDetents([.height(700)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showOverlay) { newValue in
                   if !newValue {
                       hasSeenOnboarding = true
                   }
               }
        .onReceive(NotificationCenter.default.publisher(for: .didResetOnboarding)) { _ in
            hasSeenOnboarding = false
            withAnimation {
                showOverlay = true
            }
        }
    }
}

extension Notification.Name {
    static let didResetOnboarding = Notification.Name("didResetOnboarding")
}
