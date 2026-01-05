//
//  AIRatingSheet.swift
//  SommLens
//
//  Created by Logan Rausch on 11/10/25.
//

// AIRatingSheet.swift


// AIRatingSheet.swift
import SwiftUI

struct AIRatingSheet: View {
    let rating: AIRating

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    RatingHeader(rating: rating)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why this score").font(.headline)
                        Text(rating.ratingExplanation).foregroundStyle(.black.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What Vini considered").font(.headline)
                        if let _ = rating.weightedTotal {
                            Text(String(format: "Vini Score (weighted): %.1f / 10", rating.viniScore))
                                .foregroundStyle(.black.opacity(0.6))
                        }
                        VStack(spacing: 10) {
                            ForEach(rating.factors, id: \.name) { f in
                                let tenPoint = rating.tenPoint(for: f)   // 0–10

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(f.name.capitalized)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(String(format: "%.1f / 10", tenPoint))
                                            .font(.subheadline.monospacedDigit())
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

                    // 🔻 DISCLAIMER AT THE BOTTOM 🔻
                    VStack(spacing: 4) {
                        Text("Disclaimer")
                            .font(.caption2.bold())
                        Text("AI ratings are generated automatically from label information and general wine knowledge using OpenAI. The ratings are intended for educational use only and should not replace your own judgment. ")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    
                    // Footer
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
            .navigationTitle("Vini's Rating")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Header with circular score + banded confidence
private struct RatingHeader: View {
    let rating: AIRating

    var body: some View {
        let score = rating.viniScore

        HStack(spacing: 16) {
            CircularScoreView(score: score)

            Spacer(minLength: 12)

            VStack(alignment: .center, spacing: 6) {
                Text(descriptor(for: score))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    ConfidenceTag(confidence: rating.confidence)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Circular score ring
private struct CircularScoreView: View {
    let score: Double          // 0–10
    var progress: CGFloat { CGFloat(max(0, min(score, 10))) / 10 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: 7)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    .burgundy,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: score)

            VStack(spacing: -2) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 60, alignment: .center)
        }
        .frame(width: 110, height: 110)
    }
}

// MARK: - Confidence band + descriptor helpers
private enum ConfidenceBand { case low, medium, high }

private func band(for c: Double) -> ConfidenceBand {
    switch c {
    case ..<0.60: return .low
    case ..<0.80: return .medium
    default:      return .high
    }
}

private func descriptor(for score: Double) -> String {
    switch score {
    case 9.5...10.0: return "Truly Special"
    case 9.0..<9.5:  return "Exceptional"
    case 8.5..<9.0:  return "High Quality"
    case 8.0..<8.5:  return "Very Good"
    case 7.5..<8.0:  return "Good Everyday Wine"
    case 7.0..<7.5:  return "Simple, Easy-Drinking"
    default:         return "Very Basic / Limited Complexity"
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

private struct ConfidenceTag: View {
    let confidence: Double
    var bandVal: ConfidenceBand { band(for: confidence) }

    var label: String {
        switch bandVal {
        case .high:   return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low:    return "Low Confidence"
        }
    }

    var body: some View {
        Tag(text: label)
    }
}

#if DEBUG
struct AIRatingSheet_Previews: PreviewProvider {

    static var mock: AIRating = {
        let factors: [AIRating.Factor] = [
            .init(name: "style match", score: 92, weight: 0.35, reason: "Classic for the appellation."),
            .init(name: "producer", score: 90, weight: 0.25, reason: "Strong, consistent house style."),
            .init(name: "vintage",  score: 88, weight: 0.20, reason: "Warm year; generous fruit."),
            .init(name: "terroir",  score: 94, weight: 0.20, reason: "Prime slope; limestone-clay.")
        ]
        let sumW = factors.reduce(0.0) { $0 + $1.weight }
        let total = sumW > 0
            ? factors.reduce(0.0) { $0 + Double($1.score) * $1.weight } / sumW
            : 0
        return AIRating(
            aiRating: Int(total.rounded()),
            ratingExplanation: "Elevated style match and site expression; small deduction for vintage warmth.",
            factors: factors,
            weightedTotal: total,
            confidence: 0.84
        )
    }()

    static var previews: some View {
        Group {
            NavigationStack { AIRatingSheet(rating: mock) }
                .previewDisplayName("Light")

            NavigationStack { AIRatingSheet(rating: mock) }
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }
}
#endif
