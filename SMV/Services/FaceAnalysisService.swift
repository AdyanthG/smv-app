//
//  FaceAnalysisService.swift
//  SMV
//
//  PSL-accurate facial analysis engine.
//  Measures real biometric ratios from Vision landmarks and scores
//  against looksmaxxing community standards.
//
//  Metrics: FWHR, canthal tilt, gonial angle, facial thirds,
//  IPD ratio, eye aspect ratio, nose width ratio, lip ratio,
//  philtrum ratio, bilateral symmetry.
//
//  Scoring: bell-curve distribution. No floor. Honest ratings.
//

import Vision
import UIKit

struct FaceMetrics {
    // Raw measurements
    let fwhr: Double                  // Face Width-to-Height Ratio
    let canthalTiltDegrees: Double    // Canthal tilt in degrees
    let gonialAngleDegrees: Double    // Gonial (jaw) angle estimate
    let facialThirdsDeviation: Double // How far from equal thirds (0 = perfect)
    let ipdRatio: Double             // Interpupillary distance / face width
    let eyeAspectRatio: Double       // Eye height / eye width
    let noseWidthRatio: Double       // Nose width / face width
    let lipRatio: Double             // Lip height / lip width
    let philtrumRatio: Double        // Philtrum length / lower third
    let symmetryScore: Double        // 0-1 (1 = perfect mirror)

    // Individual category scores (1-10)
    let eyeAreaScore: Double
    let jawScore: Double
    let harmonyScore: Double
    let symmetryRating: Double
    let skinClarityScore: Double  // Estimated from image analysis
    let proportionsScore: Double

    // Failo detection
    let failos: [String]
    let failoPenalty: Double // 0-1 multiplier

    // Composite
    let overallScore: Double
}

final class FaceAnalysisService {

    var errorMessage: String?

    // MARK: - High-Level Async API (called by ScanViewModel)

    func analyze(image: UIImage, userId: String) async -> ScanResult? {
        errorMessage = nil

        guard let cgImage = image.cgImage else {
            errorMessage = "Invalid image"
            return nil
        }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)

        do {
            try handler.perform([request])
        } catch {
            errorMessage = "Face detection failed: \(error.localizedDescription)"
            return nil
        }

        guard let observation = request.results?.first,
              let landmarks = observation.landmarks else {
            errorMessage = "No face detected. Please try again with better lighting."
            return nil
        }

        let metrics = analyzeFace(
            landmarks: landmarks,
            boundingBox: observation.boundingBox,
            image: image
        )

        let imageData = image.jpegData(compressionQuality: 0.7)
        return ScanResult(userId: userId, metrics: metrics, imageData: imageData)
    }

    // MARK: - Ideal Ranges (from PSL community standards + looksmax.org guide)

    private struct Ideals {
        // FWHR: "Among attractive men, ratios ranging from 1.9 to 2.05"
        static let fwhrRange: ClosedRange<Double> = 1.90...2.05
        static let fwhrAcceptable: ClosedRange<Double> = 1.75...2.15

        // Canthal Tilt: "ideal falls within 5-7 degrees, slightly positive"
        static let canthalRange: ClosedRange<Double> = 5.0...7.0
        static let canthalAcceptable: ClosedRange<Double> = 2.0...10.0

        // Gonial Angle: "optimal 112-123 degrees, up to 126 acceptable, >130 undesirable"
        static let gonialRange: ClosedRange<Double> = 112.0...123.0
        static let gonialAcceptable: ClosedRange<Double> = 108.0...130.0

        // Facial Thirds: equal = 0 deviation
        static let thirdsMaxDeviation: Double = 0.05

        // IPD: typical attractive ratio
        static let ipdRange: ClosedRange<Double> = 0.42...0.48

        // Eye Aspect Ratio: almond shape
        static let eyeAspectRange: ClosedRange<Double> = 0.28...0.38

        // Nose Width: "should fit between the eyes"
        static let noseWidthRange: ClosedRange<Double> = 0.22...0.28

        // Lip fullness
        static let lipRange: ClosedRange<Double> = 0.30...0.40

        // Philtrum-to-chin
        static let philtrumRange: ClosedRange<Double> = 0.28...0.35

        // Symmetry: >92% is good
        static let symmetryThreshold: Double = 0.92
    }

    // MARK: - Weights (Eye area + jaw = highest impact, per "Eyes are the prize" / "Jaw is law")

    private struct Weights {
        static let eyeArea: Double = 0.25       // Canthal tilt + eye aspect + IPD
        static let jaw: Double = 0.22           // Gonial angle + jawline definition
        static let symmetry: Double = 0.15
        static let harmony: Double = 0.15       // FWHR + facial thirds
        static let proportions: Double = 0.13   // Nose, lips, philtrum
        static let skinClarity: Double = 0.10
    }

    // MARK: - Public API

    func analyzeFace(
        landmarks: VNFaceLandmarks2D,
        boundingBox: CGRect,
        image: UIImage
    ) -> FaceMetrics {
        // Extract raw measurements
        let fwhr = calculateFWHR(landmarks: landmarks)
        let canthalTilt = calculateCanthalTilt(landmarks: landmarks)
        let gonialAngle = estimateGonialAngle(landmarks: landmarks)
        let thirdsDeviation = calculateFacialThirds(landmarks: landmarks)
        let ipdRatio = calculateIPDRatio(landmarks: landmarks)
        let eyeAspect = calculateEyeAspectRatio(landmarks: landmarks)
        let noseWidth = calculateNoseWidthRatio(landmarks: landmarks)
        let lipRatio = calculateLipRatio(landmarks: landmarks)
        let philtrumRatio = calculatePhiltrumRatio(landmarks: landmarks)
        let symmetry = calculateSymmetry(landmarks: landmarks)

        // Score each metric against ideals (0-10 scale)
        let canthalScore = scoreAgainstIdeal(
            value: canthalTilt,
            ideal: Ideals.canthalRange,
            acceptable: Ideals.canthalAcceptable,
            penalty: 2.0 // negative tilt is very bad
        )
        let eyeAspectScore = scoreAgainstIdeal(
            value: eyeAspect,
            ideal: Ideals.eyeAspectRange,
            acceptable: 0.20...0.45,
            penalty: 1.5
        )
        let ipdScore = scoreAgainstIdeal(
            value: ipdRatio,
            ideal: Ideals.ipdRange,
            acceptable: 0.38...0.52,
            penalty: 1.0
        )
        let eyeAreaScore = (canthalScore * 0.45 + eyeAspectScore * 0.35 + ipdScore * 0.20)

        let gonialScore = scoreGonialAngle(angle: gonialAngle)
        let jawDefinitionScore = estimateJawlineDefinition(landmarks: landmarks)
        let jawScore = gonialScore * 0.6 + jawDefinitionScore * 0.4

        let fwhrScore = scoreAgainstIdeal(
            value: fwhr,
            ideal: Ideals.fwhrRange,
            acceptable: Ideals.fwhrAcceptable,
            penalty: 1.5
        )
        let thirdsScore = scoreThirds(deviation: thirdsDeviation)
        let harmonyScore = fwhrScore * 0.5 + thirdsScore * 0.5

        let symmetryRating = scoreSymmetry(ratio: symmetry)

        let noseScore = scoreAgainstIdeal(
            value: noseWidth,
            ideal: Ideals.noseWidthRange,
            acceptable: 0.18...0.35,
            penalty: 1.2
        )
        let lipScore = scoreAgainstIdeal(
            value: lipRatio,
            ideal: Ideals.lipRange,
            acceptable: 0.22...0.50,
            penalty: 1.0
        )
        let philtrumScore = scoreAgainstIdeal(
            value: philtrumRatio,
            ideal: Ideals.philtrumRange,
            acceptable: 0.22...0.42,
            penalty: 1.0
        )
        let proportionsScore = noseScore * 0.40 + lipScore * 0.30 + philtrumScore * 0.30

        // Skin clarity — rough estimate from image uniformity
        let skinClarityScore = estimateSkinClarity(image: image, boundingBox: boundingBox)

        // Detect failos (features below 20th percentile = score < 3.5)
        var failos: [String] = []
        let failoThreshold: Double = 3.5

        if eyeAreaScore < failoThreshold { failos.append("Eye Area") }
        if jawScore < failoThreshold { failos.append("Jawline") }
        if symmetryRating < failoThreshold { failos.append("Symmetry") }
        if harmonyScore < failoThreshold { failos.append("Harmony") }
        if proportionsScore < failoThreshold { failos.append("Proportions") }
        if skinClarityScore < failoThreshold { failos.append("Skin Clarity") }

        // Failo penalty: each failo caps max possible score
        // One failo = max 7.5, two = max 6.5, three+ = max 5.5
        let failoPenalty: Double
        switch failos.count {
        case 0:    failoPenalty = 1.0
        case 1:    failoPenalty = 0.75  // cap around 7.5
        case 2:    failoPenalty = 0.65  // cap around 6.5
        default:   failoPenalty = 0.55  // cap around 5.5
        }

        // Weighted composite before penalty
        let rawComposite =
            eyeAreaScore * Weights.eyeArea +
            jawScore * Weights.jaw +
            symmetryRating * Weights.symmetry +
            harmonyScore * Weights.harmony +
            proportionsScore * Weights.proportions +
            skinClarityScore * Weights.skinClarity

        // Apply bell curve compression + failo penalty
        let bellCurved = applyBellCurve(rawScore: rawComposite)
        let finalScore = min(bellCurved * failoPenalty, 10.0).smvClamped(to: 1.0...10.0)

        return FaceMetrics(
            fwhr: fwhr,
            canthalTiltDegrees: canthalTilt,
            gonialAngleDegrees: gonialAngle,
            facialThirdsDeviation: thirdsDeviation,
            ipdRatio: ipdRatio,
            eyeAspectRatio: eyeAspect,
            noseWidthRatio: noseWidth,
            lipRatio: lipRatio,
            philtrumRatio: philtrumRatio,
            symmetryScore: symmetry,
            eyeAreaScore: eyeAreaScore.smvClamped(to: 1.0...10.0),
            jawScore: jawScore.smvClamped(to: 1.0...10.0),
            harmonyScore: harmonyScore.smvClamped(to: 1.0...10.0),
            symmetryRating: symmetryRating.smvClamped(to: 1.0...10.0),
            skinClarityScore: skinClarityScore.smvClamped(to: 1.0...10.0),
            proportionsScore: proportionsScore.smvClamped(to: 1.0...10.0),
            failos: failos,
            failoPenalty: failoPenalty,
            overallScore: finalScore
        )
    }

    // MARK: - Raw Measurement Calculations

    /// FWHR: bizygomatic width ÷ upper face height (brow to upper lip)
    private func calculateFWHR(landmarks: VNFaceLandmarks2D) -> Double {
        guard let contour = landmarks.faceContour else { return 1.8 }

        let points = contour.normalizedPoints
        guard points.count >= 10 else { return 1.8 }

        // Face width from contour extremes
        let xs = points.map { $0.x }
        let faceWidth = Double((xs.max() ?? 0.5) - (xs.min() ?? 0.5))

        // Mid-face height: from brow level to nose base
        let browY: Double
        if let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow {
            let browPoints = leftBrow.normalizedPoints + rightBrow.normalizedPoints
            browY = Double(browPoints.map { $0.y }.max() ?? 0.7)
        } else {
            browY = 0.7
        }

        let noseBaseY: Double
        if let nose = landmarks.nose {
            noseBaseY = Double(nose.normalizedPoints.map { $0.y }.min() ?? 0.4)
        } else {
            noseBaseY = 0.4
        }

        let midFaceHeight = browY - noseBaseY
        guard midFaceHeight > 0.01 else { return 1.8 }

        return faceWidth / midFaceHeight
    }

    /// Canthal tilt: angle from inner to outer eye corner
    private func calculateCanthalTilt(landmarks: VNFaceLandmarks2D) -> Double {
        guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye else { return 3.0 }

        let leftPts = leftEye.normalizedPoints
        let rightPts = rightEye.normalizedPoints
        guard leftPts.count >= 6, rightPts.count >= 6 else { return 3.0 }

        // Left eye: inner corner = first point, outer = midpoint
        let leftInner = leftPts[0]
        let leftOuter = leftPts[leftPts.count / 2]
        let leftAngle = atan2(Double(leftOuter.y - leftInner.y), Double(leftOuter.x - leftInner.x))

        // Right eye: similar
        let rightInner = rightPts[0]
        let rightOuter = rightPts[rightPts.count / 2]
        let rightAngle = atan2(Double(rightOuter.y - rightInner.y), Double(rightOuter.x - rightInner.x))

        // Average tilt in degrees
        let avgRadians = (leftAngle + rightAngle) / 2.0
        return avgRadians * (180.0 / .pi)
    }

    /// Gonial angle: estimated from jaw contour geometry
    private func estimateGonialAngle(landmarks: VNFaceLandmarks2D) -> Double {
        guard let contour = landmarks.faceContour else { return 125.0 }

        let points = contour.normalizedPoints
        guard points.count >= 15 else { return 125.0 }

        // Find chin (lowest Y point)
        let chinIndex = points.indices.min(by: { points[$0].y < points[$1].y }) ?? (points.count / 2)

        // Left gonion: ~25% from start of contour
        let leftGonionIdx = max(0, points.count / 5)
        // Right gonion: ~75% from start
        _ = min(points.count - 1, points.count * 4 / 5)

        // Use the left side for angle calculation
        let ramus = points[leftGonionIdx] // approximate gonion
        let chin = points[chinIndex]

        // Angle formed at the gonion
        // Vector from gonion upward (ramus direction) vs vector to chin
        let earPoint = points[0] // top of contour ≈ ear area

        let v1x = Double(earPoint.x - ramus.x)
        let v1y = Double(earPoint.y - ramus.y)
        let v2x = Double(chin.x - ramus.x)
        let v2y = Double(chin.y - ramus.y)

        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        guard mag1 > 0, mag2 > 0 else { return 125.0 }

        let cosAngle = (dot / (mag1 * mag2)).smvClamped(to: -1.0...1.0)
        return acos(cosAngle) * (180.0 / .pi)
    }

    /// Facial thirds: deviation from equal distribution
    private func calculateFacialThirds(landmarks: VNFaceLandmarks2D) -> Double {
        guard let contour = landmarks.faceContour else { return 0.1 }

        let allY = contour.normalizedPoints.map { Double($0.y) }
        let faceTop = allY.max() ?? 0.9
        let faceBottom = allY.min() ?? 0.1
        let faceHeight = faceTop - faceBottom
        guard faceHeight > 0.1 else { return 0.1 }

        // Brow line
        let browY: Double
        if let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow {
            let browPoints = leftBrow.normalizedPoints + rightBrow.normalizedPoints
            browY = Double(browPoints.map { $0.y }.max() ?? faceTop)
        } else {
            browY = faceTop - faceHeight * 0.33
        }

        // Nose base
        let noseBaseY: Double
        if let nose = landmarks.nose {
            noseBaseY = Double(nose.normalizedPoints.map { $0.y }.min() ?? (faceBottom + faceHeight * 0.33))
        } else {
            noseBaseY = faceBottom + faceHeight * 0.33
        }

        let upperThird = (faceTop - browY) / faceHeight
        let middleThird = (browY - noseBaseY) / faceHeight
        let lowerThird = (noseBaseY - faceBottom) / faceHeight

        let ideal: Double = 1.0 / 3.0
        let deviation = abs(upperThird - ideal) + abs(middleThird - ideal) + abs(lowerThird - ideal)
        return deviation / 2.0 // normalized
    }

    /// IPD ratio: interpupillary distance / face width
    private func calculateIPDRatio(landmarks: VNFaceLandmarks2D) -> Double {
        guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye,
              let contour = landmarks.faceContour else { return 0.45 }

        let leftCenter = centerOf(leftEye.normalizedPoints)
        let rightCenter = centerOf(rightEye.normalizedPoints)
        let ipd = abs(Double(rightCenter.x - leftCenter.x))

        let xs = contour.normalizedPoints.map { Double($0.x) }
        let faceWidth = (xs.max() ?? 0.8) - (xs.min() ?? 0.2)
        guard faceWidth > 0.1 else { return 0.45 }

        return ipd / faceWidth
    }

    /// Eye aspect ratio: height / width of the eye opening
    private func calculateEyeAspectRatio(landmarks: VNFaceLandmarks2D) -> Double {
        guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye else { return 0.33 }

        let leftAR = aspectRatio(of: leftEye.normalizedPoints)
        let rightAR = aspectRatio(of: rightEye.normalizedPoints)
        return (leftAR + rightAR) / 2.0
    }

    /// Nose width ratio: nose width / face width
    private func calculateNoseWidthRatio(landmarks: VNFaceLandmarks2D) -> Double {
        guard let nose = landmarks.nose, let contour = landmarks.faceContour else { return 0.25 }

        let noseXs = nose.normalizedPoints.map { Double($0.x) }
        let noseWidth = (noseXs.max() ?? 0.5) - (noseXs.min() ?? 0.5)

        let faceXs = contour.normalizedPoints.map { Double($0.x) }
        let faceWidth = (faceXs.max() ?? 0.8) - (faceXs.min() ?? 0.2)
        guard faceWidth > 0.1 else { return 0.25 }

        return noseWidth / faceWidth
    }

    /// Lip ratio: lip height / lip width
    private func calculateLipRatio(landmarks: VNFaceLandmarks2D) -> Double {
        guard let outerLips = landmarks.outerLips else { return 0.35 }

        let pts = outerLips.normalizedPoints
        let xs = pts.map { Double($0.x) }
        let ys = pts.map { Double($0.y) }
        let width = (xs.max() ?? 0.5) - (xs.min() ?? 0.5)
        let height = (ys.max() ?? 0.5) - (ys.min() ?? 0.5)
        guard width > 0.01 else { return 0.35 }

        return height / width
    }

    /// Philtrum ratio: estimated philtrum length / lower face third
    private func calculatePhiltrumRatio(landmarks: VNFaceLandmarks2D) -> Double {
        guard let nose = landmarks.nose, let outerLips = landmarks.outerLips,
              let contour = landmarks.faceContour else { return 0.32 }

        // Nose base (lowest nose point)
        let noseBaseY = Double(nose.normalizedPoints.map { $0.y }.min() ?? 0.4)

        // Upper lip (highest lip point)
        let upperLipY = Double(outerLips.normalizedPoints.map { $0.y }.max() ?? 0.35)

        // Chin (lowest contour point)
        let chinY = Double(contour.normalizedPoints.map { $0.y }.min() ?? 0.1)

        let philtrumLength = noseBaseY - upperLipY
        let lowerThird = noseBaseY - chinY
        guard lowerThird > 0.01 else { return 0.32 }

        return philtrumLength / lowerThird
    }

    /// Bilateral symmetry: compare left vs right face
    private func calculateSymmetry(landmarks: VNFaceLandmarks2D) -> Double {
        guard let contour = landmarks.faceContour else { return 0.85 }

        let points = contour.normalizedPoints

        // Find midline X
        let medianX: Double
        if let median = landmarks.medianLine {
            medianX = Double(centerOf(median.normalizedPoints).x)
        } else {
            let xs = points.map { Double($0.x) }
            medianX = ((xs.max() ?? 0.5) + (xs.min() ?? 0.5)) / 2.0
        }

        // Split contour into left and right halves
        let leftPoints = points.filter { Double($0.x) < medianX }
        let rightPoints = points.filter { Double($0.x) >= medianX }

        let pairCount = min(leftPoints.count, rightPoints.count)
        guard pairCount > 2 else { return 0.85 }

        // Mirror right points and compare distances
        var totalDeviation: Double = 0
        for i in 0..<pairCount {
            let lp = leftPoints[i]
            let rp = rightPoints[pairCount - 1 - i]
            let mirroredRX = 2.0 * medianX - Double(rp.x)
            let dx = Double(lp.x) - mirroredRX
            let dy = Double(lp.y) - Double(rp.y)
            totalDeviation += sqrt(dx * dx + dy * dy)
        }

        let avgDeviation = totalDeviation / Double(pairCount)
        // Map to 0-1 where 0 deviation = 1.0 symmetry
        return max(0, 1.0 - avgDeviation * 5.0)
    }

    /// Skin clarity: rough estimate from image variance in face region
    private func estimateSkinClarity(image: UIImage, boundingBox: CGRect) -> Double {
        guard let cgImage = image.cgImage else { return 5.5 }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Convert normalized bounding box to pixel coords
        let faceRect = CGRect(
            x: boundingBox.origin.x * imageWidth,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )

        guard let cropped = cgImage.cropping(to: faceRect) else { return 5.5 }

        // Sample pixels and measure color uniformity
        let width = cropped.width
        let height = cropped.height
        let totalPixels = width * height
        guard totalPixels > 100 else { return 5.5 }

        guard let data = cropped.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 5.5 }

        let bytesPerPixel = cropped.bitsPerPixel / 8
        let sampleStride = max(1, totalPixels / 500) // Sample ~500 pixels

        var luminances: [Double] = []
        for i in stride(from: 0, to: totalPixels, by: sampleStride) {
            let offset = i * bytesPerPixel
            guard offset + 2 < CFDataGetLength(data) else { break }
            let r = Double(bytes[offset])
            let g = Double(bytes[offset + 1])
            let b = Double(bytes[offset + 2])
            luminances.append((r + g + b) / 3.0)
        }

        guard luminances.count > 10 else { return 5.5 }

        // Calculate coefficient of variation (lower = more uniform = better skin)
        let mean = luminances.reduce(0, +) / Double(luminances.count)
        let variance = luminances.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(luminances.count)
        let cv = sqrt(variance) / max(mean, 1.0)

        // Map CV to score: 0.05 = excellent (9+), 0.15 = average (5), 0.30+ = poor (2)
        if cv < 0.05 { return 9.0 + (0.05 - cv) * 20 }
        if cv < 0.10 { return 7.0 + (0.10 - cv) * 40 }
        if cv < 0.18 { return 5.0 + (0.18 - cv) * 25 }
        if cv < 0.30 { return 3.0 + (0.30 - cv) * 16.7 }
        return max(1.5, 3.0 - (cv - 0.30) * 10)
    }

    // MARK: - Scoring Functions

    /// Score a metric against its ideal range using distance-based penalty
    private func scoreAgainstIdeal(
        value: Double,
        ideal: ClosedRange<Double>,
        acceptable: ClosedRange<Double>,
        penalty: Double = 1.0
    ) -> Double {
        // Perfect range → 8.5-10
        if ideal.contains(value) {
            let center = (ideal.lowerBound + ideal.upperBound) / 2.0
            let halfWidth = (ideal.upperBound - ideal.lowerBound) / 2.0
            let distFromCenter = abs(value - center) / halfWidth
            return 10.0 - distFromCenter * 1.5
        }

        // Acceptable range → 5.5-8.5
        if acceptable.contains(value) {
            let distFromIdeal: Double
            if value < ideal.lowerBound {
                distFromIdeal = (ideal.lowerBound - value) / (ideal.lowerBound - acceptable.lowerBound)
            } else {
                distFromIdeal = (value - ideal.upperBound) / (acceptable.upperBound - ideal.upperBound)
            }
            return 8.5 - distFromIdeal * 3.0
        }

        // Outside acceptable → 1-5.5
        let distOutside: Double
        if value < acceptable.lowerBound {
            distOutside = (acceptable.lowerBound - value) / acceptable.lowerBound
        } else {
            distOutside = (value - acceptable.upperBound) / acceptable.upperBound
        }
        return max(1.0, 5.5 - distOutside * 4.5 * penalty)
    }

    /// Gonial angle scoring (non-symmetric: sharp > obtuse)
    private func scoreGonialAngle(angle: Double) -> Double {
        // Optimal: 112-123° → 8.5-10
        if Ideals.gonialRange.contains(angle) {
            return 9.0 + (1.0 - abs(angle - 117.5) / 5.5)
        }
        // Acceptable: 108-130° → 6-8.5
        if Ideals.gonialAcceptable.contains(angle) {
            if angle < Ideals.gonialRange.lowerBound {
                return 8.5 - (Ideals.gonialRange.lowerBound - angle) / 4.0 * 2.5
            } else {
                return 8.5 - (angle - Ideals.gonialRange.upperBound) / 7.0 * 2.5
            }
        }
        // >130° is "less desirable" per the guide
        if angle > 130 {
            return max(2.0, 6.0 - (angle - 130) / 10.0 * 4.0)
        }
        return max(3.0, 6.0 - (108 - angle) / 10.0 * 3.0)
    }

    /// Jawline definition: estimated from contour sharpness
    private func estimateJawlineDefinition(landmarks: VNFaceLandmarks2D) -> Double {
        guard let contour = landmarks.faceContour else { return 5.5 }
        let points = contour.normalizedPoints
        guard points.count >= 10 else { return 5.5 }

        // Measure angular changes along the jawline (sharper transitions = better definition)
        var angleChanges: [Double] = []
        for i in 2..<points.count {
            let v1x = Double(points[i-1].x - points[i-2].x)
            let v1y = Double(points[i-1].y - points[i-2].y)
            let v2x = Double(points[i].x - points[i-1].x)
            let v2y = Double(points[i].y - points[i-1].y)

            let dot = v1x * v2x + v1y * v2y
            let cross = v1x * v2y - v1y * v2x
            let angle = abs(atan2(cross, dot))
            angleChanges.append(angle)
        }

        let maxAngleChange = angleChanges.max() ?? 0
        // Sharper angle changes ≈ more defined jawline
        // Map: 0.3+ radians = very defined (9+), <0.1 = round/undefined (3-5)
        let score = 3.0 + maxAngleChange * 20.0
        return score.smvClamped(to: 2.0...9.5)
    }

    /// Facial thirds scoring
    private func scoreThirds(deviation: Double) -> Double {
        // 0 deviation = perfect thirds = 10
        // 0.05 = small deviation = 7
        // 0.15+ = significant = 3
        if deviation < 0.02 { return 9.5 + (0.02 - deviation) * 25 }
        if deviation < 0.05 { return 7.0 + (0.05 - deviation) / 0.03 * 2.5 }
        if deviation < 0.10 { return 5.0 + (0.10 - deviation) / 0.05 * 2.0 }
        return max(2.0, 5.0 - (deviation - 0.10) * 30)
    }

    /// Symmetry scoring
    private func scoreSymmetry(ratio: Double) -> Double {
        // >0.95 = excellent, 0.92 = good, <0.80 = poor
        if ratio > 0.97 { return 9.5 + (ratio - 0.97) * 16.7 }
        if ratio > 0.92 { return 7.5 + (ratio - 0.92) / 0.05 * 2.0 }
        if ratio > 0.85 { return 5.0 + (ratio - 0.85) / 0.07 * 2.5 }
        return max(1.5, 5.0 - (0.85 - ratio) / 0.15 * 3.5)
    }

    /// Bell curve compression: prevents score inflation
    /// Most people should land 4-6. Elite (8+) is extremely rare.
    private func applyBellCurve(rawScore: Double) -> Double {
        // The raw weighted score tends to be 5-7 for most faces.
        // We compress the top end harder to match PSL distribution.
        //
        // Mapping:
        //   Raw 10 → Final ~9.5 (theoretical max)
        //   Raw 8  → Final ~7.5
        //   Raw 6  → Final ~5.5
        //   Raw 5  → Final ~4.5
        //   Raw 3  → Final ~2.5
        //   Raw 1  → Final ~1.5

        // Sigmoid-like compression
        let centered = rawScore - 5.5
        let compressed = centered * 0.85
        return compressed + 5.0
    }

    // MARK: - Geometry Helpers

    private func centerOf(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        let sumX = points.reduce(CGFloat(0)) { $0 + $1.x }
        let sumY = points.reduce(CGFloat(0)) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private func aspectRatio(of points: [CGPoint]) -> Double {
        let xs = points.map { Double($0.x) }
        let ys = points.map { Double($0.y) }
        let width = (xs.max() ?? 0.5) - (xs.min() ?? 0.5)
        let height = (ys.max() ?? 0.5) - (ys.min() ?? 0.5)
        guard width > 0.001 else { return 0.33 }
        return height / width
    }
}
