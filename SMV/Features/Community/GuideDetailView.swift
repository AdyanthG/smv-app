//
//  GuideDetailView.swift
//  SMV
//
//  Detail view for community guides with full article content.
//

import SwiftUI

struct GuideDetailView: View {

    let title: String
    let emoji: String
    let author: String
    let readTime: String

    @Environment(HapticService.self) private var haptics
    @State private var isLiked = false
    @State private var likeCount = Int.random(in: 800...3500)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    Text(emoji)
                        .font(.system(size: 48))

                    Text(title)
                        .font(SMVFont.displaySmall())
                        .foregroundStyle(.white)

                    HStack(spacing: SMVSpacing.md) {
                        AvatarView(name: author, size: 24)
                        Text(author)
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvCyan)

                        Text("•")
                            .foregroundStyle(Color.smvTextTertiary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(readTime)
                        }
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)

                Divider().overlay(Color.smvSurface2)

                // Article body
                VStack(alignment: .leading, spacing: SMVSpacing.lg) {
                    ForEach(guideContent, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(SMVFont.body())
                            .foregroundStyle(Color.smvTextSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)

                Divider().overlay(Color.smvSurface2)

                // Actions
                HStack(spacing: SMVSpacing.xl) {
                    Button {
                        haptics.mediumImpact()
                        isLiked.toggle()
                        likeCount += isLiked ? 1 : -1
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                            Text("\(likeCount)")
                                .font(SMVFont.caption())
                        }
                        .foregroundStyle(isLiked ? Color.smvPink : Color.smvTextSecondary)
                    }

                    Button {
                        haptics.lightImpact()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                            Text("Share")
                                .font(SMVFont.caption())
                        }
                        .foregroundStyle(Color.smvTextSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, SMVSpacing.lg)
            }
            .padding(.vertical, SMVSpacing.lg)
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // Generate content based on the guide title
    private var guideContent: [String] {
        switch title {
        case "The Complete Softmaxxing Guide":
            return [
                "Softmaxxing refers to non-surgical methods of improving your appearance. These techniques focus on maximizing what you already have through lifestyle changes, grooming, and self-care routines.",
                "The foundation of any softmaxxing journey starts with three pillars: skincare, hair optimization, and body composition. Each of these areas can yield significant improvements in your overall facial aesthetics score.",
                "Skincare: Start with a basic routine — cleanser, moisturizer, and SPF. Once you've been consistent for 2-4 weeks, introduce active ingredients like retinol (start at 0.025%), vitamin C serum, and niacinamide. Consistency is more important than complexity.",
                "Hair: Your hairstyle frames your face and can dramatically affect perceived symmetry and facial proportions. Consult with a barber or stylist who understands face shapes. Generally, styles that add volume on top work well for round faces, while shorter sides suit oval faces.",
                "Body Composition: Facial fat distribution changes significantly between 15-22% body fat. Lowering body fat reveals jawline definition and cheekbone prominence. However, going too low can create a gaunt appearance. Find your sweet spot.",
                "Advanced techniques include mewing (proper tongue posture), facial exercises for masseter development, and strategic facial hair grooming. These require months of consistency but yield compound results.",
                "Remember: softmaxxing is a marathon, not a sprint. Track your progress with monthly scans and aim for consistent 0.1-0.3 point improvements over time."
            ]
        case "Understanding PSL Ratings":
            return [
                "PSL (Pretty Scale Level) is a rating system used to quantify facial attractiveness on a 1-10 scale based on objective facial features and proportions.",
                "Unlike subjective ratings, PSL analysis focuses on measurable features: facial symmetry, golden ratio proportions, canthal tilt, jaw-to-face ratio, midface ratio, and interpupillary distance.",
                "Score Ranges: 1-3 (Below Average) — Significant asymmetry or disproportionate features. 3-5 (Average) — Most people fall here; room for improvement through softmaxxing. 5-7 (Above Average) — Favorable proportions with minor areas for improvement. 7-8 (Very Attractive) — Strong harmony across all features. 8+ (Exceptional) — Near-perfect proportions; extremely rare.",
                "Key metrics include: FWHR (Face Width-to-Height Ratio, ideal 1.8-2.0), ES ratio (Eye Spacing ratio), jawline angularity (110-130° ideal), and facial thirds symmetry.",
                "Your SMV scan measures these metrics automatically using TrueDepth camera data combined with Vision framework analysis. The multi-angle scan provides a more accurate assessment than a single frontal photo.",
                "Important: PSL ratings are objective measurements. A 5.5 PSL is genuinely above average. Don't compare to inflated ratings on social media. Focus on YOUR trajectory, not absolute numbers."
            ]
        case "Skincare Routine for Clarity":
            return [
                "Skin clarity is one of the fastest areas to improve and has a direct impact on your attractiveness score. Clear, even-toned skin signals health and youth.",
                "The Basic Routine (Month 1-2): AM — Gentle cleanser (CeraVe, Vanicream), lightweight moisturizer, SPF 30-50. PM — Same cleanser, moisturizer. That's it. Build consistency first.",
                "Adding Actives (Month 2-4): Introduce ONE new active at a time, with 2-week gaps. Start with niacinamide (10%) for texture, then vitamin C serum (15-20% L-ascorbic acid) in AM for brightening.",
                "The Game Changer — Retinol: Start with retinol 0.025% every 3rd night. Slowly increase to every other night over 2 months. This is the gold standard for texture, fine lines, and overall skin quality. Expect purging in weeks 2-6.",
                "Diet matters more than most products: cut dairy and refined sugar for 4 weeks and observe changes. Drink 3+ liters of water daily. Sleep 7-9 hours — this is when your skin repairs.",
                "Track your skin clarity score in your SMV scans. Most users see a 0.3-0.8 point improvement in the clarity sub-score within 3-6 months of consistent skincare."
            ]
        default:
            return [
                "This guide covers essential concepts for improving your appearance score through evidence-based methods.",
                "The key principle is consistency over intensity. Small daily improvements compound over months into significant transformations.",
                "Track your progress using regular scans and note which specific sub-scores are improving. Focus your efforts on your weakest areas for maximum impact.",
                "Remember that everyone's starting point and genetic ceiling are different. The goal is to maximize YOUR potential, not to compare yourself to others.",
                "Join the community forums to share progress, ask questions, and learn from others on the same journey."
            ]
        }
    }
}
