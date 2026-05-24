//
//  RadarChartView.swift
//  SMV
//
//  Hexagonal radar chart for attribute visualization.
//

import SwiftUI

struct RadarChartView: View {

    let attributes: [(name: String, value: Double)]
    var maxValue: Double = 10.0
    var size: CGFloat = 250
    var animated: Bool = true

    @State private var animationProgress: CGFloat = 0

    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }
    private var radius: CGFloat { size / 2 - 40 }

    var body: some View {
        ZStack {
            // Grid rings
            ForEach(1...4, id: \.self) { level in
                gridRing(level: level, of: 4)
            }

            // Grid lines from center
            ForEach(0..<attributes.count, id: \.self) { index in
                gridLine(index: index)
            }

            // Data polygon
            dataPolygon
                .opacity(Double(animationProgress))

            // Labels
            ForEach(0..<attributes.count, id: \.self) { index in
                attributeLabel(index: index)
            }

            // Data points
            ForEach(0..<attributes.count, id: \.self) { index in
                dataPoint(index: index)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                withAnimation(.spring(duration: 1.0, bounce: 0.15).delay(0.3)) {
                    animationProgress = 1
                }
            } else {
                animationProgress = 1
            }
        }
    }

    // MARK: - Grid

    private func gridRing(level: Int, of total: Int) -> some View {
        let scale = CGFloat(level) / CGFloat(total)
        return PolygonShape(sides: attributes.count, scale: scale)
            .stroke(Color.smvSurface2, lineWidth: 0.5)
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    private func gridLine(index: Int) -> some View {
        let angle = angleFor(index: index)
        let endX = center.x + radius * cos(angle)
        let endY = center.y + radius * sin(angle)

        return Path { path in
            path.move(to: center)
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(Color.smvSurface2.opacity(0.5), lineWidth: 0.5)
    }

    // MARK: - Data

    private var dataPolygon: some View {
        let points = (0..<attributes.count).map { dataPointPosition(index: $0) }

        return ZStack {
            // Fill
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.smvCyan.opacity(0.25), Color.smvViolet.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Stroke
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                path.closeSubpath()
            }
            .stroke(
                LinearGradient(
                    colors: [.smvCyan, .smvViolet],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
        }
    }

    private func dataPoint(index: Int) -> some View {
        let pos = dataPointPosition(index: index)
        return Circle()
            .fill(Color.smvCyan)
            .frame(width: 6, height: 6)
            .shadow(color: Color.smvCyan.opacity(0.5), radius: 4)
            .position(pos)
            .opacity(Double(animationProgress))
    }

    private func attributeLabel(index: Int) -> some View {
        let angle = angleFor(index: index)
        let labelRadius = radius + 28
        let x = center.x + labelRadius * cos(angle)
        let y = center.y + labelRadius * sin(angle)

        return Text(attributes[index].name)
            .font(SMVFont.micro())
            .foregroundStyle(Color.smvTextSecondary)
            .position(x: x, y: y)
    }

    // MARK: - Helpers

    private func angleFor(index: Int) -> CGFloat {
        let fraction = CGFloat(index) / CGFloat(attributes.count)
        return fraction * .pi * 2 - .pi / 2
    }

    private func dataPointPosition(index: Int) -> CGPoint {
        let angle = angleFor(index: index)
        let value = CGFloat(attributes[index].value / maxValue) * animationProgress
        let r = radius * value
        return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
    }
}

// MARK: - Polygon Shape

struct PolygonShape: Shape {
    let sides: Int
    var scale: CGFloat = 1.0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * scale

        var path = Path()
        for i in 0..<sides {
            let angle = CGFloat(i) / CGFloat(sides) * .pi * 2 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    RadarChartView(attributes: [
        ("Symmetry", 8.2),
        ("Jawline", 7.5),
        ("Eye Area", 8.8),
        ("Skin", 6.9),
        ("Harmony", 7.6),
        ("Proportions", 7.3),
    ])
    .padding()
    .background(Color.smvBackground)
}
