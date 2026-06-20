//
//  CoachPlan.swift
//  SMV
//
//  Personalized Looksmax Coach — generates a structured improvement plan from a
//  scan's metrics. Rule-based (no network), so it's instant, free, and reliable.
//

import Foundation

struct CoachFocusArea: Identifiable {
    let id = UUID()
    let attribute: String
    let score: Double
    let icon: String
    let why: String
    let protocols: [String]
    let timeline: String
}

struct CoachRoutineSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [String]
}

struct CoachPhase: Identifiable {
    let id = UUID()
    let phase: String
    let detail: String
}

struct CoachPlan {
    let headline: String
    let assessment: String
    let focusAreas: [CoachFocusArea]
    let quickWins: [String]
    let routine: [CoachRoutineSection]
    let roadmap: [CoachPhase]

    static func generate(from scan: ScanResult) -> CoachPlan {
        let attrs = scan.attributes // [(name, score)]
        let sorted = attrs.sorted { $0.score < $1.score }
        let weakest = Array(sorted.prefix(3))
        let strongest = sorted.last

        let tier = scan.tier
        let headline = "Your \(tier.rawValue) game plan"

        let topName = strongest?.name ?? "your features"
        let weakestName = weakest.first?.name ?? "your weak points"
        let assessment = """
        You're scoring \(scan.overallScore.scoreFormatted) (\(tier.rawValue)). Your strongest asset is \(topName.lowercased()) — lean into it. Your biggest upside is \(weakestName.lowercased()). This plan targets the \(weakest.count) areas where you'll gain the most, fastest.
        """

        let focusAreas = weakest.map { area in
            let content = protocolLibrary(for: area.name)
            return CoachFocusArea(
                attribute: area.name,
                score: area.score,
                icon: content.icon,
                why: content.why,
                protocols: content.protocols,
                timeline: content.timeline
            )
        }

        return CoachPlan(
            headline: headline,
            assessment: assessment,
            focusAreas: focusAreas,
            quickWins: quickWins,
            routine: dailyRoutine,
            roadmap: roadmap
        )
    }

    // MARK: - Content library

    private static func protocolLibrary(for attribute: String) -> (icon: String, why: String, protocols: [String], timeline: String) {
        switch attribute {
        case "Skin Clarity":
            return ("sparkles",
                "Clear skin is the single highest-ROI looksmaxxing lever — it reads as health and youth instantly.",
                [
                    "AM: gentle cleanser → vitamin C → moisturizer → SPF 30+ (never skip sunscreen)",
                    "PM: cleanser → retinoid (start 2×/week, build up) → moisturizer",
                    "Drink 3L+ of water daily; cut excess sugar and dairy if acne-prone",
                    "7–9h of sleep — skin repairs overnight",
                    "Persistent acne? See a dermatologist about tretinoin or accutane",
                ],
                "Visible improvement in 6–12 weeks")
        case "Jawline":
            return ("shield.fill",
                "A defined jaw is mostly body-fat and posture — both fully in your control.",
                [
                    "Lower your body-fat % — the #1 factor. Caloric deficit + high protein",
                    "Mewing: rest your whole tongue on the roof of your mouth, all day",
                    "Cut sodium and processed food to reduce facial water retention",
                    "Chew hard (mastic) gum to develop the masseter",
                    "Fix forward-head posture with daily chin tucks",
                ],
                "Body-composition changes show in 8–16 weeks")
        case "Eye Area":
            return ("eye.fill",
                "The eyes are the prize — they carry the most weight in perceived attractiveness.",
                [
                    "Prioritize 7–9h of quality sleep to cut dark circles and puffiness",
                    "Reduce salt intake — sodium causes under-eye puffiness",
                    "Groom and shape your eyebrows to frame the eyes",
                    "Cold compress or chilled spoons in the morning for de-puffing",
                    "Stay hydrated; consider a caffeine eye cream for circles",
                ],
                "Puffiness and circles improve in 2–6 weeks")
        case "Symmetry":
            return ("arrow.left.and.right",
                "Bone symmetry is largely fixed, but soft-tissue and posture asymmetries are fixable.",
                [
                    "Sleep on your back to avoid asymmetric facial compression",
                    "Chew evenly on both sides of your mouth",
                    "Correct postural imbalances (shoulders, neck) with targeted training",
                    "Use a hairstyle and part that visually balances your face",
                    "Smile and pose symmetrically in photos",
                ],
                "Soft-tissue changes over 4–12 weeks")
        case "Harmony":
            return ("circle.hexagongrid.fill",
                "Harmony is about how your features work together — framing is the fastest lever.",
                [
                    "Get a haircut tailored to your face shape (biggest single change)",
                    "Shape facial hair to balance your proportions",
                    "Pick glasses/frames that complement your face width",
                    "Optimize body weight — facial fat changes overall harmony",
                    "Groom eyebrows to match your features",
                ],
                "Immediate with grooming, weeks for the rest")
        case "Proportions":
            return ("ruler.fill",
                "Proportions respond to framing and body composition more than you'd think.",
                [
                    "A face-shape-appropriate hairstyle reshapes perceived proportions",
                    "Clean, well-maintained facial hair adds lower-third definition",
                    "Reduce facial fat to sharpen underlying structure",
                    "Eyebrow grooming balances the upper third",
                    "Improve posture — it changes how your whole face presents",
                ],
                "Grooming is instant; structure over 8–16 weeks")
        default:
            return ("circle.fill",
                "Consistent fundamentals move this metric.",
                ["Dial in sleep, hydration, skincare, and body composition", "Re-scan weekly to track progress"],
                "4–12 weeks")
        }
    }

    private static let quickWins: [String] = [
        "Book a fresh haircut suited to your face shape",
        "Shape your eyebrows (biggest 5-minute upgrade)",
        "Whiten your teeth",
        "Fix your posture — chin up, shoulders back",
        "Maintain clean facial hair or a sharp shave",
    ]

    private static let dailyRoutine: [CoachRoutineSection] = [
        CoachRoutineSection(title: "Morning", icon: "sunrise.fill", items: [
            "Cleanse → vitamin C → moisturizer → SPF",
            "10 min mewing while you get ready",
            "16oz of water on waking",
        ]),
        CoachRoutineSection(title: "Daytime", icon: "figure.run", items: [
            "Train — lift + a little cardio for body composition",
            "Hit 3L+ water and a high-protein meal",
            "Maintain tongue posture and chin-up posture",
        ]),
        CoachRoutineSection(title: "Evening", icon: "moon.stars.fill", items: [
            "Cleanse → retinoid → moisturizer",
            "No screens 30 min before bed",
            "7–9h sleep, on your back",
        ]),
    ]

    private static let roadmap: [CoachPhase] = [
        CoachPhase(phase: "Days 1–30", detail: "Lock in skincare, sleep, and hydration. Get a great haircut and groom your brows. Start mewing and training."),
        CoachPhase(phase: "Days 31–60", detail: "Dial in body composition. Ramp your retinoid. Re-scan weekly and watch your weak areas climb."),
        CoachPhase(phase: "Days 61–90", detail: "Re-assess your scan, double down on what's working, and consider advanced steps for your lowest metric."),
    ]
}
