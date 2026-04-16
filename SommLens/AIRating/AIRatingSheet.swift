//
//  AIRatingSheet.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//


// AIRatingSheet.swift
import SwiftUI
 
// MARK: - Dark Palette (copper accent + wine warmth)
private extension Color {
    // Backgrounds — near-black with faint wine undertone
    static let cellarDeep    = Color(red: 0.065, green: 0.058, blue: 0.060)
    static let cellarMid     = Color(red: 0.095, green: 0.085, blue: 0.088)
    static let cellarWarm    = Color(red: 0.118, green: 0.095, blue: 0.098)
 
    // Surfaces — whisper of burgundy, not pure white alpha
    static let surfaceWarm   = Color(red: 0.55, green: 0.35, blue: 0.33, opacity: 0.05)
    static let surfaceBorder = Color(red: 0.50, green: 0.38, blue: 0.36, opacity: 0.08)
 
    // Header gradient — subtle burgundy wash
    static let headerStart   = Color.burgundy.opacity(0.12)
    static let headerEnd     = Color(hex: "#c8816a").opacity(0.06)
 
    // Accent — #c8816a copper from the detail card
    static let accentCopper  = Color(hex: "#c8816a")
    static let accentCopperLight  = Color(hex: "#c8816a").opacity(0.7)
    static let barStart      = Color.burgundy.opacity(0.7)
    static let barEnd        = Color(hex: "#c8816a")
 
    // Text — warm cast on primary/heading, neutral for body down
    static let textPrimary   = Color(red: 0.98, green: 0.95, blue: 0.93, opacity: 0.92)
    static let textHeading   = Color(red: 0.96, green: 0.93, blue: 0.91, opacity: 0.80)
    static let textLabel     = Color.white.opacity(0.72)
    static let textBody      = Color.white.opacity(0.60)
    static let textCaption   = Color.white.opacity(0.48)
    static let textMuted     = Color.white.opacity(0.30)
    static let textScore     = Color(hex: "#c8816a").opacity(0.8)
    static let dividerWarm   = Color(red: 0.50, green: 0.38, blue: 0.36, opacity: 0.10)
}
 
struct AIRatingSheet: View {
    
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    let rating: AIRating
    var isUnlocked: Bool
 
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark warm background
                LinearGradient(
                    colors: [Color.cellarMid, Color.cellarWarm, Color.cellarMid, Color.cellarDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
 
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
 
                        RatingHeader(
                            rating: rating,
                            isUnlocked: isUnlocked,
                           
                        )
 
                        // ✅ Gate everything below the header
                        if isUnlocked {
 
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Why this impression").font(.headline)
                                    .foregroundStyle(Color.accentCopperLight)
                                Text(rating.ratingExplanation)
                                    .foregroundStyle(Color.textBody)
                            }
 
                            VStack(alignment: .leading, spacing: 15) {
                                Text("What Vini considered").font(.headline)
                                    .foregroundStyle(Color.accentCopperLight)
 
                                // Unified block — rows with dividers, not stacked cards
                                VStack(spacing: 0) {
                                    ForEach(Array(rating.factors.enumerated()), id: \.element.name) { index, f in
                                        let tenPoint = rating.tenPoint(for: f)
 
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(f.name.capitalized)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.textLabel)
                                                Spacer()
                                                Text(String(format: "%.1f", tenPoint))
                                                    .font(.caption.monospacedDigit())
                                                    .foregroundStyle(Color.textScore)
                                            }
 
                                            // Gradient progress bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(Color.white.opacity(0.04))
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color.barStart, Color.barEnd],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                        .frame(width: geo.size.width * CGFloat(tenPoint / 10.0))
                                                }
                                            }
                                            .frame(height: 3)
 
                                            Text(f.reason)
                                                .font(.footnote)
                                                .foregroundStyle(Color.textCaption)
                                        }
 
                                        if index < rating.factors.count - 1 {
                                            Rectangle()
                                                .fill(Color.dividerWarm)
                                                .frame(height: 0.5)
                                                .padding(.vertical, 14)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.surfaceWarm)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.surfaceBorder, lineWidth: 0.5)
                                )
                            }
 
                        } else {
 
                            LockedRatingBody(
                               
                            )
                        }
 
                        // Disclaimer
                        VStack(spacing: 4) {
                            Text("Disclaimer")
                                .font(.caption2.bold())
                            Text("AI impressions are generated automatically from label information and general wine knowledge using OpenAI. The impressions are intended for educational use only and should not replace your own judgment.")
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
 
                        // Footer
                        VStack(spacing: 10) {
                            Text("SommLens")
                                .font(.caption2)
                                .foregroundColor(Color.textMuted)
                            Image("OpenAIBadgeWhite")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 24)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 24)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Vini's Take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
    }
}
 
private struct RatingHeader: View {
    
    @EnvironmentObject var auth: AuthViewModel
    
    let rating: AIRating
    let isUnlocked: Bool
   
 
    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentCopper)
                .frame(width: 3)
 
            VStack(alignment: .leading, spacing: 0) {
                Text(rating.overallImpression)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.leading, 14)
        }
        
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
 
// MARK: - Locked body (everything except score)
private struct LockedRatingBody: View {
    
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
 
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.accentCopper.opacity(0.8))
                Text("Why this impression")
                    .font(.headline)
                    .foregroundStyle(Color.textHeading)
                Spacer()
            }
 
            Text("Unlock the explanation and the factors behind Vini's take.")
                .font(.subheadline)
                .foregroundStyle(Color.textBody)
                .padding(.bottom, 6)
 
            Button {
                auth.isPaywallPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.circle.fill")
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Color.accentCopper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.surfaceWarm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentCopper.opacity(0.4), lineWidth: 1)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.surfaceWarm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.surfaceBorder, lineWidth: 0.5)
        )
    }
}
 
 
// Simple pill tags used for confidence
private struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.textLabel)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.surfaceWarm, in: Capsule())
    }
}

#if DEBUG
 
private extension AIRating {
    static let mock = AIRating(
        aiRating: 89,
        ratingExplanation: "Concentrated dark fruit with integrated oak and a balanced tannic frame suggest careful winemaking from a strong vintage. Not trying to be flashy — just honest and well-structured.",
        factors: [
            Factor(name: "structure",  score: 85, weight: 0.30, reason: "Firm tannins, polished mid-palate, confident backbone."),
            Factor(name: "complexity", score: 72, weight: 0.25, reason: "Blackcurrant, cedar, graphite — layered but not maze-like."),
            Factor(name: "value",      score: 78, weight: 0.20, reason: "Outperforms many bottles in its range."),
            Factor(name: "balance",    score: 80, weight: 0.25, reason: "Fruit, acid, and oak in conversation — nothing dominates.")
        ],
        weightedTotal: 89.0,
        confidence: 0.82
    )
}
 
#Preview("Unlocked") {
    AIRatingSheet(
        rating: .mock,
        isUnlocked: true
    )
    .environmentObject(AuthViewModel())
}

#Preview("Locked") {
    AIRatingSheet(
        rating: .mock,
        isUnlocked: false
    )
    .environmentObject(AuthViewModel())
}
 
#endif
