//
//  FaceTrackingService.swift
//  SMV
//
//  ARKit-powered TrueDepth face tracking for multi-angle guided scanning.
//  Uses ARFaceTrackingConfiguration to get real-time head pose (yaw/pitch/roll),
//  face mesh geometry, and depth data from the TrueDepth camera.
//
//  Falls back gracefully on devices without TrueDepth.
//

import ARKit
import UIKit
import Combine

// MARK: - Guided Scan Position

enum ScanPosition: Int, CaseIterable {
    case front = 0
    case left = 1
    case right = 2
    case up = 3
    case down = 4

    var label: String {
        switch self {
        case .front: return "Look Straight"
        case .left:  return "Turn Left"
        case .right: return "Turn Right"
        case .up:    return "Look Up"
        case .down:  return "Look Down"
        }
    }

    var icon: String {
        switch self {
        case .front: return "face.smiling"
        case .left:  return "arrow.left"
        case .right: return "arrow.right"
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        }
    }

    /// Target yaw/pitch in radians (relative to baseline)
    var targetYaw: Double {
        switch self {
        case .front: return 0
        case .left:  return 0.26    // ~15 degrees left
        case .right: return -0.26   // ~15 degrees right
        case .up:    return 0
        case .down:  return 0
        }
    }

    var targetPitch: Double {
        switch self {
        case .front: return 0
        case .left:  return 0
        case .right: return 0
        case .up:    return -0.21   // ~12 degrees chin up (negative pitch = looking up in ARKit)
        case .down:  return 0.21    // ~12 degrees chin down
        }
    }

    /// Tolerance in radians for considering the position "aligned"
    var yawTolerance: Double {
        switch self {
        case .front: return 0.17    // ~10 degrees — must be roughly straight
        default:     return 0.18    // ~10 degrees around target
        }
    }

    var pitchTolerance: Double {
        switch self {
        case .front: return 0.17    // ~10 degrees
        default:     return 0.18    // ~10 degrees around target
        }
    }
}

// MARK: - Capture Data

struct AngleCapture {
    let position: ScanPosition
    let image: UIImage
    let yaw: Double
    let pitch: Double
    let roll: Double
    let faceAnchor: ARFaceAnchor?
}

// MARK: - FaceTrackingService

@Observable
final class FaceTrackingService: NSObject {

    // ── State ──
    var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }
    var isFaceDetected: Bool = false
    var isAligned: Bool = false
    var alignmentProgress: Double = 0
    var currentPosition: ScanPosition = .front
    var captures: [AngleCapture] = []
    var isComplete: Bool = false
    var isCalibrated: Bool = false

    // Angles for analysis (raw world-space, stored in captures)
    var currentYaw: Double = 0
    var currentPitch: Double = 0
    var currentRoll: Double = 0

    // Relative angles (delta from baseline) — used for alignment & debug display
    var relativeYaw: Double = 0
    var relativePitch: Double = 0

    // ── Baseline Calibration ──
    // Uses the nose direction vector (face’s Z-axis) instead of Euler angles.
    // Averaged over multiple frames for stability.
    private var baselineYaw: Double = 0
    private var baselinePitch: Double = 0
    private var calibrationSamples: [(yaw: Double, pitch: Double)] = []
    private let calibrationFrameCount = 15

    // ── AR Session ──
    let arSession = ARSession()
    weak var arView: ARSCNView?
    private var alignedSince: Date?
    private let requiredHoldDuration: TimeInterval = 0.5
    private var displayLink: CADisplayLink?
    private var lastFaceAnchor: ARFaceAnchor?

    // ── Callbacks ──
    var onCaptureComplete: (([AngleCapture]) -> Void)?

    override init() {
        super.init()
        arSession.delegate = self
    }

    // MARK: - Lifecycle

    func startSession() {
        guard isSupported else { return }

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        if #available(iOS 16.0, *) {
            config.videoHDRAllowed = true
        }
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])

        displayLink = CADisplayLink(target: self, selector: #selector(trackingLoop))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopSession() {
        arSession.pause()
        displayLink?.invalidate()
        displayLink = nil
        alignedSince = nil
    }

    func reset() {
        captures = []
        currentPosition = .front
        isComplete = false
        isCalibrated = false
        alignedSince = nil
        alignmentProgress = 0
        relativeYaw = 0
        relativePitch = 0
        baselineYaw = 0
        baselinePitch = 0
        calibrationSamples = []
    }

    // MARK: - Tracking Loop

    @objc private func trackingLoop() {
        guard isFaceDetected else {
            isAligned = false
            alignmentProgress = 0
            alignedSince = nil
            return
        }

        // ── Phase 1: Calibration ──
        // Collect N frames to establish a stable baseline
        if !isCalibrated {
            calibrationSamples.append((yaw: currentYaw, pitch: currentPitch))
            if calibrationSamples.count >= calibrationFrameCount {
                // Average all samples for stability
                let yawSum = calibrationSamples.reduce(0.0) { $0 + $1.yaw }
                let pitchSum = calibrationSamples.reduce(0.0) { $0 + $1.pitch }
                baselineYaw = yawSum / Double(calibrationSamples.count)
                baselinePitch = pitchSum / Double(calibrationSamples.count)
                isCalibrated = true
            }
            return
        }

        // ── Phase 2: Compute relative angles ──
        relativeYaw = currentYaw - baselineYaw
        relativePitch = currentPitch - baselinePitch

        // ── Phase 3: Check alignment against target ──
        let yawDiff = abs(relativeYaw - currentPosition.targetYaw)
        let pitchDiff = abs(relativePitch - currentPosition.targetPitch)

        let aligned = yawDiff < currentPosition.yawTolerance
                   && pitchDiff < currentPosition.pitchTolerance

        if aligned {
            if alignedSince == nil {
                alignedSince = Date()
            }
            let held = Date().timeIntervalSince(alignedSince!)
            alignmentProgress = min(1.0, held / requiredHoldDuration)
            isAligned = true

            if held >= requiredHoldDuration {
                captureCurrentPosition()
            }
        } else {
            alignedSince = nil
            alignmentProgress = 0
            isAligned = false
        }
    }

    // MARK: - Capture

    private func captureCurrentPosition() {
        // Prevent double-capture
        guard !captures.contains(where: { $0.position == currentPosition }) else { return }

        // Capture using ARSCNView snapshot (exact on-screen image, correct orientation)
        // Falls back to pixel buffer conversion if arView is unavailable
        let image: UIImage
        if let arView = arView {
            image = arView.snapshot()
        } else if let frame = arSession.currentFrame {
            image = imageFromPixelBuffer(frame.capturedImage)
        } else {
            return
        }

        let capture = AngleCapture(
            position: currentPosition,
            image: image,
            yaw: currentYaw,
            pitch: currentPitch,
            roll: currentRoll,
            faceAnchor: lastFaceAnchor
        )
        captures.append(capture)

        // Advance to next position
        let nextIndex = currentPosition.rawValue + 1
        if nextIndex < ScanPosition.allCases.count {
            currentPosition = ScanPosition.allCases[nextIndex]
            alignedSince = nil
            alignmentProgress = 0
            isAligned = false
        } else {
            // All positions captured
            isComplete = true
            stopSession()
            onCaptureComplete?(captures)
        }
    }

    // MARK: - 3D Metrics from Face Mesh

    /// Extract depth-based metrics from the ARFaceAnchor geometry
    func extract3DMetrics(from captures: [AngleCapture]) -> DepthMetrics {
        // Use the frontal capture's face anchor for mesh analysis
        guard let frontalCapture = captures.first(where: { $0.position == .front }),
              let anchor = frontalCapture.faceAnchor else {
            return DepthMetrics()
        }

        let geometry = anchor.geometry
        let vertices = geometry.vertices

        // ── Nose projection depth ──
        // The nose tip vertex (approximate center of face mesh) protrudes furthest in Z
        let noseTip = vertices.max(by: { $0.z < $1.z })
        let noseProjection = Double(noseTip?.z ?? 0)

        // ── Jawline depth from side captures ──
        var jawlineDepth: Double = 0
        if let leftCapture = captures.first(where: { $0.position == .left }),
           let leftAnchor = leftCapture.faceAnchor {
            // When turned left, the right jaw edge is more visible
            let leftVerts = leftAnchor.geometry.vertices
            let zRange = leftVerts.map { Double($0.z) }
            jawlineDepth = (zRange.max() ?? 0) - (zRange.min() ?? 0)
        }

        // ── Facial volume estimate (total mesh bounding box) ──
        let xs = vertices.map { Double($0.x) }
        let ys = vertices.map { Double($0.y) }
        let zs = vertices.map { Double($0.z) }
        let xRange: Double = (xs.max() ?? 0) - (xs.min() ?? 0)
        let yRange: Double = (ys.max() ?? 0) - (ys.min() ?? 0)
        let zRange2: Double = (zs.max() ?? 0) - (zs.min() ?? 0)
        let volume: Double = xRange * yRange * zRange2

        // ── 3D symmetry (compare left vs right vertices) ──
        var symmetrySum: Double = 0
        var pairCount: Int = 0
        for vertex in vertices {
            let mirrorX: Float = -vertex.x
            let vy: Float = vertex.y
            let vz: Float = vertex.z
            if let closest = vertices.min(by: {
                let d1: Float = ($0.x - mirrorX) * ($0.x - mirrorX) + ($0.y - vy) * ($0.y - vy) + ($0.z - vz) * ($0.z - vz)
                let d2: Float = ($1.x - mirrorX) * ($1.x - mirrorX) + ($1.y - vy) * ($1.y - vy) + ($1.z - vz) * ($1.z - vz)
                return d1 < d2
            }) {
                let dx = Double(closest.x) - Double(mirrorX)
                let dy = Double(closest.y) - Double(vy)
                let dz = Double(closest.z) - Double(vz)
                let dist = sqrt(dx * dx + dy * dy + dz * dz)
                symmetrySum += dist
                pairCount += 1
            }
        }
        let symmetry3D: Double = pairCount > 0 ? max(0, 1.0 - (symmetrySum / Double(pairCount)) * 20) : 0.85

        return DepthMetrics(
            noseProjection: noseProjection,
            jawlineDepth: jawlineDepth,
            facialVolume: volume,
            symmetry3D: symmetry3D
        )
    }

    // MARK: - Pixel Buffer to UIImage

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        // Front TrueDepth camera in portrait: sensor is landscape-left,
        // so the buffer needs .rightMirrored (rotate right + mirror for front cam)
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .rightMirrored)
    }
}

// MARK: - ARSessionDelegate

extension FaceTrackingService: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            isFaceDetected = false
            return
        }

        isFaceDetected = true
        lastFaceAnchor = faceAnchor

        // ── Extract yaw/pitch from nose direction vector ──
        // The face's Z-axis (column 2) is the nose direction in world space.
        // This avoids Euler angle gimbal lock and wrapping issues.
        let transform = faceAnchor.transform
        let noseX = transform.columns.2.x
        let noseY = transform.columns.2.y
        let noseZ = transform.columns.2.z

        // Yaw: left/right angle of nose in the XZ plane
        currentYaw = Double(atan2(noseX, noseZ))
        // Pitch: up/down angle of nose
        currentPitch = Double(asin(noseY / sqrt(noseX * noseX + noseY * noseY + noseZ * noseZ)))
        // Roll: use the face's X-axis (column 0) Y-component
        currentRoll = Double(atan2(transform.columns.0.y, transform.columns.0.x))
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        if anchors.contains(where: { $0 is ARFaceAnchor }) {
            isFaceDetected = false
        }
    }
}

// MARK: - Depth Metrics

struct DepthMetrics {
    var noseProjection: Double = 0
    var jawlineDepth: Double = 0
    var facialVolume: Double = 0
    var symmetry3D: Double = 0.85

    /// Bonus score modifier based on 3D data (0.95-1.05)
    var confidenceMultiplier: Double {
        // If we have good 3D data, we can slightly boost or reduce confidence
        // A high 3D symmetry validates the 2D symmetry score
        if symmetry3D > 0.92 { return 1.03 }
        if symmetry3D > 0.85 { return 1.0 }
        return 0.97
    }
}
