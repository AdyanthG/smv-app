//
//  FaceAnalysisService.swift
//  SMV
//
//  PSL-accurate facial analysis engine with quality validation.
//  Measures real biometric ratios from Vision landmarks and scores
//  against looksmaxxing community standards.
//
//  Quality gates: Face must be frontal, upright, properly lit, and
//  undistorted. Bad angles, puffed cheeks, head tilts, and partial
//  faces are detected and penalized.
//
//  Metrics: FWHR, canthal tilt, gonial angle, facial thirds,
//  IPD ratio, eye aspect ratio, nose width ratio, lip ratio,
//  philtrum ratio, bilateral symmetry.
//
//  Scoring: bell-curve distribution. No floor. Honest ratings.
//

import Vision
import UIKit

// MARK: - Face Quality Assessment

struct FaceQuality {
    let yaw: Double          // Head rotation left/right (degrees, 0 = frontal)
    let roll: Double         // Head tilt (degrees, 0 = upright)
    let faceAreaRatio: Double // Face bbox area / image area (too small = too far)
    let landmarkConfidence: Float
    let isValid: Bool
    let issues: [String]
    let qualityMultiplier: Double // 0-1, applied to final score
}

struct FaceMetrics {
    // Quality assessment
    let quality: FaceQuality

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

    func analyze(image: UIImage, userId: String, isAngled: Bool = false) async -> ScanResult? {
        errorMessage = nil

        guard let cgImage = image.cgImage else {
            errorMessage = "Invalid image"
            return nil
        }

        // Run face detection with quality metrics
        let request = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)

        do {
            try handler.perform([request, qualityRequest])
        } catch {
            errorMessage = "Face detection failed: \(error.localizedDescription)"
            return nil
        }

        guard let observation = request.results?.first,
              let landmarks = observation.landmarks else {
            // For angled captures, failing to detect is OK — skip silently
            if isAngled { return nil }
            errorMessage = "No face detected. Please try again with better lighting."
            return nil
        }

        // Get capture quality from Apple's quality assessment
        let captureQuality = qualityRequest.results?.first?.faceCaptureQuality ?? 0.5

        let metrics = analyzeFace(
            landmarks: landmarks,
            boundingBox: observation.boundingBox,
            image: image,
            captureQuality: Float(captureQuality),
            yaw: observation.yaw?.doubleValue,
            roll: observation.roll?.doubleValue,
            isAngled: isAngled
        )

        // Block clearly invalid scans (but not for intentional angled captures)
        if !isAngled && !metrics.quality.isValid {
            errorMessage = "Poor scan quality: \(metrics.quality.issues.joined(separator: ", ")). Please face the camera straight-on in good lighting."
            return nil
        }

        let imageData = image.jpegData(compressionQuality: 0.7)
        return ScanResult(userId: userId, metrics: metrics, imageData: imageData)
    }

    // MARK: - Ideal Ranges (from PSL community standards + looksmax.org guide)

    private struct Ideals {
        // FWHR: "Among attractive men, ratios ranging from 1.9 to 2.05"
        static let fwhrRange: ClosedRange<Double> = 1.85...2.10
        static let fwhrAcceptable: ClosedRange<Double> = 1.65...2.25

        // Canthal Tilt: "ideal falls within 5-7 degrees, slightly positive"
        static let canthalRange: ClosedRange<Double> = 4.0...8.0
        static let canthalAcceptable: ClosedRange<Double> = 0.0...12.0

        // Gonial Angle: "optimal 112-123 degrees, up to 126 acceptable, >130 undesirable"
        static let gonialRange: ClosedRange<Double> = 110.0...125.0
        static let gonialAcceptable: ClosedRange<Double> = 105.0...135.0

        // Facial Thirds: equal = 0 deviation
        static let thirdsMaxDeviation: Double = 0.05

        // IPD: typical attractive ratio
        static let ipdRange: ClosedRange<Double> = 0.40...0.50

        // Eye Aspect Ratio: almond shape
        static let eyeAspectRange: ClosedRange<Double> = 0.25...0.40

        // Nose Width: "should fit between the eyes"
        static let noseWidthRange: ClosedRange<Double> = 0.20...0.30

        // Lip fullness
        static let lipRange: ClosedRange<Double> = 0.25...0.45

        // Philtrum-to-chin
        static let philtrumRange: ClosedRange<Double> = 0.25...0.38

        // Symmetry: >90% is good
        static let symmetryThreshold: Double = 0.90
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
        image: UIImage,
        captureQuality: Float = 0.5,
        yaw: Double? = nil,
        roll: Double? = nil,
        isAngled: Bool = false
    ) -> FaceMetrics {

        // ── Step 0: Quality Gate ──
        let quality = assessQuality(
            landmarks: landmarks,
            boundingBox: boundingBox,
            captureQuality: captureQuality,
            yaw: yaw,
            roll: roll,
            isAngled: isAngled
        )

        // ── Step 1: Extract raw measurements ──
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

        // ── Step 2: Detect distortion (puffed cheeks, fish face, etc.) ──
        let distortionPenalty = detectDistortion(
            fwhr: fwhr,
            lipRatio: lipRatio,
            noseWidth: noseWidth,
            jawAngle: gonialAngle,
            landmarks: landmarks
        )

        // ── Step 3: Score each metric against ideals (0-10 scale) ──
        let canthalScore = scoreAgainstIdeal(
            value: canthalTilt,
            ideal: Ideals.canthalRange,
            acceptable: Ideals.canthalAcceptable,
            penalty: 1.5
        )
        let eyeAspectScore = scoreAgainstIdeal(
            value: eyeAspect,
            ideal: Ideals.eyeAspectRange,
            acceptable: 0.18...0.50,
            penalty: 1.0
        )
        let ipdScore = scoreAgainstIdeal(
            value: ipdRatio,
            ideal: Ideals.ipdRange,
            acceptable: 0.35...0.55,
            penalty: 0.8
        )
        let eyeAreaScore = (canthalScore * 0.45 + eyeAspectScore * 0.35 + ipdScore * 0.20)

        let gonialScore = scoreGonialAngle(angle: gonialAngle)
        let jawDefinitionScore = estimateJawlineDefinition(landmarks: landmarks)
        let jawScore = gonialScore * 0.6 + jawDefinitionScore * 0.4

        let fwhrScore = scoreAgainstIdeal(
            value: fwhr,
            ideal: Ideals.fwhrRange,
            acceptable: Ideals.fwhrAcceptable,
            penalty: 1.0
        )
        let thirdsScore = scoreThirds(deviation: thirdsDeviation)
        let harmonyScore = fwhrScore * 0.5 + thirdsScore * 0.5

        let symmetryRating = scoreSymmetry(ratio: symmetry)

        let noseScore = scoreAgainstIdeal(
            value: noseWidth,
            ideal: Ideals.noseWidthRange,
            acceptable: 0.15...0.38,
            penalty: 0.8
        )
        let lipScore = scoreAgainstIdeal(
            value: lipRatio,
            ideal: Ideals.lipRange,
            acceptable: 0.18...0.55,
            penalty: 0.8
        )
        let philtrumScore = scoreAgainstIdeal(
            value: philtrumRatio,
            ideal: Ideals.philtrumRange,
            acceptable: 0.18...0.45,
            penalty: 0.8
        )
        let proportionsScore = noseScore * 0.40 + lipScore * 0.30 + philtrumScore * 0.30

        // Skin clarity — rough estimate from image uniformity
        let skinClarityScore = estimateSkinClarity(image: image, boundingBox: boundingBox)

        // ── Step 4: Detect failos ──
        var failos: [String] = []
        let failoThreshold: Double = 2.5

        if eyeAreaScore < failoThreshold { failos.append("Eye Area") }
        if jawScore < failoThreshold { failos.append("Jawline") }
        if symmetryRating < failoThreshold { failos.append("Symmetry") }
        if harmonyScore < failoThreshold { failos.append("Harmony") }
        if proportionsScore < failoThreshold { failos.append("Proportions") }
        if skinClarityScore < failoThreshold { failos.append("Skin Clarity") }

        let failoPenalty: Double
        switch failos.count {
        case 0:    failoPenalty = 1.0
        case 1:    failoPenalty = 0.95
        case 2:    failoPenalty = 0.90
        default:   failoPenalty = 0.85
        }

        // ── Step 5: Weighted composite ──
        // Use ALL metrics for all angles — this is the whole point of multi-angle scanning
        let rawComposite =
            eyeAreaScore * Weights.eyeArea +
            jawScore * Weights.jaw +
            symmetryRating * Weights.symmetry +
            harmonyScore * Weights.harmony +
            proportionsScore * Weights.proportions +
            skinClarityScore * Weights.skinClarity

        // ── Step 6: Apply bell curve + dampened penalties ──
        let bellCurved = applyBellCurve(rawScore: rawComposite)
        // Dampen quality penalty: half-weight so bad lighting doesn't destroy the score
        let qualityAdjusted = bellCurved * (0.5 + quality.qualityMultiplier * 0.5)
        // Dampen distortion penalty similarly
        let distortionAdjusted = qualityAdjusted * (0.6 + distortionPenalty * 0.4)
        let finalScore = (distortionAdjusted * failoPenalty).smvClamped(to: 1.0...10.0)

        return FaceMetrics(
            quality: quality,
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
            eyeAreaScore: eyeAreaScore.smvClamped(to: 0.0...10.0),
            jawScore: jawScore.smvClamped(to: 0.0...10.0),
            harmonyScore: harmonyScore.smvClamped(to: 0.0...10.0),
            symmetryRating: symmetryRating.smvClamped(to: 0.0...10.0),
            skinClarityScore: skinClarityScore.smvClamped(to: 0.0...10.0),
            proportionsScore: proportionsScore.smvClamped(to: 0.0...10.0),
            failos: failos,
            failoPenalty: failoPenalty,
            overallScore: finalScore
        )
    }

    // MARK: - Quality Assessment

    /// Validates face orientation, size, and capture quality.
    /// Returns a multiplier (0-1) that penalizes bad scans.
    private func assessQuality(
        landmarks: VNFaceLandmarks2D,
        boundingBox: CGRect,
        captureQuality: Float,
        yaw: Double?,
        roll: Double?,
        isAngled: Bool = false
    ) -> FaceQuality {

        var issues: [String] = []
        var multiplier: Double = 1.0

        // ── Yaw (head turned left/right) ──
        // Vision yaw: 0 = frontal, positive = turned right, negative = turned left
        // Skip this penalty for intentional angled captures (multi-angle scan)
        let yawDeg = abs((yaw ?? 0) * (180.0 / .pi))
        if !isAngled {
            if yawDeg > 25 {
                issues.append("Turn your face toward the camera")
                multiplier *= 0.7
            } else if yawDeg > 15 {
                issues.append("Face slightly angled")
                multiplier *= 0.88
            } else if yawDeg > 8 {
                // Minor angle — small penalty
                multiplier *= 0.95
            }
        }

        // ── Roll (head tilted sideways) ──
        // Also skip for angled captures
        let rollDeg = abs((roll ?? 0) * (180.0 / .pi))
        if !isAngled {
            if rollDeg > 20 {
                issues.append("Straighten your head")
                multiplier *= 0.75
            } else if rollDeg > 10 {
                issues.append("Slight head tilt")
                multiplier *= 0.90
            }
        }

        // ── Face size (too far / too close) ──
        let faceArea = Double(boundingBox.width * boundingBox.height)
        if faceArea < 0.04 {
            issues.append("Move closer to the camera")
            multiplier *= 0.80
        } else if faceArea < 0.08 {
            multiplier *= 0.92
        } else if faceArea > 0.65 {
            issues.append("Move slightly further from camera")
            multiplier *= 0.90
        }

        // ── Apple's capture quality score ──
        if captureQuality < 0.2 {
            issues.append("Poor lighting or blurry image")
            multiplier *= 0.75
        } else if captureQuality < 0.4 {
            multiplier *= 0.90
        }

        // ── Landmark completeness check ──
        let hasEyes = landmarks.leftEye != nil && landmarks.rightEye != nil
        let hasNose = landmarks.nose != nil
        let hasLips = landmarks.outerLips != nil
        let hasBrows = landmarks.leftEyebrow != nil && landmarks.rightEyebrow != nil
        let hasContour = landmarks.faceContour != nil

        let landmarkCount = [hasEyes, hasNose, hasLips, hasBrows, hasContour].filter { $0 }.count
        if landmarkCount < 4 {
            issues.append("Face partially obscured")
            multiplier *= 0.70
        }

        // ── Determine validity ──
        // Block scan if quality is extremely poor
        let isValid = multiplier > 0.50 && landmarkCount >= 3

        return FaceQuality(
            yaw: yawDeg,
            roll: rollDeg,
            faceAreaRatio: faceArea,
            landmarkConfidence: captureQuality,
            isValid: isValid,
            issues: issues,
            qualityMultiplier: multiplier
        )
    }

    // MARK: - Distortion Detection

    /// Detects unnatural facial distortion (puffed cheeks, fish face,
    /// double chin, tongue out, etc.) by checking for implausible ratio combinations.
    private func detectDistortion(
        fwhr: Double,
        lipRatio: Double,
        noseWidth: Double,
        jawAngle: Double,
        landmarks: VNFaceLandmarks2D
    ) -> Double {
        var penalty: Double = 1.0

        // ── Puffed cheeks: abnormally wide face ──
        // Lowered thresholds — puffed cheeks often land 2.0-2.3
        if fwhr > 2.20 {
            penalty *= max(0.60, 1.0 - (fwhr - 2.20) * 1.8)
        } else if fwhr > 2.10 {
            penalty *= max(0.80, 1.0 - (fwhr - 2.10) * 1.2)
        }

        // ── Fish face / duck lips ──
        if lipRatio > 0.50 {
            penalty *= max(0.65, 1.0 - (lipRatio - 0.50) * 2.5)
        }

        // ── Cross-validate: wide face + compressed nose = cheek puffing ──
        if fwhr > 2.05 && noseWidth < 0.20 {
            penalty *= 0.82
        }

        // ── Double chin detection ──
        // A double chin causes the jaw contour to sag downward.
        // Measured by comparing the lowest contour point to the chin baseline.
        if let contour = landmarks.faceContour, let nose = landmarks.nose {
            let contourPts = contour.normalizedPoints
            let nosePts = nose.normalizedPoints

            if contourPts.count >= 8 && nosePts.count >= 2 {
                // Jaw bottom: lowest Y on face contour
                let jawBottomY = contourPts.map { Double($0.y) }.min() ?? 0
                // Nose bottom: lowest Y on nose
                let noseBottomY = nosePts.map { Double($0.y) }.min() ?? 0
                // Face contour top points (sides of face near ears)
                let contourTopY = contourPts.map { Double($0.y) }.max() ?? 0

                let faceHeight = contourTopY - jawBottomY
                let noseToJaw = noseBottomY - jawBottomY

                // In a normal face, nose-to-jaw is ~25-35% of face height.
                // A double chin extends the jaw contour downward, making this ratio > 40%.
                if faceHeight > 0 {
                    let chinRatio = noseToJaw / faceHeight
                    if chinRatio > 0.45 {
                        // Severe double chin — strong penalty
                        penalty *= max(0.60, 1.0 - (chinRatio - 0.45) * 4.0)
                    } else if chinRatio > 0.38 {
                        // Mild double chin
                        penalty *= max(0.82, 1.0 - (chinRatio - 0.38) * 2.5)
                    }
                }

                // Also check contour width vs height ratio
                // Puffed cheeks make the contour very wide relative to height
                let contourXs = contourPts.map { Double($0.x) }
                let contourWidth = (contourXs.max() ?? 0) - (contourXs.min() ?? 0)
                if faceHeight > 0 {
                    let widthToHeight = contourWidth / faceHeight
                    // Normal is ~0.7-0.9, puffed cheeks push > 1.0
                    if widthToHeight > 1.05 {
                        penalty *= max(0.65, 1.0 - (widthToHeight - 1.05) * 3.0)
                    } else if widthToHeight > 0.95 {
                        penalty *= max(0.85, 1.0 - (widthToHeight - 0.95) * 1.5)
                    }
                }
            }
        }

        // ── Mouth gaping ──
        if let outerLips = landmarks.outerLips, let innerLips = landmarks.innerLips {
            let outerPts = outerLips.normalizedPoints
            let innerPts = innerLips.normalizedPoints

            let outerYs = outerPts.map { Double($0.y) }
            let innerYs = innerPts.map { Double($0.y) }

            let outerHeight = (outerYs.max() ?? 0) - (outerYs.min() ?? 0)
            let innerHeight = (innerYs.max() ?? 0) - (innerYs.min() ?? 0)

            if innerHeight > 0.02 && outerHeight > 0 && innerHeight / outerHeight > 0.45 {
                penalty *= 0.82
            }
        }

        return penalty.smvClamped(to: 0.40...1.0)
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

        // For each eye, identify the medial (inner) and lateral (outer) canthus.
        // Vision provides points roughly in order around the eye.
        // Inner corner = closest to midline, outer = farthest from midline.
        let faceMidX = (centerOf(leftPts).x + centerOf(rightPts).x) / 2.0

        // Left eye: inner = closest to midline (highest x), outer = lowest x
        let leftInner = leftPts.max(by: { $0.x < $1.x }) ?? leftPts[0]
        let leftOuter = leftPts.min(by: { $0.x < $1.x }) ?? leftPts[leftPts.count / 2]

        // Right eye: inner = closest to midline (lowest x), outer = highest x
        let rightInner = rightPts.min(by: { $0.x < $1.x }) ?? rightPts[0]
        let rightOuter = rightPts.max(by: { $0.x < $1.x }) ?? rightPts[rightPts.count / 2]

        // Tilt = angle from inner to outer (positive = outer higher than inner)
        let leftAngle = atan2(Double(leftOuter.y - leftInner.y), Double(leftInner.x - leftOuter.x))
        let rightAngle = atan2(Double(rightOuter.y - rightInner.y), Double(rightOuter.x - rightInner.x))

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

        // Use the left side for angle calculation
        let ramus = points[leftGonionIdx] // approximate gonion
        let chin = points[chinIndex]

        // Angle formed at the gonion
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

        let browY: Double
        if let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow {
            let browPoints = leftBrow.normalizedPoints + rightBrow.normalizedPoints
            browY = Double(browPoints.map { $0.y }.max() ?? faceTop)
        } else {
            browY = faceTop - faceHeight * 0.33
        }

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
        return deviation / 2.0
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

        let noseBaseY = Double(nose.normalizedPoints.map { $0.y }.min() ?? 0.4)
        let upperLipY = Double(outerLips.normalizedPoints.map { $0.y }.max() ?? 0.35)
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

        let leftPoints = points.filter { Double($0.x) < medianX }
        let rightPoints = points.filter { Double($0.x) >= medianX }

        let pairCount = min(leftPoints.count, rightPoints.count)
        guard pairCount > 2 else { return 0.85 }

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
        // Reduced multiplier: 3.0 instead of 5.0
        // Even well-symmetric faces have 0.05-0.10 deviation from 2D landmark noise.
        // 5.0× was making slightly asymmetric faces (0.17 dev) score near 0.
        return max(0, 1.0 - avgDeviation * 3.0)
    }

    /// Skin clarity: rough estimate from image variance in face region
    private func estimateSkinClarity(image: UIImage, boundingBox: CGRect) -> Double {
        guard let cgImage = image.cgImage else { return 5.5 }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        let faceRect = CGRect(
            x: boundingBox.origin.x * imageWidth,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )

        guard let cropped = cgImage.cropping(to: faceRect) else { return 5.5 }

        let width = cropped.width
        let height = cropped.height
        let totalPixels = width * height
        guard totalPixels > 100 else { return 5.5 }

        guard let data = cropped.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 5.5 }

        let bytesPerPixel = cropped.bitsPerPixel / 8
        let sampleStride = max(1, totalPixels / 500)

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

        let mean = luminances.reduce(0, +) / Double(luminances.count)
        let variance = luminances.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(luminances.count)
        let cv = sqrt(variance) / max(mean, 1.0)

        // Too-low CV can indicate flat/washed-out image (ring light blowout, puffed cheeks)
        // Natural skin has SOME texture variation. Penalize both extremes.
        // Skin clarity scoring:
        // Low CV (uniform brightness) → smooth skin → high score
        // High CV (lots of variation) can mean texture/acne OR just dim/mixed lighting
        // Don't punish high CV too harshly — dim lighting naturally increases CV
        if cv < 0.03 {
            // Suspiciously uniform — likely blown out or distorted
            return 6.0
        }
        if cv < 0.06 { return 8.0 + (0.06 - cv) / 0.03 * 1.5 }
        if cv < 0.12 { return 6.5 + (0.12 - cv) / 0.06 * 1.5 }
        if cv < 0.22 { return 5.0 + (0.22 - cv) / 0.10 * 1.5 }
        if cv < 0.35 { return 4.0 + (0.35 - cv) / 0.13 * 1.0 }
        return max(3.0, 4.0 - (cv - 0.35) * 5)
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
        if Ideals.gonialRange.contains(angle) {
            return 9.0 + (1.0 - abs(angle - 117.5) / 5.5)
        }
        if Ideals.gonialAcceptable.contains(angle) {
            if angle < Ideals.gonialRange.lowerBound {
                return 8.5 - (Ideals.gonialRange.lowerBound - angle) / 4.0 * 2.5
            } else {
                return 8.5 - (angle - Ideals.gonialRange.upperBound) / 7.0 * 2.5
            }
        }
        if angle > 130 {
            return max(2.0, 6.0 - (angle - 130) / 10.0 * 4.0)
        }
        return max(3.0, 6.0 - (108 - angle) / 10.0 * 3.0)
    }

    /// Jawline definition: estimated from contour sharpness
    /// Fixed: uses median angle change instead of max to prevent distortion boosting
    private func estimateJawlineDefinition(landmarks: VNFaceLandmarks2D) -> Double {
        guard let contour = landmarks.faceContour else { return 5.5 }
        let points = contour.normalizedPoints
        guard points.count >= 10 else { return 5.5 }

        // Measure angular changes along the jawline
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

        guard !angleChanges.isEmpty else { return 5.5 }

        // Use the 75th percentile angle change (not max).
        // Max is easily gamed by puffing cheeks which creates ONE sharp transition.
        // A truly defined jawline has CONSISTENT sharpness across multiple points.
        let sorted = angleChanges.sorted()
        let p75Index = Int(Double(sorted.count) * 0.75)
        let p75Angle = sorted[min(p75Index, sorted.count - 1)]

        // Also check consistency: std deviation of angle changes
        // Low std dev = smooth, consistent jaw (good). High = irregular (bad/distorted).
        let mean = angleChanges.reduce(0, +) / Double(angleChanges.count)
        let variance = angleChanges.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(angleChanges.count)
        let stdDev = sqrt(variance)

        // Consistency bonus/penalty (0.75 - 1.05)
        let consistencyFactor: Double
        if stdDev < 0.04 {
            // VERY uniform curvature = likely a round/bloated face (puffed cheeks)
            // Real defined jawlines have SOME variation (sharp jaw corners vs straight lines)
            consistencyFactor = 0.85
        } else if stdDev < 0.08 {
            consistencyFactor = 1.05  // Some variation = good, natural jaw
        } else if stdDev < 0.15 {
            consistencyFactor = 0.95  // Moderate variation
        } else if stdDev < 0.25 {
            consistencyFactor = 0.85  // Somewhat irregular
        } else {
            consistencyFactor = 0.75  // Very irregular (likely distorted)
        }

        // Check for chin sag (double chin): compare the midpoint Y of contour 
        // to the endpoints Y — a sagging chin drops the middle well below the ear line
        let midIndex = points.count / 2
        let midY = Double(points[midIndex].y)
        let leftEarY = Double(points[0].y)
        let rightEarY = Double(points[points.count - 1].y)
        let earLineY = (leftEarY + rightEarY) / 2.0
        let chinDrop = earLineY - midY  // positive = chin below ears (Vision coords: 0=bottom)

        var chinPenalty: Double = 1.0
        // In normalized coords, large chinDrop means chin hangs well below ears
        if chinDrop > 0.25 {
            chinPenalty = max(0.70, 1.0 - (chinDrop - 0.25) * 3.0)
        }

        // Score from 75th percentile angle
        let rawScore = 3.0 + p75Angle * 18.0
        return (rawScore * consistencyFactor * chinPenalty).smvClamped(to: 2.0...9.0)
    }

    /// Facial thirds scoring
    private func scoreThirds(deviation: Double) -> Double {
        if deviation < 0.02 { return 9.5 + (0.02 - deviation) * 25 }
        if deviation < 0.05 { return 7.0 + (0.05 - deviation) / 0.03 * 2.5 }
        if deviation < 0.10 { return 5.0 + (0.10 - deviation) / 0.05 * 2.0 }
        return max(2.0, 5.0 - (deviation - 0.10) * 30)
    }

    /// Symmetry scoring
    private func scoreSymmetry(ratio: Double) -> Double {
        if ratio > 0.97 { return 9.5 + (ratio - 0.97) * 16.7 }
        if ratio > 0.92 { return 7.5 + (ratio - 0.92) / 0.05 * 2.0 }
        if ratio > 0.85 { return 5.0 + (ratio - 0.85) / 0.07 * 2.5 }
        return max(1.5, 5.0 - (0.85 - ratio) / 0.15 * 3.5)
    }

    /// Bell curve shaping with wider spread.
    /// Uses steeper sigmoid so scores differentiate more clearly.
    /// Most people land 4-6. Attractive 6.5-8. Elite 8-9.5.
    private func applyBellCurve(rawScore: Double) -> Double {
        // Steeper sigmoid for better differentiation at extremes
        let k = 0.65
        let midpoint = 5.0
        let sigmoid = 1.0 / (1.0 + exp(-k * (rawScore - midpoint)))
        // Map sigmoid (0-1) to score (2.0-9.5) — higher floor, realistic range
        return 2.0 + sigmoid * 7.5
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
