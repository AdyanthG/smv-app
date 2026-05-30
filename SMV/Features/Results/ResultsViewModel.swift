//
//  ResultsViewModel.swift
//  SMV
//
//  Business logic for the results display.
//

import SwiftUI
import SwiftData
import FirebaseFirestore

@Observable
final class ResultsViewModel {

    var result: ScanResult?
    var previousResult: ScanResult?
    var showShareSheet = false
    var shareImage: UIImage?

    /// Angle image URLs for a scan loaded from Firestore (not in local storage).
    /// Keyed by angle label: "Front", "Left", "Right", "Up", "Down".
    var remoteAngleURLs: [String: String]?

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

    /// Load a scan for display. Tries local SwiftData first (own scans); if not
    /// found, fetches it from Firestore (another user's scan) and builds an
    /// in-memory result — it is intentionally NOT inserted into the model context.
    func loadResult(scanId: String, context: ModelContext, firestore: FirestoreService) async {
        let descriptor = FetchDescriptor<ScanResult>(
            predicate: #Predicate { $0.id == scanId }
        )
        if let local = try? context.fetch(descriptor).first {
            result = local
            loadPreviousResult(userId: local.userId, context: context)
            return
        }

        // Not local — fetch from Firestore (e.g. viewing another user's scan)
        if let data = await firestore.fetchScan(scanId: scanId) {
            result = Self.makeResult(scanId: scanId, data: data)
            remoteAngleURLs = Self.angleURLs(from: data)
        }
    }

    private func loadPreviousResult(userId: String, context: ModelContext) {
        let prevDescriptor = FetchDescriptor<ScanResult>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let allResults = (try? context.fetch(prevDescriptor)) ?? []
        previousResult = allResults.count > 1 ? allResults[1] : nil
    }

    /// Build an in-memory ScanResult from a Firestore scan document.
    private static func makeResult(scanId: String, data: [String: Any]) -> ScanResult {
        func d(_ key: String, _ fallback: Double) -> Double { data[key] as? Double ?? fallback }

        let result = ScanResult(
            id: scanId,
            userId: data["userId"] as? String ?? "",
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? .now,
            overallScore: d("overallScore", 0),
            eyeAreaScore: d("eyeAreaScore", 5),
            jawScore: d("jawScore", 5),
            symmetryScore: d("symmetryScore", 5),
            harmonyScore: d("harmonyScore", 5),
            proportionsScore: d("proportionsScore", 5),
            skinClarityScore: d("skinClarityScore", 5),
            jawlineScore: d("jawScore", 5),
            fwhr: d("fwhr", 1.85),
            canthalTiltDegrees: d("canthalTiltDegrees", 4),
            gonialAngleDegrees: d("gonialAngleDegrees", 120),
            facialThirdsDeviation: d("facialThirdsDeviation", 0.05),
            ipdRatio: d("ipdRatio", 0.45),
            eyeAspectRatio: d("eyeAspectRatio", 0.33),
            noseWidthRatio: d("noseWidthRatio", 0.25),
            lipRatio: d("lipRatio", 0.35),
            philtrumRatio: d("philtrumRatio", 0.32),
            rawSymmetry: d("rawSymmetry", 0.90),
            failos: data["failos"] as? [String] ?? [],
            failoPenalty: d("failoPenalty", 1.0)
        )
        // Treat as multi-angle if any profile angle URL is present.
        result.isMultiAngleScan = data["leftImageURL"] != nil || data["rightImageURL"] != nil
        return result
    }

    /// Extract angle label → URL map from a Firestore scan document.
    private static func angleURLs(from data: [String: Any]) -> [String: String] {
        let keys: [(String, String)] = [
            ("Front", "frontImageURL"),
            ("Left", "leftImageURL"),
            ("Right", "rightImageURL"),
            ("Up", "upTiltImageURL"),
            ("Down", "downTiltImageURL"),
        ]
        var map: [String: String] = [:]
        for (label, field) in keys {
            if let url = data[field] as? String { map[label] = url }
        }
        return map
    }

    @MainActor
    func generateShareCard() {
        guard let result else { return }
        let card = ShareCardView(result: result)
        shareImage = card.renderToImage()
        showShareSheet = true
    }
}
