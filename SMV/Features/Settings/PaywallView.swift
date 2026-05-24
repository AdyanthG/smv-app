//
//  PaywallView.swift
//  SMV
//
//  Premium subscription paywall with tier comparison.
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(SubscriptionManager.self) private var subs
    @Environment(HapticService.self) private var haptics
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanOption = .proMonthly

    var body: some View {
        ZStack {
            Color.smvBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: SMVSpacing.xxl) {
                    // Close
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.smvTextTertiary)
                        }
                    }

                    // Hero
                    VStack(spacing: SMVSpacing.lg) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.smvAmber)

                        Text("Unlock Your\nFull Potential")
                            .font(SMVFont.displayMedium())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text("Get unlimited scans, detailed analytics, and access the full community.")
                            .font(SMVFont.body())
                            .foregroundStyle(Color.smvTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Features comparison
                    featureComparison

                    // Plan selector
                    planSelector

                    // CTA
                    GradientButton(
                        title: "Subscribe Now",
                        icon: "sparkles",
                        isLoading: subs.isLoading
                    ) {
                        haptics.mediumImpact()
                        Task {
                            if let product = subs.products.first(where: {
                                $0.id == selectedPlan.productId
                            }) {
                                await subs.purchase(product)
                                if subs.isPro { dismiss() }
                            }
                        }
                    }

                    // Legal
                    VStack(spacing: SMVSpacing.xs) {
                        Text("Cancel anytime. Auto-renews unless cancelled 24h before period end.")
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                            .multilineTextAlignment(.center)

                        Button("Restore Purchases") {
                            Task { await subs.restorePurchases() }
                        }
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvCyan)
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.bottom, SMVSpacing.huge)
            }
        }
        .task { await subs.loadProducts() }
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        VStack(spacing: SMVSpacing.md) {
            featureRow(icon: "bolt.fill", text: "Unlimited Scans", free: "3/mo", pro: "∞")
            featureRow(icon: "chart.bar.fill", text: "Detailed Breakdown", free: "—", pro: "✓")
            featureRow(icon: "chart.line.uptrend.xyaxis", text: "Score Trends", free: "—", pro: "✓")
            featureRow(icon: "bubble.fill", text: "Forum Posting", free: "Read Only", pro: "Full Access")
            featureRow(icon: "trophy.fill", text: "Leaderboard", free: "View", pro: "Compete")
            featureRow(icon: "sparkles", text: "AI Coach", free: "—", pro: "Elite Only")
        }
    }

    private func featureRow(icon: String, text: String, free: String, pro: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.smvCyan)
                .frame(width: 24)

            Text(text)
                .font(SMVFont.caption())
                .foregroundStyle(.white)

            Spacer()

            Text(free)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
                .frame(width: 60)

            Text(pro)
                .font(SMVFont.micro())
                .fontWeight(.bold)
                .foregroundStyle(Color.smvAmber)
                .frame(width: 60)
        }
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: SMVSpacing.md) {
            ForEach(PlanOption.allCases) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: PlanOption) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            haptics.selection()
            withAnimation(.spring(duration: 0.3)) { selectedPlan = plan }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SMVSpacing.sm) {
                        Text(plan.name)
                            .font(SMVFont.title())
                            .foregroundStyle(.white)
                        if plan == .proYearly {
                            Text("SAVE 40%")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvEmerald)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.smvEmerald.opacity(0.2)))
                        }
                    }
                    Text(plan.subtitle)
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(SMVFont.headline())
                        .foregroundStyle(.white)
                    Text(plan.period)
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                }
            }
            .padding(SMVSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: SMVRadius.lg)
                    .fill(isSelected ? Color.smvViolet.opacity(0.15) : Color.smvSurface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: SMVRadius.lg)
                            .stroke(
                                isSelected ? Color.smvViolet : Color.smvSurface2,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plan Options

enum PlanOption: String, CaseIterable, Identifiable {
    case proMonthly = "pro_monthly"
    case proYearly = "pro_yearly"
    case elite = "elite"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .proMonthly: return "Pro Monthly"
        case .proYearly: return "Pro Yearly"
        case .elite: return "Elite"
        }
    }

    var subtitle: String {
        switch self {
        case .proMonthly: return "Unlimited scans + full analytics"
        case .proYearly: return "Best value — everything in Pro"
        case .elite: return "Pro + AI Coach + exclusive perks"
        }
    }

    var price: String {
        switch self {
        case .proMonthly: return "$4.99"
        case .proYearly: return "$34.99"
        case .elite: return "$9.99"
        }
    }

    var period: String {
        switch self {
        case .proMonthly: return "/month"
        case .proYearly: return "/year"
        case .elite: return "/month"
        }
    }

    var productId: String {
        switch self {
        case .proMonthly: return SubscriptionManager.proMonthlyId
        case .proYearly: return SubscriptionManager.proYearlyId
        case .elite: return SubscriptionManager.eliteMonthlyId
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
        .environment(HapticService())
}
