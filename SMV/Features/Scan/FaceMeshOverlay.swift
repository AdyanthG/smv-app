//
//  FaceMeshOverlay.swift
//  SMV
//
//  Draws detected face landmarks as a glowing mesh overlay.
//

import SwiftUI
import Vision

struct FaceMeshOverlay: View {

    let landmarks: VNFaceLandmarks2D?
    let boundingBox: CGRect
    var color: Color = .smvCyan

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let lm = landmarks else { return }

                let transform = CGAffineTransform(
                    scaleX: size.width,
                    y: -size.height
                ).translatedBy(x: 0, y: -1)

                // Draw each landmark region
                drawRegion(lm.faceContour, context: context, size: size, transform: transform, color: color.opacity(0.6))
                drawRegion(lm.leftEye, context: context, size: size, transform: transform, color: .smvEmerald)
                drawRegion(lm.rightEye, context: context, size: size, transform: transform, color: .smvEmerald)
                drawRegion(lm.leftEyebrow, context: context, size: size, transform: transform, color: color.opacity(0.5))
                drawRegion(lm.rightEyebrow, context: context, size: size, transform: transform, color: color.opacity(0.5))
                drawRegion(lm.nose, context: context, size: size, transform: transform, color: color.opacity(0.7))
                drawRegion(lm.noseCrest, context: context, size: size, transform: transform, color: color.opacity(0.4))
                drawRegion(lm.outerLips, context: context, size: size, transform: transform, color: .smvPink.opacity(0.7))
                drawRegion(lm.innerLips, context: context, size: size, transform: transform, color: .smvPink.opacity(0.5))
                drawRegion(lm.medianLine, context: context, size: size, transform: transform, color: color.opacity(0.3))

                // Draw dots at each landmark point
                drawPoints(lm.allPoints, context: context, size: size, transform: transform, color: color)
            }
        }
    }

    private func drawRegion(
        _ region: VNFaceLandmarkRegion2D?,
        context: GraphicsContext,
        size: CGSize,
        transform: CGAffineTransform,
        color: Color
    ) {
        guard let region, region.pointCount > 1 else { return }
        let points = region.normalizedPoints.map { pt in
            CGPoint(x: pt.x, y: pt.y).applying(transform)
        }

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(
            path,
            with: .color(color),
            lineWidth: 1.5
        )
    }

    private func drawPoints(
        _ region: VNFaceLandmarkRegion2D?,
        context: GraphicsContext,
        size: CGSize,
        transform: CGAffineTransform,
        color: Color
    ) {
        guard let region else { return }
        let points = region.normalizedPoints

        for pt in points {
            let transformed = CGPoint(x: pt.x, y: pt.y).applying(transform)
            let rect = CGRect(x: transformed.x - 1.5, y: transformed.y - 1.5, width: 3, height: 3)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(0.8))
            )
        }
    }
}
