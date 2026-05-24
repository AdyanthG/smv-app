//
//  EmptyStateView.swift
//  SMV
//
//  Consistent empty state placeholder for lists and grids.
//

import SwiftUI

struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: SMVSpacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient.brandPrimary
                )
                .padding(.bottom, SMVSpacing.sm)

            Text(title)
                .font(SMVFont.headline())
                .foregroundStyle(Color.smvTextPrimary)

            Text(message)
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if let actionTitle, let action {
                GradientButton(title: actionTitle, isFullWidth: false, action: action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SMVSpacing.xxl)
    }
}

#Preview {
    EmptyStateView(
        icon: "camera.viewfinder",
        title: "No Scans Yet",
        message: "Take your first face scan to see your scores and start tracking your progress.",
        actionTitle: "Start Scanning"
    ) { }
    .background(Color.smvBackground)
}
