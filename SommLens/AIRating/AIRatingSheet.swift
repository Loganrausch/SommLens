//
//  AIRatingSheet.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//

// AIRatingSheet.swift
import SwiftUI

struct AIRatingSheet: View {
    let rating: AIRating
    var isUnlocked: Bool
    var unlockAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    RatingHeader(
                        rating: rating,
                        isUnlocked: isUnlocked,
                        unlockAction: unlockAction
                    )

                    // ✅ Gate everything below the header
                    if isUnlocked {

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why this impression").font(.headline)
                            Text(rating.ratingExplanation)
                                .foregroundStyle(.black.opacity(0.6))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("What Vini considered").font(.headline)
                            
                            
                            VStack(spacing: 10) {
                                ForEach(rating.factors, id: \.name) { f in
                                    let tenPoint = rating.tenPoint(for: f)   // 0–10
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(f.name.capitalized)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Text(String(format: "%.1f / 10", tenPoint))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        ProgressView(value: tenPoint, total: 10)
                                            .progressViewStyle(.linear)
                                            .tint(.burgundy)
                                        
                                        Text(f.reason)
                                            .font(.footnote)
                                            .foregroundStyle(.black.opacity(0.6))
                                    }
                                    .padding()
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                    } else {

                        LockedRatingBody(
                            unlockAction: unlockAction
                        )
                    }
                    
                    // Disclaimer (your call — I’m leaving it inside Pro)
                    VStack(spacing: 4) {
                        Text("Disclaimer")
                            .font(.caption2.bold())
                        Text("AI impressions are generated automatically from label information and general wine knowledge using OpenAI. The impressions are intended for educational use only and should not replace your own judgment.")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)

                    // Footer (fine for everyone)
                    VStack(spacing: 4) {
                        Text("SommLens")
                            .font(.caption2)
                            .foregroundColor(.black.opacity(0.6))
                        Image("OpenAIBadge")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 24)
                }
                .padding(16)
            }
            .navigationTitle("Vini's Take")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct RatingHeader: View {
    let rating: AIRating
    let isUnlocked: Bool
    let unlockAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // little accent bar
            RoundedRectangle(cornerRadius: 2)
                .foregroundStyle(.burgundy.opacity(0.75))
                .frame(width: 45, height: 2)

            if isUnlocked {
                Text(rating.overallImpression)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.9))
            } else {
                Text("Upgrade for details")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.burgundy)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Locked body (everything except score)
private struct LockedRatingBody: View {
    let unlockAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.burgundy)
                Text("Impression breakdown is Pro")
                    .font(.headline)
                Spacer()
            }

            Text("Unlock the explanation and the factors behind Vini’s take.")
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.7))

            Button {
                unlockAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.circle.fill")
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.latte.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.burgundy.opacity(0.8), lineWidth: 1)
            )
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}


// Simple pill tags used for confidence
private struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}
