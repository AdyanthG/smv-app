//
//  GradientButton.swift
//  SMV
//
//  Clean, solid CTA button. Less glow, more weight.
//

import SwiftUI

struct GradientButton: View {

    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = .brandPrimary
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SMVSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(title)
                        .font(SMVFont.title())
                        .tracking(0.3)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, SMVSpacing.lg)
            .padding(.horizontal, SMVSpacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: SMVRadius.md)
                    .fill(gradient)
            )
            .glow(.smvCyan, radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {

    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SMVSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(SMVFont.title())
                    .tracking(0.3)
            }
            .foregroundStyle(Color.smvTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SMVSpacing.lg)
            .padding(.horizontal, SMVSpacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: SMVRadius.md)
                    .fill(Color.smvSurface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: SMVRadius.md)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        GradientButton(title: "Scan Your Face", icon: "bolt.fill") { }
        SecondaryButton(title: "Share Results", icon: "square.and.arrow.up") { }
    }
    .padding()
    .background(Color.smvBackground)
}
