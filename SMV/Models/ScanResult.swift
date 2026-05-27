//
//  ScanResult.swift
//  SMV
//
//  Scan result model with PSL-accurate metrics.
//  Persisted via SwiftData.
//

import Foundation
import SwiftData

@Model
final class ScanResult {

    @Attribute(.unique)
    var id: String

    var userId: String
    var timestamp: Date

    // ── Overall Score (1-10, PSL-mapped) ──
    var overallScore: Double

    // ── Category Scores (1-10 each) ──
    var eyeAreaScore: Double
    var jawScore: Double
    var symmetryScore: Double
    var harmonyScore: Double
    var proportionsScore: Double
    var skinClarityScore: Double

    // ── Legacy compat ──
    var jawlineScore: Double

    // ── Raw Biometric Measurements ──
    var fwhr: Double
    var canthalTiltDegrees: Double
    var gonialAngleDegrees: Double
    var facialThirdsDeviation: Double
    var ipdRatio: Double
    var eyeAspectRatio: Double
    var noseWidthRatio: Double
    var lipRatio: Double
    var philtrumRatio: Double
    var rawSymmetry: Double

    // ── Failo Detection ──
    var failos: [String]
    var failoPenalty: Double

    // ── Multi-angle scan flag ──
    var isMultiAngleScan: Bool

    // ── Image ──
    @Attribute(.externalStorage)
    var imageData: Data?

    // ── Computed ──
    var tier: ScoreTier {
        ScoreTier.from(score: overallScore)
    }

    var attributes: [(name: String, score: Double)] {
        [
            ("Eye Area", eyeAreaScore),
            ("Jawline", jawScore),
            ("Symmetry", symmetryScore),
            ("Harmony", harmonyScore),
            ("Proportions", proportionsScore),
            ("Skin Clarity", skinClarityScore),
        ]
    }

    var topAttribute: String {
        attributes.max(by: { $0.score < $1.score })?.name ?? "Eye Area"
    }

    var weakestAttribute: String {
        attributes.min(by: { $0.score < $1.score })?.name ?? "Jawline"
    }

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        userId: String,
        timestamp: Date = .now,
        overallScore: Double,
        eyeAreaScore: Double = 5.0,
        jawScore: Double = 5.0,
        symmetryScore: Double = 5.0,
        harmonyScore: Double = 5.0,
        proportionsScore: Double = 5.0,
        skinClarityScore: Double = 5.0,
        jawlineScore: Double = 5.0,
        fwhr: Double = 1.85,
        canthalTiltDegrees: Double = 4.0,
        gonialAngleDegrees: Double = 120.0,
        facialThirdsDeviation: Double = 0.05,
        ipdRatio: Double = 0.45,
        eyeAspectRatio: Double = 0.33,
        noseWidthRatio: Double = 0.25,
        lipRatio: Double = 0.35,
        philtrumRatio: Double = 0.32,
        rawSymmetry: Double = 0.90,
        failos: [String] = [],
        failoPenalty: Double = 1.0,
        isMultiAngleScan: Bool = false,
        imageData: Data? = nil
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.overallScore = overallScore
        self.eyeAreaScore = eyeAreaScore
        self.jawScore = jawScore
        self.symmetryScore = symmetryScore
        self.harmonyScore = harmonyScore
        self.proportionsScore = proportionsScore
        self.skinClarityScore = skinClarityScore
        self.jawlineScore = jawlineScore
        self.fwhr = fwhr
        self.canthalTiltDegrees = canthalTiltDegrees
        self.gonialAngleDegrees = gonialAngleDegrees
        self.facialThirdsDeviation = facialThirdsDeviation
        self.ipdRatio = ipdRatio
        self.eyeAspectRatio = eyeAspectRatio
        self.noseWidthRatio = noseWidthRatio
        self.lipRatio = lipRatio
        self.philtrumRatio = philtrumRatio
        self.rawSymmetry = rawSymmetry
        self.failos = failos
        self.failoPenalty = failoPenalty
        self.isMultiAngleScan = isMultiAngleScan
        self.imageData = imageData
    }

    // MARK: - Convenience init from FaceMetrics

    convenience init(userId: String, metrics: FaceMetrics, imageData: Data? = nil) {
        self.init(
            userId: userId,
            overallScore: metrics.overallScore,
            eyeAreaScore: metrics.eyeAreaScore,
            jawScore: metrics.jawScore,
            symmetryScore: metrics.symmetryRating,
            harmonyScore: metrics.harmonyScore,
            proportionsScore: metrics.proportionsScore,
            skinClarityScore: metrics.skinClarityScore,
            jawlineScore: metrics.jawScore,
            fwhr: metrics.fwhr,
            canthalTiltDegrees: metrics.canthalTiltDegrees,
            gonialAngleDegrees: metrics.gonialAngleDegrees,
            facialThirdsDeviation: metrics.facialThirdsDeviation,
            ipdRatio: metrics.ipdRatio,
            eyeAspectRatio: metrics.eyeAspectRatio,
            noseWidthRatio: metrics.noseWidthRatio,
            lipRatio: metrics.lipRatio,
            philtrumRatio: metrics.philtrumRatio,
            rawSymmetry: metrics.symmetryScore,
            failos: metrics.failos,
            failoPenalty: metrics.failoPenalty,
            imageData: imageData
        )
    }

    // MARK: - Legacy convenience init for previews

    convenience init(
        userId: String,
        overallScore: Double,
        symmetryScore: Double,
        jawlineScore: Double,
        eyeAreaScore: Double,
        skinClarityScore: Double,
        harmonyScore: Double,
        proportionsScore: Double
    ) {
        self.init(
            userId: userId,
            overallScore: overallScore,
            eyeAreaScore: eyeAreaScore,
            jawScore: jawlineScore,
            symmetryScore: symmetryScore,
            harmonyScore: harmonyScore,
            proportionsScore: proportionsScore,
            skinClarityScore: skinClarityScore,
            jawlineScore: jawlineScore
        )
    }
}
