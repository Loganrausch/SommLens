//
//  OverlayOnboardingView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/29/25.
//

import SwiftUI

struct UnifiedOnboardingOverlayView: View {
    @Binding var isVisible: Bool
    
    @State private var showLearnMore = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 28) {
                if !showLearnMore {
                    // ── WELCOME CARD ──
                    VStack(spacing: 20) {
                        Text("Welcome to SommLens")
                            .font(.title.bold())
                            .foregroundColor(.latte)
                            .multilineTextAlignment(.center)

                        Text("Tap the Scan Bottle button to get expert-level wine insights using AI.")
                            .font(.body)
                            .foregroundColor(.latte.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            withAnimation {
                                isVisible = false
                            }
                        } label: {
                            Text("Got it")
                                .font(.headline)
                                .foregroundColor(.burgundy)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                                .shadow(radius: 3)
                        }

                        Button {
                            withAnimation {
                                showLearnMore = true
                            }
                        } label: {
                            Text("Learn how it works")
                                .font(.callout.weight(.semibold))
                                .underline()
                                .foregroundColor(.latte.opacity(0.85))
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                } else {
                    // ── LEARN MORE TUTORIAL ──
                    VStack(spacing: 32) {
                        
                        TabView(selection: $currentPage) {
                            learnCard(
                                title: "Scan Any Wine",
                                subtitle: "Just point your camera at a label and tap the shutter. SommLens instantly reads the bottle and returns expert-level insights using AI.",
                                systemImage: "viewfinder"
                            )
                            .tag(0)

                            learnCard(
                                title: "Taste With Vini AI",
                                subtitle: "After scanning a label, explore a guided tasting. Record your impressions, then reveal Vini’s notes to compare — perfect for beginners and pros alike.",
                                systemImage: "wineglass"
                            )
                            .tag(1)

                            learnCard(
                                title: "All Scans Saved",
                                subtitle: "Every scan and tasting builds your profile. Track the wines you love—and the ones you don’t.",
                                systemImage: "heart.text.square"
                            )
                            .tag(2)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .frame(height: 420)
                        .onAppear {
                            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(named: "Burgundy")
                            UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.2)
                        }

                        Button("Got it") {
                            withAnimation {
                                isVisible = false
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.burgundy)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 3.5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1)))
                    )
                    .padding()
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func learnCard(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.burgundy)

            Text(title)
                .font(.title.bold())
                .foregroundColor(.latte)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundColor(.latte)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
    }
}
