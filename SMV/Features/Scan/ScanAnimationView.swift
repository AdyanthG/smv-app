//
//  ScanAnimationView.swift
//  SMV
//
//  Animated scanning progress overlay.
//

import SwiftUI

struct ScanAnimationView: View {

    let progress: Double

    @State private var scanLineOffset: CGFloat = -1
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dimming overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: SMVSpacing.xxl) {
                // Scanning ring
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.smvCyan.opacity(0.2), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [.smvViolet, .smvCyan, .smvEmerald],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    // Center icon
                    Image(systemName: progressIcon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient.brandPrimary
                        )
                        .symbolEffect(.pulse, isActive: progress < 1.0)
                }

                // Status text
                VStack(spacing: SMVSpacing.sm) {
                    Text(statusTitle)
                        .font(SMVFont.headline())
                        .foregroundStyle(.white)

                    Text(statusSubtitle)
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextSecondary)

                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(SMVFont.scoreMedium())
                        .foregroundStyle(Color.smvCyan)
                        .contentTransition(.numericText())
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    private var progressIcon: String {
        switch progress {
        case 0..<0.25:  return "viewfinder"
        case 0.25..<0.5: return "cpu"
        case 0.5..<0.75: return "chart.bar.fill"
        case 0.75..<1.0: return "checkmark.circle"
        default:         return "sparkles"
        }
    }

    private var statusTitle: String {
        switch progress {
        case 0..<0.2:   return "Detecting Face..."
        case 0.2..<0.45: return "Mapping Landmarks..."
        case 0.45..<0.7: return "Calculating Ratios..."
        case 0.7..<0.9:  return "Generating Score..."
        default:         return "Analysis Complete"
        }
    }

    private var statusSubtitle: String {
        switch progress {
        case 0..<0.2:   return "Locating facial features"
        case 0.2..<0.45: return "76 landmark points detected"
        case 0.45..<0.7: return "Symmetry • Jawline • Eye Area"
        case 0.7..<0.9:  return "Almost there..."
        default:         return "Tap to see your results"
        }
    }
}

#Preview {
    ScanAnimationView(progress: 0.55)
        .background(Color.smvBackground)
}
