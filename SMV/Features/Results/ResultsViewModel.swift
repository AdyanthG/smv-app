//
//  ResultsViewModel.swift
//  SMV
//
//  Business logic for the results display.
//

import SwiftUI
import SwiftData

@Observable
final class ResultsViewModel {

    var result: ScanResult?
    var previousResult: ScanResult?
    var showShareSheet = false
    var shareImage: UIImage?

    var scoreDelta: Double? {
        guard let current = result?.overallScore,
              let previous = previousResult?.overallScore else { return nil }
        return current - previous
    }

    var improvementTips: [(icon: String, title: String, description: String)] {
        guard let result else { return [] }

        var tips: [(String, String, String)] = []
        let attrs = result.attributes.sorted { $0.score < $1.score }

        for attr in attrs.prefix(3) {
            switch attr.name {
            case "Skin Clarity":
                tips.append(("drop.fill", "Skincare Routine", "Cleanser → Retinol → Moisturizer → SPF. Consistency is everything."))
                tips.append(("cup.and.saucer.fill", "Hydration", "Drink 3+ liters of water daily. Skin clarity starts from within."))
            case "Jawline":
                tips.append(("figure.run", "Body Fat", "Lowering overall body fat percentage can significantly define the jawline."))
                tips.append(("mouth.fill", "Mewing", "Maintain proper tongue posture against the palate throughout the day."))
            case "Symmetry":
                tips.append(("bed.double.fill", "Sleep Position", "Try sleeping on your back to avoid asymmetric facial compression."))
            case "Eye Area":
                tips.append(("moon.fill", "Sleep Quality", "7-9 hours of quality sleep reduces dark circles and puffiness."))
            case "Harmony":
                tips.append(("scissors", "Hairstyle", "Choose a hairstyle that complements your face shape and proportions."))
            case "Proportions":
                tips.append(("face.smiling", "Grooming", "Clean, well-maintained facial hair can improve perceived proportions."))
            default:
                break
            }
        }

        return tips.map { ($0.0, $0.1, $0.2) }
    }

    func loadResult(scanId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<ScanResult>(
            predicate: #Predicate { $0.id == scanId }
        )
        result = try? context.fetch(descriptor).first

        // Load previous result
        if let userId = result?.userId {
            let prevDescriptor = FetchDescriptor<ScanResult>(
                predicate: #Predicate { $0.userId == userId },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let allResults = (try? context.fetch(prevDescriptor)) ?? []
            previousResult = allResults.count > 1 ? allResults[1] : nil
        }
    }

    @MainActor
    func generateShareCard() {
        guard let result else { return }
        let card = ShareCardView(result: result)
        shareImage = card.renderToImage()
        showShareSheet = true
    }
}
